@tool
class_name LanternPost
extends PropBody
## Wooden lamp post with a braced arm and a hanging metal lantern whose glass
## glows (emissive) and holds a warm OmniLight3D. The lantern sways gently at
## runtime on its `lantern` pivot. Collision: the post.

@export_range(1.5, 5.0, 0.05) var height := 2.6:
	set(v):
		height = v
		_queue_rebuild()
@export_range(0.3, 1.5, 0.01) var arm_length := 0.75:
	set(v):
		arm_length = v
		_queue_rebuild()
@export var lit := true:
	set(v):
		lit = v
		_queue_rebuild()
@export_range(0.0, 8.0, 0.05) var light_energy := 1.4:
	set(v):
		light_energy = v
		_queue_rebuild()
@export_range(1.0, 20.0, 0.1) var light_range := 7.0:
	set(v):
		light_range = v
		_queue_rebuild()
@export var light_color := Color(1.0, 0.82, 0.55):
	set(v):
		light_color = v
		_queue_rebuild()
## Brass instead of iron fittings.
@export var brass := false:
	set(v):
		brass = v
		_queue_rebuild()
@export var swing := true

## Pivot the lantern hangs from (rotate it to animate).
var lantern: Node3D
var light: OmniLight3D
var _t := 0.0


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var parts := PropParts.new()
	var mt := parts.matte
	var wood := PropPalette.WOOD_FRAME.darkened(0.08)
	mt.chamfer_box(Vector3(0.36, 0.3, 0.36), 0.05, Transform3D(Basis.IDENTITY, Vector3.UP * 0.1), Palette.STONE)
	mt.chamfer_box(Vector3(0.18, height + 0.1, 0.18), 0.035, Transform3D(Basis.IDENTITY, Vector3.UP * (height + 0.1) * 0.5 - Vector3.UP * 0.05), wood)
	var cap := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.15, 0.0), Vector2(0.15, 0.04), Vector2(0.0, 0.14)])
	mt.lathe(cap, 4, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3.UP * height), wood.darkened(0.15), PackedColorArray(), true)
	var arm_y := height - 0.18
	mt.beam(Vector3(-0.05, arm_y, 0), Vector3(arm_length + 0.06, arm_y, 0), 0.11, 0.13, 0.025, wood)
	mt.beam(Vector3(0.06, arm_y - 0.48, 0), Vector3(arm_length * 0.6, arm_y - 0.03, 0), 0.08, 0.08, 0.02, wood.darkened(0.06))
	add_mesh(parts.build(), "Post")
	# Lantern on its own pivot so it can sway.
	var hook := Vector3(arm_length - 0.06, arm_y - 0.065, 0)
	lantern = PropKit.pivot(self, "Lantern", Transform3D(Basis.IDENTITY, hook))
	var lp := PropParts.new()
	lp.glow_color = PropPalette.LAMP_GLOW
	var fit: Color = Palette.BRASS if brass else PropPalette.IRON
	lp.metal.torus(0.02, 0.045, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.DOWN * 0.03), fit, 10, 4)
	lp.metal.rod(Vector3.DOWN * 0.06, Vector3.DOWN * 0.16, 0.012, 0.012, fit, 5, false)
	var hood := PackedVector2Array([Vector2(0.13, -0.3), Vector2(0.17, -0.29), Vector2(0.16, -0.26), Vector2(0.05, -0.15), Vector2(0.0, -0.13)])
	lp.metal.lathe(hood, 8, Transform3D.IDENTITY, fit, PackedColorArray(), true)
	if lit:
		lp.glow.cylinder(0.115, 0.115, 0.22, Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.41), Color.WHITE, 8)
	else:
		lp.glossy.cylinder(0.115, 0.115, 0.22, Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.41), Color("cfe6ee"), 8)
	for k in 4:
		var a := PI * 0.25 + PI * 0.5 * k
		var d := Vector3(cos(a), 0.0, sin(a)) * 0.125
		lp.metal.rod(d + Vector3.DOWN * 0.29, d + Vector3.DOWN * 0.53, 0.014, 0.014, fit, 4, false)
	var base := PackedVector2Array([Vector2(0.0, -0.64), Vector2(0.03, -0.62), Vector2(0.1, -0.59), Vector2(0.15, -0.55), Vector2(0.14, -0.52)])
	lp.metal.lathe(base, 8, Transform3D.IDENTITY, fit, PackedColorArray(), true)
	PropKit.mesh_instance(lantern, lp.build(), "LanternMesh")
	if lit:
		light = OmniLight3D.new()
		light.light_specular = 0.0  # no cel glint discs on nearby walls
		light.light_color = light_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.2
		light.position = Vector3.DOWN * 0.41
		PropKit.add_generated(lantern, light, "Light")
	else:
		light = null
	add_shape(PropKit.box_shape(Vector3(0.22, height, 0.22)), Transform3D(Basis.IDENTITY, Vector3.UP * height * 0.5))


func _process(delta: float) -> void:
	if lantern == null or not swing or Engine.is_editor_hint():
		return
	_t += delta
	lantern.rotation = Vector3(sin(_t * 0.9 + 1.0) * 0.04, 0.0, sin(_t * 1.3) * 0.06)
	if light != null:
		light.light_energy = light_energy * (1.0 + sin(_t * 9.0) * 0.03)
