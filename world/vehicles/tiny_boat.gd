@tool
class_name TinyBoat
extends CharacterBody3D
## Patchy's patched-up dinghy (spec §75): "[E] Board", steer with the stick
## (camera-relative, like walking), jump to hop out near any shore. Floats on
## the water with a gentle bob, leans into turns and lifts its bow when it
## gets going. Nothing holds it to one island: the whole sea is one world
## (WorldDirector), so it sails anywhere the water goes. Remembers where it
## was left; if Patchy ends up on another island without it, it washes up
## at that island's dock. Old Shellby's gift of Betty's spare sail
## (docs/ARCHIPELAGO.md) makes it bigger-sailed and quicker.

@export var boat_id: StringName = &"tiny_boat"
@export_range(1.0, 30.0, 0.1) var max_speed := 10.5
@export_range(0.5, 40.0, 0.1) var accel := 5.5
@export_range(0.5, 40.0, 0.1) var brake := 8.0
@export_range(0.0, 20.0, 0.1) var drag := 2.4
@export_range(0.1, 6.0, 0.05) var turn_rate_slow := 2.1
@export_range(0.1, 6.0, 0.05) var turn_rate_fast := 1.25
## Hull origin sits this far above the water surface.
@export_range(-1.0, 1.0, 0.01) var float_offset := 0.0

## WorldState id of Betty's spare sail (Old Shellby's gift).
const SPARE_SAIL := &"boat_spare_sail"
const SPARE_SAIL_SPEED := 1.3

const LENGTH := 3.8
const HALF_WIDTH := 0.86
const KEEL_Y := -0.4
const GUNWALE_Y := 0.48
## Patchy's feet while seated on the stern thwart (boat local space).
const SEAT := Vector3(0.0, -0.06, 0.78)

var driver: Node3D = null
var _yaw := 0.0
var _speed := 0.0
var _visual: Node3D
var _board: Interactable
var _bob_t := 0.0
var _roll := 0.0
var _pitch := 0.0
var _bump_cool := 0.0
var _wake_t := 0.0
var _check_t := 0.0
var _driven_t := 0.0


func _ready() -> void:
	collision_layer = Layers.PROPS
	collision_mask = Layers.WORLD
	motion_mode = MOTION_MODE_FLOATING
	_build()
	if Engine.is_editor_hint():
		return
	add_to_group(&"boat")
	_yaw = rotation.y
	var saved: Variant = WorldState.get_flag(_save_id(), "pos")
	if saved is Array and (saved as Array).size() == 3:
		global_position = Vector3(saved[0], saved[1], saved[2])
		_yaw = float(WorldState.get_flag(_save_id(), "yaw", _yaw))
	rotation = Vector3(0, _yaw, 0)
	_board = Interactable.new()
	_board.prompt = "{interact} Board"
	_board.radius = 2.7
	_board.min_facing = -0.6
	_board.interact_priority = 1
	add_child(_board, false, Node.INTERNAL_MODE_FRONT)
	_board.interacted.connect(_on_board)


func _build() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(HALF_WIDTH * 2.0, 0.9, LENGTH)
	cs.shape = box
	cs.position = Vector3(0, 0.05, 0)
	cs.set_meta(&"generated", true)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	_visual.set_meta(&"generated", true)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mi := MeshInstance3D.new()
	mi.mesh = _hull_mesh()
	_visual.add_child(mi)
	var sail := MeshInstance3D.new()
	sail.name = "Sail"
	sail.mesh = _sail_mesh() if Engine.is_editor_hint() or not has_spare_sail() else _spare_sail_mesh()
	_visual.add_child(sail)


static func has_spare_sail() -> bool:
	return WorldState.is_completed(SPARE_SAIL)


## Rigs Betty's spare sail (after Shellby hands it over).
func refresh_sail() -> void:
	var sail := _visual.get_node_or_null(^"Sail") as MeshInstance3D
	if sail != null:
		sail.mesh = _spare_sail_mesh() if has_spare_sail() else _sail_mesh()


func top_speed() -> float:
	return max_speed * (SPARE_SAIL_SPEED if has_spare_sail() else 1.0)


## Half-width and gunwale height along the hull, s = 0 at the bow, 1 at the stern.
static func _section(s: float) -> Vector2:
	var w := 0.0
	if s < 0.62:
		w = 0.06 + 0.94 * pow(sin(s / 0.62 * PI * 0.5), 0.75)
	else:
		w = 1.0 - 0.3 * pow((s - 0.62) / 0.38, 2.0)
	var top := GUNWALE_Y + 0.26 * pow(1.0 - s, 2.2)
	return Vector2(w * HALF_WIDTH, top)


