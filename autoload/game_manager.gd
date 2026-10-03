extends Node
## Session-level glue only: who the player is, where to respawn, which island
## we're on and how long we've played. Not a dumping ground (spec §130):
## progression lives in Inventory/Parrot/WorldState managers.

## Island id -> scene. Saves store ids, never paths, so scenes can move.
const ISLAND_SCENES := {
	&"castaway_cay": "res://world/islands/castaway_cay/castaway_cay.tscn",
	&"driftwood_key": "res://world/islands/castaway_cay/castaway_cay.tscn",
	&"hat_rock": "res://world/islands/hat_rock/hat_rock.tscn",
	&"bell_atoll": "res://world/islands/bell_atoll/bell_atoll.tscn",
	&"pinwheel_isle": "res://world/islands/pinwheel_isle/pinwheel_isle.tscn",
	&"captains_cabin": "res://world/hub/captains_cabin.tscn",
}
const FIRST_ISLAND := &"castaway_cay"

var player: Node3D = null
var current_island: StringName = &""
var play_time: float = 0.0

var checkpoint_id: StringName = &""
## Island the checkpoint belongs to (a checkpoint never carries across islands).
var checkpoint_island: StringName = &""
## Set by Continue: the next island scene places Patchy at the checkpoint.
var resume_pending := false
var _checkpoint_transform := Transform3D.IDENTITY
var _has_checkpoint := false
var _discovered_islands: Array[StringName] = []
## Islands glimpsed through the Spyglass: pencilled onto the sea chart.
var _sighted_islands: Array[StringName] = []
## Set when a voyage casts off (Voyage): the island scene that loads next
## seats Patchy in his boat, sailing in from `from`. {to, from}
var voyage_arrival: Dictionary = {}


func _ready() -> void:
	var log := QuestLog.new()
	log.name = "QuestLog"
	add_child(log)


## Rebuilds the pause menu's quest page (for progress that isn't announced
## through an Events signal, like a favor asked by an islander).
func quest_log_refresh() -> void:
	var log := get_node_or_null(^"QuestLog") as QuestLog
	if log != null:
		log.refresh.call_deferred()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


func register_player(p: Node3D) -> void:
	player = p
	if not _has_checkpoint:
		_checkpoint_transform = p.global_transform
		_has_checkpoint = true
	Events.player_spawned.emit(p)


func unregister_player(p: Node3D) -> void:
	if player == p:
		player = null


## `silent` records a respawn point (e.g. an island arrival) without the
## flag-raise announcement or an autosave.
func set_checkpoint(id: StringName, xform: Transform3D, silent: bool = false) -> void:
	var is_new := id != checkpoint_id
	checkpoint_id = id
	checkpoint_island = current_island
	_checkpoint_transform = xform
	_has_checkpoint = true
	if is_new and not silent:
		Events.checkpoint_reached.emit(id)


func get_checkpoint_transform() -> Transform3D:
	return _checkpoint_transform


func discover_island(island_id: StringName, display_name: String) -> bool:
	current_island = island_id
	if island_id in _discovered_islands:
		return false
	_discovered_islands.append(island_id)
	Events.island_discovered.emit(island_id, display_name)
	return true


func is_island_discovered(island_id: StringName) -> bool:
	return island_id in _discovered_islands


func get_discovered_islands() -> Array[StringName]:
	return _discovered_islands.duplicate()


## Marks an island seen through the Spyglass. True the first time.
func sight_island(island_id: StringName) -> bool:
	if island_id == &"" or island_id in _sighted_islands or is_island_discovered(island_id):
		return false
	_sighted_islands.append(island_id)
	Events.island_sighted.emit(island_id)
	return true


func is_island_sighted(island_id: StringName) -> bool:
	return island_id in _sighted_islands


func get_island_scene(island_id: StringName) -> String:
	return ISLAND_SCENES.get(island_id, ISLAND_SCENES[FIRST_ISLAND])


## Fast travel by the sea chart (spec §83): sail to a discovered island.
## Islands sharing this scene: a fade, then Patchy (and his boat) arrive at
## the destination's dock. Other islands: a scene change to their "dock"
## spawn point.
func can_sail_to(island_id: StringName) -> bool:
	if not is_island_discovered(island_id) or island_id == current_island:
		return false
	var p := player as Player
	if p == null or not p.state_id in [&"ground", &"swim", &"boat"]:
		return false
	return SeaRegion.find(get_tree(), island_id) != null or ISLAND_SCENES.has(island_id)


