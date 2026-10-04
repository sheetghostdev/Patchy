class_name WorldDirector
extends Node
## The one sea (docs/ARCHIPELAGO.md): every island lives in a single world
## scene, joined by open water. No scene changes and no walls between them;
## the director keeps it light and keeps track of where Patchy is:
##  - Places Patchy when the world loads: a saved checkpoint (Continue), a
##    named spawn point (back out of the captain's cabin), or where the
##    world put him (a new game washes him up on Castaway Cay).
##  - Wakes the islands near him and puts the far ones to sleep (no
##    processing, no physics, hidden), drawing each sleeping island as its
##    silhouette instead. Silhouettes grow a little with distance, Wind
##    Waker's trick, so a far island still reads at sea.
##  - Tracks the waters he's in (SeaRegion): the island they belong to is
##    the current island (checkpoints, the chart's "you are here", the
##    collection pages), sailing into new waters announces the island and
##    plays its music, and coming ashore from the sea makes its landing the
##    respawn point. Out between islands are "Uncharted Waters".

## An island wakes this far (m) beyond its own waters (Archipelago.waters)...
const WAKE_MARGIN := 120.0
## ...and goes back to sleep this far beyond them.
const SLEEP_MARGIN := 180.0

## Island id -> its chunk (the island's scene root in the world).
var chunks := {}
## Island id -> its IslandInfo.
var infos := {}
## Island id -> its silhouette (HorizonIsland).
var silhouettes := {}
## Island id -> whether its chunk is awake.
var awake := {}
## The waters Patchy is in (null out at sea).
var region: SeaRegion = null
var _started := false
var _tracking := false


func _ready() -> void:
	add_to_group(&"world_director")
	# Before anything else moves this tick, so an island is awake under
	# Patchy the moment he arrives on it.
	process_physics_priority = -100
	_start.call_deferred()


func _start() -> void:
	_collect()
	_place_player(GameManager.player as Player)
	_started = true
	stream()
	var seq := _pending_sequence()
	if seq != null:
		await seq.finished
	_tracking = true
	_track(true)


## Nodes of `group` in this world (not one on its way out).
func _mine(group: StringName) -> Array[Node]:
	var world := get_parent()
	var out: Array[Node] = []
	for n in get_tree().get_nodes_in_group(group):
		if world.is_ancestor_of(n):
			out.append(n)
	return out


func _collect() -> void:
	for n in _mine(&"island_info"):
		var info := n as IslandInfo
		if info == null or not info.get_parent() is Node3D:
			continue
		chunks[info.island_id] = info.get_parent()
		infos[info.island_id] = info
		awake[info.island_id] = true
	for n in _mine(&"horizon_island"):
		var sil := n as Node3D
		if sil != null and sil.has_meta(&"island_id"):
			silhouettes[StringName(sil.get_meta(&"island_id"))] = sil


func _physics_process(_delta: float) -> void:
	if not _started:
		return
	stream()
	if _tracking:
		_track(false)


## Where the world is seen from: Patchy (or the camera when he's missing).
func focus() -> Vector3:
	var p := GameManager.player as Node3D
	if p != null and is_instance_valid(p):
		return p.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam != null else Vector3.ZERO


## Wakes and sleeps the islands round the focus, and sizes the silhouettes.
func stream() -> void:
	var at := focus()
	for id: StringName in chunks:
		var d := _distance(at, id)
		var r := Archipelago.waters(id)
		var want: bool = awake[id]
		if d < r + WAKE_MARGIN:
			want = true
		elif d > r + SLEEP_MARGIN:
			want = false
		if want != awake[id]:
			set_awake(id, want)
	for id: StringName in silhouettes:
		var sil: Node3D = silhouettes[id]
		if chunks.has(id):
			sil.visible = not awake[id]
		if sil.visible:
			sil.scale = Vector3.ONE * silhouette_scale(id, _distance(at, id))


