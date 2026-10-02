@tool
class_name Collectible
extends Area3D
## Treasure and pickups (spec §83–85, §137, §153–154). Coins are counted by
## value only; unique treasure (gems, goblets, crowns, relics) carries a
## stable id so it never respawns once collected. Pickups gently magnetize
## toward Patchy, pop with sparkles and a rising-pitch ding when collected in
## quick succession (coin trails feel musical).

signal collected(collectible: Collectible)

const KIND_VALUES := {&"coin": 1, &"pearl": 3, &"gem": 5, &"goblet": 15, &"crown": 25, &"relic": 40, &"heart": 0}

@export_enum("coin", "gem", "pearl", "goblet", "crown", "relic", "heart") var kind: String = "coin":
	set(v):
		kind = v
		_rebuild()
## 0 = default value for the kind.
@export var value := 0
## Unique id for persistent treasure (leave empty for loose coins).
@export var treasure_id: StringName = &""
@export var island_id: StringName = &""
@export var gem_color := Palette.GEM_RED:
	set(v):
		gem_color = v
		_rebuild()
@export_range(0.0, 6.0, 0.1) var magnet_radius := 2.0
@export var float_motion := true
## Spawned by a chest/crab/break: pop upward and scatter before settling.
@export var launched := false

static var _streak := 0
static var _last_pickup_ms := -10000

var _mesh: MeshInstance3D
var _time := 0.0
var _picked := false
var _velocity := Vector3.ZERO
var _base_y := 0.0
var _magnet_t := 0.0
var _sparkle_loop: AudioStreamPlayer3D
## True while a crab carries it (not collectible directly).
var carried := false
## Initial velocity when `launched` (zero = a random spill).
var launch_velocity := Vector3.ZERO


func _ready() -> void:
	collision_layer = Layers.COLLECTIBLE
	collision_mask = Layers.PLAYER
	monitorable = true
	_rebuild()
	if Engine.is_editor_hint():
		return
	if treasure_id != &"" and InventoryManager.has_treasure(treasure_id):
		queue_free()
		return
	if not _has_shape():
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.55 if kind == "coin" else 0.65
		cs.shape = sph
		add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_time = randf() * TAU
	_base_y = position.y
	if kind != "coin" and kind != "heart":
		add_to_group(&"look_at_target")
		_sparkle_loop = AudioManager.create_loop(&"sparkle_loop", self, -14.0)
		if _sparkle_loop.stream != null:
			_sparkle_loop.max_distance = 9.0
			_sparkle_loop.play()
	if launched:
		if launch_velocity != Vector3.ZERO:
			_velocity = launch_velocity
		else:
			_velocity = Vector3(randf_range(-2.5, 2.5), randf_range(6.0, 8.0), randf_range(-2.5, 2.5))


## Pop out of something (props call this on spawned contents).
func launch(v: Vector3) -> void:
	launched = true
	launch_velocity = v
	_velocity = v


func _has_shape() -> bool:
	for c in get_children(true):
		if c is CollisionShape3D:
			return true
	return false


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
	_mesh.mesh = TreasureMeshes.get_mesh(StringName(kind), gem_color)
	var s := 1.0
	match kind:
		"crown", "relic", "goblet":
			s = 1.35
		"heart":
			s = 1.2
	_mesh.scale = Vector3.ONE * s


func get_value() -> int:
	return value if value > 0 else int(KIND_VALUES.get(StringName(kind), 1))


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _picked or carried:
		return
	_time += delta
	if launched:
		_velocity.y -= 22.0 * delta
		var next := global_position + _velocity * delta
		var hit := get_world_3d().direct_space_state.intersect_ray(
				PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.3, next - Vector3.UP * 0.3, Layers.WORLD))
		if not hit.is_empty() and _velocity.y < 0.0:
			global_position = (hit.position as Vector3) + Vector3.UP * 0.35
			_velocity *= Vector3(0.5, -0.35, 0.5)
			if absf(_velocity.y) < 1.2:
				launched = false
				_base_y = position.y
		else:
			global_position = next
		return
	var p := GameManager.player
	# No vacuuming up loot while knocked out, talking or in a cutscene.
	if p != null and magnet_radius > 0.0 and p.get(&"state_id") != &"locked":
		var chest := p.global_position + Vector3.UP * 0.8
		var d := global_position.distance_to(chest)
		if d < magnet_radius or _magnet_t > 0.0:
			_magnet_t += delta
			var speed := 4.0 + _magnet_t * 30.0
			global_position = global_position.move_toward(chest, speed * delta)
			return
	if float_motion:
		position.y = _base_y + sin(_time * 2.4) * 0.1
	if _mesh != null:
		_mesh.rotation.y += delta * (3.0 if kind == "coin" else 1.6)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and not carried:
		collect(body as Player)


func collect(player: Player) -> void:
	if _picked:
		return
	_picked = true
	if kind == "heart":
		player.health.heal(1)
		AudioManager.play(&"heart_pickup", global_position)
	else:
		InventoryManager.collect_treasure(treasure_id, StringName(kind), get_value(), island_id, gem_color)
		_play_pickup_sound()
	collected.emit(self)
	var col := Palette.GOLD if kind in ["coin", "goblet", "crown"] else gem_color
	VFX.sparkle(self, global_position, col, 6 if kind == "coin" else 16, 3.0 if kind == "coin" else 5.0)
	if _sparkle_loop != null:
		_sparkle_loop.stop()
	set_deferred(&"monitoring", false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_mesh, "scale", _mesh.scale * 1.8, 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(self, "global_position", global_position + Vector3.UP * 0.6, 0.18)
	tw.chain().tween_property(_mesh, "scale", Vector3.ZERO, 0.1)
	tw.chain().tween_callback(queue_free)


func _play_pickup_sound() -> void:
	var now := Time.get_ticks_msec()
	_streak = _streak + 1 if now - _last_pickup_ms < 650 else 0
	_last_pickup_ms = now
	match kind:
		"coin":
			# Rising pitch across quick trails: a little melody (spec §137).
			var semis := [0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19]
			var st: int = semis[mini(_streak, semis.size() - 1)]
			AudioManager.play(&"coin", global_position, -2.0, pow(2.0, st / 12.0), 0.0)
		"gem", "pearl":
			AudioManager.play(&"gem", global_position)
		_:
			AudioManager.play(&"treasure_big", global_position)


## Grabbed by a thief (crab): stops floating and stops being collectible.
func set_carried(on: bool) -> void:
	carried = on
	monitoring = not on
	if not on:
		_base_y = position.y
		_magnet_t = 0.0