func sail_to(island_id: StringName) -> void:
	if not can_sail_to(island_id) or SceneTransition.is_busy():
		return
	var region := SeaRegion.find(get_tree(), island_id)
	if region == null:
		SceneTransition.change_scene(get_island_scene(island_id), &"dock")
		return
	var p := player as Player
	await SceneTransition.fade_out(0.45)
	if not is_instance_valid(p):
		return
	if p.state_id == &"boat":
		p.change_state(&"ground")
	var boat := get_tree().get_first_node_in_group(&"boat") as Node3D
	if boat != null and region.boat_dock != null:
		boat.global_position = region.boat_dock.global_position
		boat.set(&"_yaw", Player.yaw_of(-region.boat_dock.global_basis.z))
		boat.rotation = Vector3(0, float(boat.get(&"_yaw")), 0)
		boat.set(&"_speed", 0.0)
		if boat.has_method(&"_save"):
			boat.call(&"_save")
	var at := region.arrival if region.arrival != null else region.boat_dock
	p.teleport(at.global_position, -at.global_basis.z)
	current_island = island_id
	set_checkpoint(StringName(String(island_id) + "_arrival"), at.global_transform, true)
	AudioManager.play(&"sail_flap", p.global_position)
	await SceneTransition.fade_in(0.5)


## Why Patchy's boat can't make the voyage to `island_id` ("" if it can):
## each island's sailing gate (Archipelago "gate", docs/ARCHIPELAGO.md),
## in words the player sees out on the water.
func voyage_blocker(island_id: StringName) -> String:
	var name := UIChartData.display_name(island_id)
	match StringName(Archipelago.get_island(island_id).get("gate", &"")):
		&"spare_sail":
			if not TinyBoat.has_spare_sail():
				return "The little patched sail can't fight the open-sea current. The boat's turned back... a bigger sail might do it."
		&"jolly_patch":
			if not (InventoryManager.has_ship_part(&"anchor") and InventoryManager.has_ship_part(&"rudder") and InventoryManager.has_ship_part(&"sails")):
				return "A fierce headwind blows the little boat back from %s. It'll take a real ship to get there." % name
		&"ship_cannons":
			if not InventoryManager.has_ship_part(&"cannons"):
				return "Brock's chain boom bars the way into %s. Something would have to blast it." % name
		&"iron_hull":
			if not InventoryManager.has_ship_part(&"iron_hull"):
				return "The storm wall round %s would smash the boat to splinters." % name
		&"full_ship":
			return "Reefs, currents and cannons ring %s. Not without a whole ship... and a whole flock." % name
	if not ISLAND_SCENES.has(island_id):
		return "Sea mist hides the way to %s. (This island isn't built yet.)" % name
	return ""


## Casts off for `island_id` from `from` (the boat's position).
func set_sail(island_id: StringName, from: Vector3) -> void:
	if SceneTransition.is_busy() or voyage_blocker(island_id) != "":
		return
	voyage_arrival = {"to": island_id, "from": from}
	SceneTransition.voyage(get_island_scene(island_id), UIChartData.display_name(island_id))


## Title screen -> New Game: wipe progression and wash ashore.
func start_new_game(slot: int = 0) -> void:
	SaveManager.new_game(slot)
	SaveManager.autosave_enabled = true
	SceneTransition.change_scene(get_island_scene(FIRST_ISLAND))


## Title screen -> Continue: load the slot and return to its checkpoint.
func continue_game(slot: int = 0) -> bool:
	if not SaveManager.load_game(slot):
		return false
	SaveManager.autosave_enabled = true
	resume_pending = true
	SceneTransition.change_scene(get_island_scene(current_island if current_island != &"" else FIRST_ISLAND))
	return true


func serialize() -> Dictionary:
	var o := _checkpoint_transform.origin
	return {
		"play_time": play_time,
		"island": String(current_island),
		"checkpoint_id": String(checkpoint_id),
		"checkpoint_island": String(checkpoint_island),
		"checkpoint_pos": [o.x, o.y, o.z],
		"checkpoint_yaw": _checkpoint_transform.basis.get_euler().y,
		"islands": _discovered_islands.map(func(i: StringName) -> String: return String(i)),
		"sighted": _sighted_islands.map(func(i: StringName) -> String: return String(i)),
	}


func deserialize(data: Dictionary) -> void:
	play_time = float(data.get("play_time", 0.0))
	current_island = StringName(data.get("island", ""))
	checkpoint_id = StringName(data.get("checkpoint_id", ""))
	checkpoint_island = StringName(data.get("checkpoint_island", data.get("island", "")))
	var p: Array = data.get("checkpoint_pos", [])
	if p.size() == 3:
		var yaw := float(data.get("checkpoint_yaw", 0.0))
		_checkpoint_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p[0], p[1], p[2]))
		_has_checkpoint = true
	_discovered_islands.clear()
	for i in data.get("islands", []):
		_discovered_islands.append(StringName(i))
	_sighted_islands.clear()
	for i in data.get("sighted", []):
		_sighted_islands.append(StringName(i))


func reset() -> void:
	play_time = 0.0
	current_island = &""
	checkpoint_id = &""
	checkpoint_island = &""
	resume_pending = false
	_has_checkpoint = false
	_checkpoint_transform = Transform3D.IDENTITY
	_discovered_islands.clear()
	_sighted_islands.clear()