func set_awake(id: StringName, on: bool) -> void:
	var chunk := chunks.get(id) as Node3D
	if chunk == null:
		return
	awake[id] = on
	chunk.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	chunk.visible = on
	if silhouettes.has(id):
		(silhouettes[id] as Node3D).visible = not on


func is_awake(id: StringName) -> bool:
	return bool(awake.get(id, false))


## How big an island's silhouette is drawn from `d` m away: life size up
## close, growing toward its Archipelago "scale" far out. Never faster than
## the distance itself grows, so sailing in, an island only ever looms larger.
func silhouette_scale(id: StringName, d: float) -> float:
	var full := float(Archipelago.get_island(id).get("scale", 1.0))
	if full <= 1.0:
		return 1.0
	var near := Archipelago.waters(id) + WAKE_MARGIN
	var far := near * full * 1.1
	return lerpf(1.0, full, clampf((d - near) / (far - near), 0.0, 1.0))


func _distance(at: Vector3, id: StringName) -> float:
	var c := Archipelago.world_position(id)
	return Vector2(at.x - c.x, at.z - c.z).length()


# --- Where Patchy is ------------------------------------------------------------------

## The waters at `pos`: the smallest SeaRegion holding it (an islet's
## waters inside a bigger island's), or null out at sea.
func region_at(pos: Vector3) -> SeaRegion:
	var best: SeaRegion = null
	for n in _mine(&"sea_region"):
		var r := n as SeaRegion
		if r != null and r.contains(pos) and (best == null or r.radius < best.radius):
			best = r
	return best


func _track(first: bool) -> void:
	var p := GameManager.player as Player
	if p == null:
		return
	var here := region_at(p.global_position)
	if here == region and not first:
		return
	region = here
	if here == null:
		GameManager.current_island = &""
		return
	var id := here.island_id
	GameManager.discover_island(id, here.region_name)
	# Come ashore from the sea: a fall or a faint brings Patchy back to this
	# island's landing, not to the last island he was on.
	if GameManager.checkpoint_island != id:
		var land := here.arrival if here.arrival != null else here.boat_dock
		if land != null:
			GameManager.set_checkpoint(StringName(String(id) + "_arrival"), land.global_transform, true)
	var info := _info_for(id)
	if info != null and info.music != &"":
		AudioManager.play_music(info.music)


func _info_for(id: StringName) -> IslandInfo:
	for k: StringName in infos:
		var info := infos[k] as IslandInfo
		if info.covers(id):
			return info
	return null


func _place_player(player: Player) -> void:
	if player == null:
		return
	if GameManager.resume_pending:
		GameManager.resume_pending = false
		var xf := GameManager.get_checkpoint_transform()
		player.teleport(xf.origin, -xf.basis.z)
		_snap_camera(player)
		return
	var spawn_id := SceneTransition.pending_spawn_id
	SceneTransition.pending_spawn_id = &""
	if spawn_id != &"":
		for sp in _mine(&"spawn_point"):
			if StringName(sp.get_meta(&"spawn_id", &"")) == spawn_id:
				var marker := sp as Node3D
				player.teleport(marker.global_position, -marker.global_basis.z)
				_snap_camera(player)
				break
	# Arriving fresh: falling or fainting returns here until a flag is raised.
	var here := region_at(player.global_position)
	GameManager.current_island = here.island_id if here != null else &""
	var id := GameManager.current_island if GameManager.current_island != &"" else &"open_sea"
	GameManager.set_checkpoint(StringName(String(id) + "_arrival"), player.global_transform, true)


func _snap_camera(player: Player) -> void:
	var rig := player.camera_rig as CameraRig
	if rig != null:
		rig.snap_behind_target()


func _pending_sequence() -> OpeningSequence:
	for n in _mine(&"opening_sequence"):
		var seq := n as OpeningSequence
		if seq != null and seq.is_pending():
			return seq
	return null
