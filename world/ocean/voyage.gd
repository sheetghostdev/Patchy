class_name Voyage
extends Node
## Sailing from one island to another (docs/ARCHIPELAGO.md). Steer the boat
## out past this island's waters with another island dead ahead on the
## horizon and, if the boat can make the trip (GameManager.voyage_blocker),
## the sea carries Patchy there: "Sailing for Hat Rock...", an iris, and his
## boat nosing in toward the new shore. If it can't, the sea says why.
## One per island scene; `home` is the scene's island (Archipelago id).

@export var home: StringName = &"castaway_cay"
## Degrees either side of the bow an island may lie to count as "ahead".
@export_range(4.0, 40.0, 0.5) var aim := 15.0
## Seconds to hold the course (under way) before casting off.
@export_range(0.0, 5.0, 0.1) var hold_time := 1.0

var _target: StringName = &""
var _hold := 0.0
var _hint_cool := 0.0


func _physics_process(delta: float) -> void:
	_hint_cool = maxf(_hint_cool - delta, 0.0)
	var boat := _driven_boat()
	if boat == null or SceneTransition.is_busy():
		_reset()
		return
	var at := boat.global_position
	if Player.flat(at - Archipelago.world_position(home)).length() < Archipelago.waters(home):
		_reset()
		return
	var ahead := destination_ahead(at, Player.dir_from_yaw(boat.get_yaw()))
	if ahead == &"":
		_reset()
		return
	var why := GameManager.voyage_blocker(ahead)
	if why != "":
		_reset()
		if _hint_cool <= 0.0:
			_hint_cool = 9.0
			Events.hud_message.emit(why, 3.5)
		return
	if ahead != _target:
		_target = ahead
		_hold = 0.0
		Events.hud_message.emit("Sailing for %s..." % UIChartData.display_name(ahead), 1.6)
	if boat.get_speed() > 2.0:
		_hold += delta
	if _hold >= hold_time:
		_reset()
		GameManager.set_sail(ahead, at)


## The nearest island within `aim` degrees of `heading` from `at`, other
## than the ones this scene holds.
func destination_ahead(at: Vector3, heading: Vector3) -> StringName:
	var info := get_tree().get_first_node_in_group(&"island_info") as IslandInfo
	var best: StringName = &""
	var best_d := INF
	for id in Archipelago.ids():
		if id == home or (info != null and info.covers(id)):
			continue
		var to := Player.flat(Archipelago.world_position(id) - at)
		if rad_to_deg(heading.angle_to(to.normalized())) > aim:
			continue
		if to.length() < best_d:
			best_d = to.length()
			best = id
	return best


func _driven_boat() -> TinyBoat:
	var p := GameManager.player as Player
	if p == null or p.state_id != &"boat":
		return null
	for b in get_tree().get_nodes_in_group(&"boat"):
		var boat := b as TinyBoat
		if boat != null and boat.driver == p:
			return boat
	return null


func _reset() -> void:
	_target = &""
	_hold = 0.0
