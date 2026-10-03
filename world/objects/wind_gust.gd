@tool
class_name WindGust
extends Area3D
## A lane of sea wind (Hat Rock's spiral ledge, docs/ARCHIPELAGO.md). Every
## `period` seconds a gust blows through the box along the node's -Z: first
## a warning (the pennant lifts, faint streaks, a rising whistle), then the
## gust itself, which blows Patchy along (Player.wind) unless he crouches
## to brace. Walking into it holds him still. The lane is the box `size`
## centred on the node, standing on its floor.

@export var size := Vector3(10, 5, 8):
	set(v):
		size = v
		_rebuild()
## Wind speed during a gust (m/s).
@export_range(0.0, 20.0, 0.1) var strength := 7.5
## How much of the gust gets through while Patchy crouches on the ground.
@export_range(0.0, 1.0, 0.01) var brace := 0.03
@export_range(1.0, 20.0, 0.1) var period := 4.6
@export_range(0.1, 4.0, 0.05) var warn_time := 1.1
@export_range(0.1, 6.0, 0.05) var gust_time := 1.5
## Shifts this lane's cycle so neighbouring lanes take turns.
@export_range(0.0, 20.0, 0.05) var offset := 0.0
## Where the pennant stands (local), or the lane's back corner if unset.
@export var pennant_at := Vector3.INF

const STREAKS := 16

var _t := 0.0
var _shape: CollisionShape3D
var _streaks: Array[MeshInstance3D] = []
var _streak_pos: Array[Vector3] = []
var _pennant: Node3D
var _flag: MeshInstance3D
var _was_warning := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	_t = offset


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		_shape.shape = BoxShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	(_shape.shape as BoxShape3D).size = size
	_shape.position = Vector3(0, size.y * 0.5, 0)
	for s in _streaks:
		s.queue_free()
	_streaks.clear()
	_streak_pos.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.75)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in STREAKS:
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = rng.randf_range(1.6, 3.4)
		cyl.radial_segments = 4
		cyl.rings = 1
		mi.mesh = cyl
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.basis = Basis(Vector3.RIGHT, PI * 0.5)
		mi.visible = false
		add_child(mi, false, Node.INTERNAL_MODE_FRONT)
		_streaks.append(mi)
		_streak_pos.append(Vector3(rng.randf_range(-0.5, 0.5) * size.x, rng.randf_range(0.3, 0.9) * size.y, rng.randf_range(-0.5, 0.5) * size.z))
	if _pennant != null:
		_pennant.queue_free()
	_pennant = Node3D.new()
	_pennant.position = pennant_at if pennant_at != Vector3.INF else Vector3(size.x * 0.5 - 0.4, 0, size.z * 0.5 - 0.4)
	add_child(_pennant, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	mb.cylinder(0.06, 0.08, 2.6, Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0)), Palette.WOOD_DARK, 6)
	mb.sphere(0.11, Transform3D(Basis.IDENTITY, Vector3(0, 2.65, 0)), Palette.BRASS, 6, 8)
	var pole := MeshInstance3D.new()
	pole.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_pennant.add_child(pole)
	var fb := MeshBuilder.new()
	fb.triangle(Vector3(0, 0.22, 0), Vector3(0, -0.22, 0), Vector3(0, 0, 1.3), Color("e8433a"), true)
	fb.triangle(Vector3(0, -0.22, 0), Vector3(0, 0.22, 0), Vector3(0, 0, 1.3), Color("e8433a"), true)
	_flag = MeshInstance3D.new()
	_flag.mesh = fb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_flag.position = Vector3(0, 2.35, 0)
	_pennant.add_child(_flag)


## Seconds into the current cycle.
func cycle_time() -> float:
	return fposmod(_t, period)


func is_warning() -> bool:
	return cycle_time() < warn_time


func is_gusting() -> bool:
	var c := cycle_time()
	return c >= warn_time and c < warn_time + gust_time


## The way the wind blows (world, flat).
func blow_dir() -> Vector3:
	return Player.flat(-global_basis.z).normalized()


## How hard it blows now, 0..1 (eases in and out of each gust).
func gust_level() -> float:
	var c := cycle_time() - warn_time
	if c < 0.0 or c >= gust_time:
		return 0.0
	return clampf(minf(c / 0.2, (gust_time - c) / 0.3), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	var warning := is_warning()
	if warning and not _was_warning:
		var p := GameManager.player as Player
		if p != null and p.global_position.distance_to(global_position) < 45.0:
			AudioManager.play(&"wind_gust", global_position, 0.0, 1.0, 0.05)
	_was_warning = warning
	var level := gust_level()
	if level <= 0.0:
		return
	for body in get_overlapping_bodies():
		var p := body as Player
		if p == null:
			continue
		var k := strength * level
		if p.is_on_floor() and p.input.is_held(&"crouch"):
			k *= brace
		p.wind += blow_dir() * k


func _process(delta: float) -> void:
	if _streaks.is_empty():
		return
	var c := cycle_time()
	var warn := clampf(c / maxf(warn_time, 0.01), 0.0, 1.0) if c < warn_time else 0.0
	var gust := gust_level()
	var show := maxf(warn * 0.35, gust)
	# Streaks race down the lane (local -Z), more of them as it builds.
	for i in _streaks.size():
		var mi := _streaks[i]
		var on := show > 0.0 and float(i) / STREAKS < show
		mi.visible = on
		if not on:
			continue
		var base := _streak_pos[i]
		var speed := 26.0 if gust > 0.0 else 14.0
		var u := fposmod(base.z + (_t + i * 0.37) * speed, size.z + 6.0)
		mi.position = Vector3(base.x, base.y, size.z * 0.5 + 3.0 - u)
		mi.transparency = clampf(1.0 - show, 0.0, 0.9)
	# The pennant: droops in the calm, lifts on the warning, streams out
	# straight downwind in a gust.
	if _flag != null:
		var lift := maxf(warn * 0.5, gust)
		var flutter := sin(_t * (9.0 + 14.0 * lift)) * (0.35 - 0.2 * lift)
		var droop := lerpf(1.15, 0.05, lift)
		_flag.basis = Basis.from_euler(Vector3(droop, PI + flutter, 0.0))