static func _hull_rows(scale_w: float, keel_lift: float, top_drop: float) -> Array:
	var rows: Array = []
	var nrows := 14
	var ncols := 11
	for j in nrows:
		var s := float(j) / (nrows - 1)
		var z := -LENGTH * 0.5 + s * LENGTH
		var sec := _section(s)
		var w := sec.x * scale_w
		var top := sec.y - top_drop
		var keel := KEEL_Y + keel_lift + 0.18 * pow(1.0 - s, 3.0)
		var row := PackedVector3Array()
		for i in ncols:
			var a := -PI * 0.5 + PI * float(i) / (ncols - 1)
			var x := w * sin(a)
			var y := keel + (top - keel) * (1.0 - pow(cos(a), 0.7))
			row.append(Vector3(x, y, z))
		rows.append(row)
	return rows


func _hull_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var outer := _hull_rows(1.0, 0.0, 0.0)
	var inner := _hull_rows(0.86, 0.12, 0.03)
	var hull_color := Color("8a5a36")
	var inside_color := Color("c08a55")
	mb.grid(outer, hull_color, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y - GUNWALE_Y, 0.0).normalized() + Vector3(0, 0, -0.3 if p.z < -1.2 else 0.0))
	mb.grid(inner, inside_color, func(p: Vector3) -> Vector3: return -Vector3(p.x, p.y - GUNWALE_Y, 0.0).normalized())
	# Transom (flat stern) and gunwale rails.
	var last: PackedVector3Array = outer[outer.size() - 1]
	var center := Vector3(0, (KEEL_Y + GUNWALE_Y) * 0.5, LENGTH * 0.5)
	for i in last.size() - 1:
		mb.triangle(center, last[i], last[i + 1], hull_color.darkened(0.1), true)
	mb.triangle(last[0], last[last.size() - 1], center, hull_color.darkened(0.1), true)
	for side: int in [0, 10]:
		var rail := PackedVector3Array()
		var radii := PackedFloat32Array()
		for j in outer.size():
			var p: Vector3 = outer[j][side]
			rail.append(p + Vector3(0, 0.02, 0))
			radii.append(0.06)
		mb.tube(rail, radii, Palette.WOOD_DARK, 6, true)
	var stern_rail := PackedVector3Array([last[0] + Vector3(0, 0.02, 0), last[last.size() - 1] + Vector3(0, 0.02, 0)])
	mb.tube(stern_rail, PackedFloat32Array([0.06, 0.06]), Palette.WOOD_DARK, 6, true)
	# A colorful band along the hull (Patchy's red).
	for j in outer.size() - 1:
		for side: int in [1, 9]:
			var a: Vector3 = outer[j][side]
			var b: Vector3 = outer[j + 1][side]
			var o := Vector3(signf(a.x) * 0.012, 0, 0)
			mb.box(Vector3(0.02, 0.07, a.distance_to(b) + 0.02), Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5 + o), Palette.COAT)
	# Thwarts (seats), rudder and tiller.
	mb.box(Vector3(HALF_WIDTH * 1.7, 0.07, 0.34), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, SEAT.z)), Palette.WOOD)
	mb.box(Vector3(HALF_WIDTH * 1.6, 0.07, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, 0.22, -0.55)), Palette.WOOD)
	mb.box(Vector3(0.08, 0.9, 0.5), Transform3D(Basis.IDENTITY, Vector3(0, -0.05, LENGTH * 0.5 + 0.12)), Palette.WOOD_DARK)
	mb.cylinder(0.035, 0.035, 0.9, Transform3D(Basis.from_euler(Vector3(PI * 0.5 - 0.25, 0, 0)), Vector3(0, 0.42, LENGTH * 0.5 - 0.18)), Palette.WOOD_DARK, 6)
	var mesh := mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	return mesh


func _sail_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var mast_z := -0.75
	mb.cylinder(0.05, 0.065, 2.9, Transform3D(Basis.IDENTITY, Vector3(0, 1.55, mast_z)), Palette.WOOD_DARK, 8)
	mb.cylinder(0.035, 0.035, 1.7, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 0.75, mast_z + 0.85)), Palette.WOOD_DARK, 6)
	# Patched triangular sail.
	var head := Vector3(0, 2.85, mast_z)
	var tack := Vector3(0, 0.82, mast_z + 0.05)
	var clew := Vector3(0, 0.82, mast_z + 1.65)
	var cloth := Color("f3ead2")
	mb.triangle(head, tack, clew, cloth, true)
	mb.triangle(head + Vector3(0.012, 0, 0), Vector3(0.012, 1.7, mast_z + 0.45), Vector3(0.012, 1.35, mast_z + 0.85), Color("e9b44c"), true)
	mb.triangle(Vector3(-0.012, 1.0, mast_z + 0.6), Vector3(-0.012, 1.45, mast_z + 0.55), Vector3(-0.012, 1.0, mast_z + 1.05), Color("6fb0d9"), true)
	# Patchy's pennant.
	mb.triangle(Vector3(0, 3.05, mast_z), Vector3(0, 2.85, mast_z), Vector3(0, 2.95, mast_z + 0.5), Palette.COAT, true)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


