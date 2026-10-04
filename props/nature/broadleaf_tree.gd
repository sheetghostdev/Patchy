@tool
class_name BroadleafTree
extends PropBody
## A round, puffy broadleaf tree (Castaway Cay's north forest, in the spirit
## of Wind Waker's Forest Haven): a stout, slightly twisting trunk on a flare
## of roots, a branch or two, and a crown of big faceted leaf clumps that
## sway gently (props/shaders/foliage_sway.gdshader). Origin at the trunk
## base. Collision: the trunk, and the crown as a soft sphere you can land on.

@export_range(3.0, 14.0, 0.1) var height := 7.0:
	set(v):
		height = v
		_queue_rebuild()
@export_range(1.0, 6.0, 0.05) var crown_radius := 2.8:
	set(v):
		crown_radius = v
		_queue_rebuild()
## Leaf color family: 0 green, 1 deep green, 2 lime, 3 autumn gold.
@export_range(0, 3) var tint := 0:
	set(v):
		tint = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const LEAVES := [
	[Color("3f9a3c"), Color("5cb84a"), Color("2f7d38")],
	[Color("2b7a3a"), Color("3f9a4a"), Color("1f5e30")],
	[Color("78c64a"), Color("9ad65a"), Color("5aa83e")],
	[Color("e0a43a"), Color("f2c14e"), Color("c97a2e")],
]
const BARK := Color("8a6446")


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var parts := PropParts.new()
	parts.foliage_profile = &"leaves"
	var rng := PropKit.make_rng(seed, 701)
	var trunk_top := height - crown_radius * 0.6
	var bend := Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var r0 := 0.2 + height * 0.035
	for i in 6:
		var t := float(i) / 5.0
		pts.append(Vector3(0, t * trunk_top, 0) + bend * sin(t * PI * 0.8))
		radii.append(lerpf(r0, r0 * 0.55, t))
	parts.matte.tube(pts, radii, BARK, 9, true)
	# Root flare.
	for k in 4:
		var a := TAU * k / 4.0 + rng.randf_range(-0.3, 0.3)
		var d := Vector3(cos(a), 0, sin(a))
		parts.matte.tube(PackedVector3Array([Vector3(0, 0.6, 0), d * r0 * 1.6 + Vector3.UP * 0.15, d * r0 * 2.6 + Vector3.DOWN * 0.05]), PackedFloat32Array([r0 * 0.6, r0 * 0.4, r0 * 0.15]), BARK.darkened(0.1), 6, true)
	# Branches out to the side clumps.
	var crown := pts[pts.size() - 1]
	var clumps: Array = [[crown + Vector3.UP * crown_radius * 0.35, crown_radius]]
	var n := 3 + rng.randi() % 3
	for k in n:
		var a := TAU * k / n + rng.randf_range(-0.4, 0.4)
		var out := Vector3(cos(a), 0, sin(a))
		var p := crown + out * crown_radius * rng.randf_range(0.6, 0.85) + Vector3.UP * rng.randf_range(-0.5, 0.6)
		clumps.append([p, crown_radius * rng.randf_range(0.55, 0.75)])
		if k < 2:
			parts.matte.tube(PackedVector3Array([crown + Vector3.DOWN * 0.6, crown.lerp(p, 0.5) + Vector3.DOWN * 0.1, p]), PackedFloat32Array([r0 * 0.5, r0 * 0.35, r0 * 0.2]), BARK, 6, false)
	var cols: Array = LEAVES[tint]
	for c: Array in clumps:
		var center: Vector3 = c[0]
		var r: float = c[1]
		var col: Color = PropKit.jitter(cols[rng.randi() % cols.size()], rng, 0.05)
		var from := parts.foliage.mark()
		parts.foliage.append(HorizonIsland.lump(Vector3(r, r * 0.82, r), rng.randi(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), center), 0.16, [], 7, 10))
		parts.foliage.recolor(func(p: Vector3, _n: Vector3, _c: Color) -> Color:
			var k := clampf((p.y - center.y) / r * 0.5 + 0.5, 0.0, 1.0)
			return cols[2].lerp(col, k).lerp(cols[1], maxf(k - 0.7, 0.0) * 2.0), from)
	parts.foliage.flat_shade()
	add_mesh(parts.build(), "Tree")
	add_shape(PropKit.cylinder_shape(r0, trunk_top), Transform3D(Basis.IDENTITY, Vector3.UP * trunk_top * 0.5), "Trunk")
	var top := SphereShape3D.new()
	top.radius = crown_radius * 0.9
	add_shape(top, Transform3D(Basis.IDENTITY, crown + Vector3.UP * crown_radius * 0.35), "Crown")
