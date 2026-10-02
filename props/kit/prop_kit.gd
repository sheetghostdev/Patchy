class_name PropKit
## Shared helpers for the props & nature kit: transforms, seeded RNGs,
## cached materials (swaying foliage, flames), a small mesh cache, and the
## bookkeeping for generated children. Generated nodes are added in
## INTERNAL_MODE_FRONT and tagged, so they are never saved into scenes and a
## rebuild can always find and replace them (even after a script reload).

const GEN_META := &"_prop_generated"
const CACHE_LIMIT := 384
const FOLIAGE_SHADER := preload("res://props/shaders/foliage_sway.gdshader")
const FLAME_SHADER := preload("res://props/shaders/flame.gdshader")

static var _materials: Dictionary = {}
static var _meshes: Dictionary = {}


static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl), pos)


## Orthonormal basis whose Y axis points along `dir`.
static func basis_y(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var ref := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x := y.cross(ref).normalized()
	var z := x.cross(y).normalized()
	return Basis(x, y, z)


static func make_rng(seed_value: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(Vector2i(seed_value, salt))
	return r


## Picks a color from a palette array with a little value jitter.
static func jitter(c: Color, rng: RandomNumberGenerator, amount: float = 0.06) -> Color:
	var f := rng.randf_range(-amount, amount)
	return c.lightened(f) if f > 0.0 else c.darkened(-f)


# --- Materials -----------------------------------------------------------------------------

## Shared swaying, double-sided foliage material. Profiles tune the motion:
## &"palm" (slow, big fronds), &"leaves" (bushes, ferns), &"grass" (quick,
## small), &"cloth" (sails: flutter), &"bob" (bridge planks: vertical bob),
## &"still" (double-sided, no motion), &"kelp" (slow, deep underwater sway).
static func foliage_material(profile: StringName = &"leaves") -> ShaderMaterial:
	var key := "foliage_%s" % profile
	if _materials.has(key):
		return _materials[key]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE_SHADER
	var p := {}
	match profile:
		&"palm":
			p = {&"sway_strength": 0.16, &"sway_speed": 0.9, &"flutter_strength": 0.025, &"flutter_speed": 3.2, &"weight_power": 1.7}
		&"grass":
			p = {&"sway_strength": 0.07, &"sway_speed": 1.7, &"flutter_strength": 0.01, &"flutter_speed": 5.0, &"weight_power": 1.4}
		&"cloth":
			p = {&"sway_strength": 0.06, &"sway_speed": 1.3, &"flutter_strength": 0.05, &"flutter_speed": 4.2, &"weight_power": 1.0}
		&"bob":
			p = {&"sway_strength": 0.0, &"flutter_strength": 0.0, &"bob_strength": 0.03, &"bob_speed": 1.4, &"weight_power": 1.0, &"backface_darken": 0.0}
		&"still":
			p = {&"sway_strength": 0.0, &"flutter_strength": 0.0}
		&"kelp":
			p = {&"sway_strength": 0.45, &"sway_speed": 0.55, &"flutter_strength": 0.04, &"flutter_speed": 1.6, &"weight_power": 1.25}
		_:
			p = {&"sway_strength": 0.05, &"sway_speed": 1.2, &"flutter_strength": 0.012, &"flutter_speed": 4.0, &"weight_power": 1.5}
	m.set_shader_parameter(&"rim_strength", 0.14)
	m.set_shader_parameter(&"spec_strength", 0.0)
	for k: StringName in p:
		m.set_shader_parameter(k, p[k])
	_materials[key] = m
	return m


## Faceted gems: the toon shader with little sky reflection (keeps the
## facets saturated) and a strong, tight cel highlight for the sparkle.
static func gem_material() -> ShaderMaterial:
	if _materials.has("gem"):
		return _materials["gem"]
	var m := MaterialLibrary.toon(Color.WHITE, &"glossy").duplicate() as ShaderMaterial
	m.set_shader_parameter(&"roughness", 0.85)
	m.set_shader_parameter(&"spec_strength", 0.7)
	m.set_shader_parameter(&"spec_size", 0.95)
	m.set_shader_parameter(&"rim_strength", 0.3)
	m.set_shader_parameter(&"form_shading", 0.4)
	_materials["gem"] = m
	return m


static func flame_material() -> ShaderMaterial:
	if _materials.has("flame"):
		return _materials["flame"]
	var m := ShaderMaterial.new()
	m.shader = FLAME_SHADER
	_materials["flame"] = m
	return m


# --- Mesh cache ----------------------------------------------------------------------------

## Returns a cached mesh for `key`, building it with `maker.call()` once.
## Props with identical parameters (crates, barrels, rocks) share meshes.
static func cached_mesh(key: String, maker: Callable) -> Mesh:
	return cached(key, maker) as Mesh


## Generic cache for anything derived from parameters (meshes + collision
## points, debris piece lists...). `maker.call()` runs once per key.
static func cached(key: String, maker: Callable) -> Variant:
	if _meshes.has(key):
		return _meshes[key]
	# Editor slider tweaking creates many one-off keys: start over now and
	# then (meshes still in use stay alive through their nodes).
	if _meshes.size() >= CACHE_LIMIT:
		_meshes.clear()
	var v: Variant = maker.call()
	_meshes[key] = v
	return v


static func triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var n := 0
	for s in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(s)
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty():
			n += floori((idx as PackedInt32Array).size() / 3.0)
		else:
			n += floori((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3.0)
	return n


# --- Generated children ----------------------------------------------------------------------

static func clear_generated(owner_node: Node) -> void:
	for c in owner_node.get_children(true):
		if c.has_meta(GEN_META):
			owner_node.remove_child(c)
			c.queue_free()


## Adds `child` as an internal, tagged child of `parent` (never saved).
static func add_generated(parent: Node, child: Node, node_name: String = "") -> Node:
	if node_name != "":
		child.name = node_name
	child.set_meta(GEN_META, true)
	parent.add_child(child, false, Node.INTERNAL_MODE_FRONT)
	return child


static func mesh_instance(parent: Node, mesh: Mesh, node_name: String = "Mesh", shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_generated(parent, mi, node_name)
	return mi


static func collision(parent: Node, shape: Shape3D, xform: Transform3D = Transform3D.IDENTITY, node_name: String = "Collision") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform
	add_generated(parent, cs, node_name)
	return cs


static func pivot(parent: Node, node_name: String, xform: Transform3D = Transform3D.IDENTITY) -> Node3D:
	var n := Node3D.new()
	n.transform = xform
	add_generated(parent, n, node_name)
	return n


static func box_shape(size: Vector3) -> BoxShape3D:
	var s := BoxShape3D.new()
	s.size = size
	return s


static func cylinder_shape(radius: float, height: float) -> CylinderShape3D:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	return s


static func capsule_shape(radius: float, height: float) -> CapsuleShape3D:
	var s := CapsuleShape3D.new()
	s.radius = radius
	s.height = maxf(height, radius * 2.0)
	return s


## Capsule collision spanning two points.
static func capsule_between(parent: Node, a: Vector3, b: Vector3, radius: float, node_name: String = "Collision") -> CollisionShape3D:
	var d := b - a
	return collision(parent, capsule_shape(radius, d.length() + radius * 2.0), Transform3D(basis_y(d), (a + b) * 0.5), node_name)