## Betty's spare sail: a taller mast, a big striped mainsail (Shellby's red
## and cream) with a jib before it, and Patchy's pennant on top.
func _spare_sail_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var mast_z := -0.75
	mb.cylinder(0.055, 0.07, 3.5, Transform3D(Basis.IDENTITY, Vector3(0, 1.85, mast_z)), Palette.WOOD_DARK, 8)
	mb.cylinder(0.04, 0.04, 2.0, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 0.8, mast_z + 1.0)), Palette.WOOD_DARK, 6)
	# Mainsail: four vertical strips from the mast aft to the boom.
	var strips := 4
	for k in strips:
		var z0 := mast_z + 0.05 + 1.85 * k / strips
		var z1 := mast_z + 0.05 + 1.85 * (k + 1) / strips
		var top0 := 3.45 - 2.3 * float(k) / strips
		var top1 := 3.45 - 2.3 * float(k + 1) / strips
		var belly := 0.08 * sin(PI * (k + 0.5) / strips)
		var col := Color("d8433a") if k % 2 == 0 else Color("f6ecd6")
		var a := Vector3(belly, top0, z0)
		var b := Vector3(belly, top1, z1)
		var c := Vector3(belly, 0.86, z1)
		var d := Vector3(belly, 0.86, z0)
		mb.triangle(a, b, c, col, true)
		mb.triangle(a, c, d, col, true)
	# A square patch stitched on, for Shellby's honesty.
	mb.triangle(Vector3(0.1, 1.6, mast_z + 0.95), Vector3(0.1, 1.6, mast_z + 1.25), Vector3(0.1, 1.3, mast_z + 1.25), Color("6fb0d9"), true)
	mb.triangle(Vector3(0.1, 1.6, mast_z + 0.95), Vector3(0.1, 1.3, mast_z + 1.25), Vector3(0.1, 1.3, mast_z + 0.95), Color("6fb0d9"), true)
	# Jib from the masthead down to the bow.
	mb.triangle(Vector3(0, 3.3, mast_z), Vector3(0, 0.75, mast_z - 0.05), Vector3(0, 0.62, -LENGTH * 0.5 + 0.12), Color("f6ecd6"), true)
	mb.triangle(Vector3(0, 3.75, mast_z), Vector3(0, 3.5, mast_z), Vector3(0, 3.62, mast_z + 0.6), Palette.COAT, true)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


# --- Runtime ------------------------------------------------------------------------

func _on_board(player: Node3D) -> void:
	var p := player as Player
	if p == null or driver != null:
		return
	driver = p
	_board.enabled = false
	AudioManager.play(&"boat_splash", global_position, -4.0)
	p.change_state(&"boat", {"vehicle": self})


## Called by the player's boat state every physics tick while seated.
func drive(stick: Vector3, delta: float) -> void:
	_driven_t = 0.15
	var want := Player.flat(stick)
	var mag := clampf(want.length(), 0.0, 1.0)
	if mag > 0.15:
		var target_yaw := Player.yaw_of(want)
		var rate := lerpf(turn_rate_slow, turn_rate_fast, clampf(_speed / top_speed(), 0.0, 1.0))
		var before := _yaw
		_yaw = rotate_toward(_yaw, target_yaw, rate * delta)
		_roll = lerpf(_roll, clampf(angle_difference(before, _yaw) / maxf(delta, 0.001) * 0.09, -0.16, 0.16), 1.0 - exp(-delta * 4.0))
		var align := clampf(Player.dir_from_yaw(_yaw).dot(want.normalized()), 0.0, 1.0)
		var target := top_speed() * mag * lerpf(0.3, 1.0, align * align)
		_speed = move_toward(_speed, target, (accel if target > _speed else brake) * delta)
	else:
		_speed = move_toward(_speed, 0.0, drag * delta)
		_roll = lerpf(_roll, 0.0, 1.0 - exp(-delta * 3.0))
	_step(delta)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_bump_cool = maxf(_bump_cool - delta, 0.0)
	if _driven_t > 0.0:
		_driven_t -= delta
		return
	# Unmanned: coast to a stop and keep floating.
	_speed = move_toward(_speed, 0.0, drag * 2.0 * delta)
	_roll = lerpf(_roll, 0.0, 1.0 - exp(-delta * 3.0))
	_step(delta)
	_check_t -= delta
	if _check_t <= 0.0:
		_check_t = 1.0
		_maybe_return_to_dock()


