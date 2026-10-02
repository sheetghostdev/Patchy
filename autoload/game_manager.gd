extends Node
## Session-level glue only: who the player is, where to respawn, which island
## we're on and how long we've played. Not a dumping ground (spec §130):
## progression lives in Inventory/Parrot/WorldState managers.

var player: Node3D = null
var current_island: StringName = &""
var play_time: float = 0.0

var checkpoint_id: StringName = &""
var _checkpoint_transform := Transform3D.IDENTITY
var _has_checkpoint := false
var _discovered_islands: Array[StringName] = []


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


func set_checkpoint(id: StringName, xform: Transform3D) -> void:
	var is_new := id != checkpoint_id
	checkpoint_id = id
	_checkpoint_transform = xform
	_has_checkpoint = true
	if is_new:
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


func serialize() -> Dictionary:
	var o := _checkpoint_transform.origin
	return {
		"play_time": play_time,
		"island": String(current_island),
		"checkpoint_id": String(checkpoint_id),
		"checkpoint_pos": [o.x, o.y, o.z],
		"checkpoint_yaw": _checkpoint_transform.basis.get_euler().y,
		"islands": _discovered_islands.map(func(i: StringName) -> String: return String(i)),
	}


func deserialize(data: Dictionary) -> void:
	play_time = float(data.get("play_time", 0.0))
	current_island = StringName(data.get("island", ""))
	checkpoint_id = StringName(data.get("checkpoint_id", ""))
	var p: Array = data.get("checkpoint_pos", [])
	if p.size() == 3:
		var yaw := float(data.get("checkpoint_yaw", 0.0))
		_checkpoint_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(p[0], p[1], p[2]))
		_has_checkpoint = true
	_discovered_islands.clear()
	for i in data.get("islands", []):
		_discovered_islands.append(StringName(i))


func reset() -> void:
	play_time = 0.0
	current_island = &""
	checkpoint_id = &""
	_has_checkpoint = false
	_checkpoint_transform = Transform3D.IDENTITY
	_discovered_islands.clear()
