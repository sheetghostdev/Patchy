@tool
class_name Torch
extends PropBody
## Tiki torch: a banded bamboo pole with a woven basket head holding a
## cartoon flame (props/shaders/flame.gdshader: fresnel core, flickering
## vertices) and a warm OmniLight3D that flickers at runtime. Collision: a
## slim capsule around the pole.

@export_range(0.6, 3.0, 0.01) var height := 1.7:
	set(v):
		height = v
		_queue_rebuild()
@export var lit := true:
	set(v):
		lit = v
		_queue_rebuild()
@export_range(0.0, 8.0, 0.05) var light_energy := 1.6:
	set(v):
		light_energy = v
		_queue_rebuild()
@export_range(1.0, 20.0, 0.1) var light_range := 6.0:
	set(v):
		light_range = v
		_queue_rebuild()
@export var light_color := PropPalette.TORCH_LIGHT:
	set(v):
		light_color = v
		_queue_rebuild()
@export var flicker := true
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

var light: OmniLight3D
var _t := 0.0


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var rng := PropKit.make_rng(seed, 41)
	var parts := PropParts.new()
	var mt := parts.matte
	# Banded bamboo pole.
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	var nodes := 4
	var r := 0.055
	var pole_top := height - 0.32
	for n in nodes:
		var y0 := -0.1 + (pole_top + 0.1) * float(n) / nodes
		var y1 := -0.1 + (pole_top + 0.1) * float(n + 1) / nodes
		pts.append(Vector3(0, y0, 0))
		radii.append(r * 1.15)
		pts.append(Vector3(0, lerpf(y0, y1, 0.07), 0))
		radii.append(r)
		cols.append(PropPalette.BAMBOO_DARK)
		cols.append(PropKit.jitter(PropPalette.BAMBOO, rng, 0.04))
	pts.append(Vector3(0, pole_top, 0))
	radii.append(r)
	mt.banded_tube(pts, radii, cols, 8)
	# Woven basket head: flared cup in alternating straw bands.
	var cup := PackedVector2Array([
		Vector2(r * 0.9, pole_top - 0.02), Vector2(0.11, pole_top + 0.06), Vector2(0.15, pole_top + 0.16),
		Vector2(0.16, pole_top + 0.24), Vector2(0.13, pole_top + 0.25), Vector2(0.0, pole_top + 0.22),
	])
	mt.lathe(cup, 12, Transform3D.IDENTITY, Color.WHITE, PackedColorArray([PropPalette.ROPE_DARK, Palette.ROPE, PropPalette.ROPE_DARK, PropPalette.ROPE_LIGHT, PropPalette.WOOD_DEEP]), true)
	mt.torus(0.13, 0.175, Transform3D(Basis.IDENTITY, Vector3.UP * (pole_top + 0.2)), PropPalette.ROPE_DARK, 14, 5)
	mt.torus(0.07, 0.1, Transform3D(Basis.IDENTITY, Vector3.UP * (pole_top + 0.02)), Palette.ROPE, 10, 4)
	add_mesh(parts.build(), "Torch")
	if lit:
		var flame := MeshInstance3D.new()
		flame.mesh = flame_mesh()
		flame.material_override = PropKit.flame_material()
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3.UP * (pole_top + 0.2)
		PropKit.add_generated(self, flame, "Flame")
		light = OmniLight3D.new()
		light.light_specular = 0.0  # no cel glint discs on nearby walls
		light.light_color = light_color
		light.light_energy = light_energy
		light.omni_range = light_range
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.position = Vector3.UP * (pole_top + 0.45)
		PropKit.add_generated(self, light, "Light")
	else:
		light = null
	PropKit.capsule_between(self, Vector3.UP * 0.1, Vector3.UP * (height - 0.2), 0.12)


## Teardrop flame (shared by torches and braziers). UV.y runs base -> tip.
static func flame_mesh(size_scale: float = 1.0) -> Mesh:
	return PropKit.cached_mesh("flame_%.2f" % size_scale, func() -> Mesh:
		var mb := PropBuilder.new()
		var s := size_scale
		var prof := PackedVector2Array([
			Vector2(0.0, -0.02 * s), Vector2(0.1 * s, 0.02 * s), Vector2(0.135 * s, 0.1 * s), Vector2(0.12 * s, 0.2 * s),
			Vector2(0.08 * s, 0.31 * s), Vector2(0.035 * s, 0.42 * s), Vector2(0.0, 0.5 * s),
		])
		mb.lathe(prof, 12, Transform3D.IDENTITY, Color.WHITE)
		return mb.build()
	)


func _process(delta: float) -> void:
	if light == null or not flicker or Engine.is_editor_hint():
		return
	_t += delta
	var n := sin(_t * 13.0) * 0.5 + sin(_t * 7.3 + 1.7) * 0.3 + sin(_t * 23.0 + 0.4) * 0.2
	light.light_energy = light_energy * (1.0 + n * 0.12)