func _step(delta: float) -> void:
	rotation = Vector3(0, _yaw, 0)
	var surface := _surface_height()
	var v := Player.dir_from_yaw(_yaw) * _speed
	v.y = (surface + float_offset - global_position.y) * 8.0
	velocity = v
	move_and_slide()
	if get_slide_collision_count() > 0 and _speed > 2.0 and _bump_cool <= 0.0:
		_bump_cool = 0.5
		_speed *= 0.45
		AudioManager.play(&"wood_creak", global_position, -2.0, randf_range(0.85, 1.05))
		Events.camera_impulse.emit(0.15)
	_animate(delta)


func _animate(delta: float) -> void:
	_bob_t += delta
	var k := clampf(_speed / top_speed(), 0.0, 1.0)
	_pitch = lerpf(_pitch, -0.07 * k, 1.0 - exp(-delta * 2.0))
	var bob := sin(_bob_t * 1.7) * 0.045 + sin(_bob_t * 2.9 + 1.0) * 0.02
	_visual.position = Vector3(0, bob, 0)
	_visual.rotation = Vector3(_pitch + sin(_bob_t * 1.3) * 0.02, 0, -_roll + sin(_bob_t * 1.1 + 0.5) * 0.03)
	if _speed > 3.0:
		_wake_t -= delta
		if _wake_t <= 0.0:
			_wake_t = lerpf(0.22, 0.09, k)
			var stern := global_transform * Vector3(randf_range(-0.5, 0.5), 0.0, LENGTH * 0.5)
			VFX.splash(get_tree().current_scene, Vector3(stern.x, _surface_height() + 0.05, stern.z), 0.35 + k * 0.4)


func get_seat_transform() -> Transform3D:
	var xf := Transform3D(Basis(Vector3.UP, _yaw), global_position)
	return Transform3D(xf.basis, xf * SEAT + Vector3(0, _visual.position.y, 0))


func can_disembark() -> bool:
	var regions := get_tree().get_nodes_in_group(&"sea_region")
	if regions.is_empty():
		return true
	for r in regions:
		if (r as SeaRegion).contains(global_position):
			return true
	return false


func on_driver_exit(player: Node3D) -> void:
	driver = null
	_board.enabled = true
	_save()
	get_tree().create_timer(0.6, false).timeout.connect(func() -> void:
		if is_instance_valid(player) and is_instance_valid(self) and driver != player:
			(player as PhysicsBody3D).remove_collision_exception_with(self))


func _save() -> void:
	var p := global_position
	WorldState.set_flag(_save_id(), "pos", [p.x, p.y, p.z])
	WorldState.set_flag(_save_id(), "yaw", _yaw)


func _save_id() -> StringName:
	return boat_id


func get_yaw() -> float:
	return _yaw


func get_speed() -> float:
	return _speed


## Holds the boat to `speed` at most (sea mist, a headwind).
func slow_to(speed: float) -> void:
	_speed = minf(_speed, speed)


## Puts the boat at `at`, heading along `dir`, already under way at `speed`.
func place(at: Vector3, dir: Vector3, speed := 0.0) -> void:
	global_position = at
	_yaw = Player.yaw_of(dir)
	_speed = speed
	rotation = Vector3(0, _yaw, 0)


## Seats Patchy at the tiller straight away.
func board_now(player: Player) -> void:
	if driver != null:
		return
	driver = player
	_board.enabled = false
	player.teleport(get_seat_transform().origin, Player.dir_from_yaw(_yaw))
	player.change_state(&"boat", {"vehicle": self, "seated": true})


func _surface_height() -> float:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = global_position + Vector3.UP * 0.6
	q.collide_with_areas = true
	q.collide_with_bodies = false
	q.collision_mask = Layers.WATER
	for hit in get_world_3d().direct_space_state.intersect_point(q, 4):
		var w := hit.collider as WaterVolume
		if w != null:
			return w.get_surface_height(global_position)
	return 0.0


## If Patchy is on land around another island, the boat washes up at that
## island's dock so he can never strand himself.
func _maybe_return_to_dock() -> void:
	var p := GameManager.player as Player
	if p == null or driver != null or p.state_id != &"ground":
		return
	var here: SeaRegion = null
	for r in get_tree().get_nodes_in_group(&"sea_region"):
		if (r as SeaRegion).contains(p.global_position):
			here = r
			break
	if here == null or here.contains(global_position) or here.boat_dock == null:
		return
	global_position = here.boat_dock.global_position
	_yaw = Player.yaw_of(-here.boat_dock.global_basis.z)
	_speed = 0.0
	rotation = Vector3(0, _yaw, 0)
	_save()
