class_name VFX
## One-shot stylized particle effects (spec §137). Each call spawns a small
## CPUParticles3D burst in the current scene that frees itself. Soft round
## puffs, no textures, readable at gameplay distance.

static var _puff_mesh: SphereMesh
static var _spark_mesh: PrismMesh
static var _materials: Dictionary = {}


static func _get_puff_mesh() -> SphereMesh:
	if _puff_mesh == null:
		_puff_mesh = SphereMesh.new()
		_puff_mesh.radius = 0.5
		_puff_mesh.height = 1.0
		_puff_mesh.radial_segments = 8
		_puff_mesh.rings = 4
	return _puff_mesh


static func _get_spark_mesh() -> PrismMesh:
	if _spark_mesh == null:
		_spark_mesh = PrismMesh.new()
		_spark_mesh.size = Vector3(0.5, 0.7, 0.12)
	return _spark_mesh


static func _material(kind: StringName) -> StandardMaterial3D:
	if _materials.has(kind):
		return _materials[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_BACK
	match kind:
		&"glow":
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.emission_enabled = true
			m.emission = Color(1, 0.9, 0.5)
			m.emission_energy_multiplier = 0.6
		_:
			m.roughness = 1.0
	_materials[kind] = m
	return m


static func _spawn(context: Node, pos: Vector3, amount: int, lifetime: float, mesh: Mesh, kind: StringName = &"puff") -> CPUParticles3D:
	if context == null or not context.is_inside_tree():
		return null
	var root := context.get_tree().current_scene
	if root == null:
		root = context.get_tree().root
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.mesh = mesh
	p.material_override = _material(kind)
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.global_position = pos
	p.emitting = true
	context.get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)
	return p


static func _fade(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(c, c.a))
	g.set_color(1, Color(c, 0.0))
	return g


static func _grow_shrink(peak: float = 0.3) -> Curve:
	var cv := Curve.new()
	cv.add_point(Vector2(0.0, 0.35))
	cv.add_point(Vector2(peak, 1.0))
	cv.add_point(Vector2(1.0, 0.0))
	return cv


## Little dust puffs at the feet (footsteps, takeoffs, skids).
static func dust(context: Node, pos: Vector3, amount: int = 6, size: float = 0.35, color: Color = Color(0.96, 0.92, 0.82, 0.7), spread: float = 1.2, rise: float = 1.0) -> void:
	var p := _spawn(context, pos, amount, 0.45, _get_puff_mesh())
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = spread * 0.5
	p.initial_velocity_max = spread * 1.4
	p.gravity = Vector3(0, rise * 0.8, 0)
	p.damping_min = 3.0
	p.damping_max = 5.0
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size * 1.2
	p.scale_amount_curve = _grow_shrink()
	p.color_ramp = _fade(color)


## Expanding ring of dust (landings, ground pounds).
static func ring(context: Node, pos: Vector3, radius: float = 1.0, amount: int = 14, color: Color = Color(0.96, 0.92, 0.82, 0.9)) -> void:
	var p := _spawn(context, pos + Vector3.UP * 0.1, amount, 0.6, _get_puff_mesh())
	if p == null:
		return
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = radius * 0.35
	p.emission_ring_inner_radius = radius * 0.3
	p.emission_ring_height = 0.05
	p.direction = Vector3.UP
	p.spread = 90.0
	p.flatness = 0.85
	p.initial_velocity_min = radius * 3.0
	p.initial_velocity_max = radius * 4.5
	p.damping_min = radius * 6.0
	p.damping_max = radius * 8.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.35 * radius
	p.scale_amount_max = 0.55 * radius
	p.scale_amount_curve = _grow_shrink(0.2)
	p.color_ramp = _fade(color)


## Water splash: droplets up and out, plus a foam ring.
static func splash(context: Node, pos: Vector3, size: float = 1.0) -> void:
	var p := _spawn(context, pos, int(14 * size) + 4, 0.8, _get_puff_mesh())
	if p != null:
		p.direction = Vector3.UP
		p.spread = 35.0
		p.initial_velocity_min = 3.5 * size
		p.initial_velocity_max = 6.5 * size
		p.gravity = Vector3(0, -18, 0)
		p.scale_amount_min = 0.12 * size
		p.scale_amount_max = 0.24 * size
		p.scale_amount_curve = _grow_shrink(0.1)
		p.color_ramp = _fade(Color(0.85, 0.98, 1.0, 0.95))
	ring(context, pos, 0.9 * size, int(12 * size), Color(0.92, 1.0, 1.0, 0.85))


## Bright twinkles (treasure pickups, parrot rescues, chest openings).
static func sparkle(context: Node, pos: Vector3, color: Color = Color(1.0, 0.85, 0.3), amount: int = 10, speed: float = 3.0) -> void:
	var p := _spawn(context, pos, amount, 0.7, _get_spark_mesh(), &"glow")
	if p == null:
		return
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -2, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45
	p.scale_amount_curve = _grow_shrink(0.15)
	p.color_ramp = _fade(color)


## Comic impact stars (hits, bonks, ground-pound smashes).
static func impact(context: Node, pos: Vector3, color: Color = Color(1.0, 0.95, 0.7), amount: int = 7) -> void:
	sparkle(context, pos, color, amount, 5.0)
	dust(context, pos, 4, 0.3, Color(1, 1, 1, 0.8), 2.0, 0.2)
