@tool
class_name Barrel
extends BreakableProp
## Bulging wooden barrel: twelve staves in alternating warm tones over a dark
## core (crisp seams), four metal hoops and a recessed plank lid. Breakable by
## default (see BreakableProp); can lie on its side for beach set dressing.
## Origin at the bottom center (on the ground also when lying).

enum Hoops { IRON, BRASS }

@export_range(0.5, 3.0, 0.01) var height := 1.1:
	set(v):
		height = v
		_queue_rebuild()
@export_range(0.2, 1.5, 0.01) var radius := 0.44:
	set(v):
		radius = v
		_queue_rebuild()
@export var hoops := Hoops.IRON:
	set(v):
		hoops = v
		_queue_rebuild()
## Lies on its side (rolled 90 degrees about Z).
@export var lying := false:
	set(v):
		lying = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const STAVES := 12


func _surface() -> StringName:
	return &"wood"


func _center() -> Vector3:
	return Vector3.UP * (radius if lying else height * 0.5)


func _build() -> void:
	var mesh := PropKit.cached_mesh("barrel_%.2f_%.2f_%d_%d" % [height, radius, hoops, seed], func() -> Mesh:
		return build_mesh(height, radius, hoops, seed)
	)
	var mi := add_mesh(mesh, "Barrel")
	var shape := PropKit.cylinder_shape(radius * 0.97, height)
	if lying:
		# Roll onto its side, centered on the origin, resting on the ground.
		mi.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(height * 0.5, radius * 0.97, 0))
		add_shape(shape, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, radius * 0.97, 0)))
	else:
		add_shape(shape, Transform3D(Basis.IDENTITY, Vector3.UP * height * 0.5))


static func _profile_r(y: float, h: float, r_mid: float) -> float:
	var r_end := r_mid * 0.84
	return r_end + (r_mid - r_end) * sin(PI * clampf(y / h, 0.0, 1.0))


static func build_mesh(h: float, r_mid: float, hoop_kind: Hoops, seed_value: int) -> ArrayMesh:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed_value, 66)
	var mt := parts.matte
	var rows := 6
	# Dark core behind the staves.
	var core := PackedVector2Array()
	for j in rows + 1:
		var y := h * float(j) / rows
		core.append(Vector2(_profile_r(y, h, r_mid) * 0.95, y))
	mt.lathe(core, STAVES, Transform3D.IDENTITY, PropPalette.WOOD_DEEP)
	# Staves: flat strips following the bulge, each its own tone.
	var gap := 0.018
	for i in STAVES:
		var a0 := TAU * float(i) / STAVES + gap * 0.5
		var a1 := TAU * float(i + 1) / STAVES - gap * 0.5
		var col := PropKit.jitter(PropPalette.PLANK if i % 2 == 0 else PropPalette.PLANK_LIGHT, rng, 0.05)
		var base := mt.mark()
		for j in rows + 1:
			var y := h * float(j) / rows
			var r := _profile_r(y, h, r_mid)
			var dr := (_profile_r(y + 0.01, h, r_mid) - _profile_r(y - 0.01, h, r_mid)) / 0.02
			for a: float in [a0, a1]:
				var d := Vector3(cos(a), 0.0, sin(a))
				mt.vert(d * r + Vector3.UP * y, (d - Vector3.UP * dr).normalized(), col, Vector2(0, float(j) / rows))
		for j in rows:
			var k := base + j * 2
			var mid_a := (a0 + a1) * 0.5
			mt.quad(k, k + 1, k + 3, k + 2, Vector3(cos(mid_a), 0.0, sin(mid_a)))
		# Stave end grain on the top rim.
		var rt := _profile_r(h, h, r_mid)
		var ri := rt - r_mid * 0.09
		var top := PackedVector3Array()
		for a: float in [a0, a1]:
			var d := Vector3(cos(a), 0.0, sin(a))
			top.append(d * rt + Vector3.UP * h)
			top.append(d * ri + Vector3.UP * h)
		mt.flat_quad(top[0], top[2], top[3], top[1], Vector3.UP, col.darkened(0.08))
	# Recessed lid made of three planks.
	var lid_r := _profile_r(h, h, r_mid) * 0.93
	var circle := PackedVector2Array()
	for k in 20:
		var a := TAU * float(k) / 20.0
		circle.append(Vector2(cos(a), sin(a)) * lid_r)
	var lid_y := h - r_mid * 0.08
	var lid_basis := Basis(Vector3.RIGHT, -PI * 0.5)
	for k in 3:
		var x0 := -lid_r + k * lid_r * 2.0 / 3.0 + 0.008
		var x1 := -lid_r + (k + 1) * lid_r * 2.0 / 3.0 - 0.008
		var strip := PackedVector2Array([Vector2(x0, -lid_r), Vector2(x1, -lid_r), Vector2(x1, lid_r), Vector2(x0, lid_r)])
		for poly in Geometry2D.intersect_polygons(circle, strip):
			mt.extrude(poly, 0.04, Transform3D(lid_basis, Vector3.UP * lid_y), PropKit.jitter(PropPalette.PLANK_LIGHT if k == 1 else PropPalette.PLANK, rng, 0.04))
	# Hoops.
	var hoop_col: Color = PropPalette.IRON if hoop_kind == Hoops.IRON else Palette.BRASS
	for f: float in [0.09, 0.27, 0.73, 0.91]:
		var y := h * f
		var r := _profile_r(y, h, r_mid)
		var hh := h * 0.035
		var prof := PackedVector2Array([
			Vector2(r - 0.01, y - hh), Vector2(r + 0.028, y - hh + 0.008),
			Vector2(r + 0.028, y + hh - 0.008), Vector2(r - 0.01, y + hh),
		])
		parts.metal.lathe(prof, 16, Transform3D.IDENTITY, hoop_col, PackedColorArray(), true)
	return parts.build()


func _debris_pieces() -> Array:
	var key := "barrel_debris_%.2f_%.2f_%d" % [height, radius, hoops]
	return PropKit.cached(key, func() -> Array:
		var stave := Vector3(TAU * radius / STAVES * 0.95, height * 0.8, radius * 0.11)
		var specs := [
			[stave, PropPalette.PLANK, &"matte"],
			[Vector3(stave.x, height * 0.5, stave.z), PropPalette.PLANK_LIGHT, &"matte"],
			[Vector3(radius * 0.9, 0.04, radius * 0.5), PropPalette.PLANK_LIGHT, &"matte"],
			[Vector3(radius * 0.9, height * 0.07, 0.04), PropPalette.IRON if hoops == Hoops.IRON else Palette.BRASS, &"metal"],
		]
		var out := []
		for sp: Array in specs:
			var mb := PropBuilder.new()
			var sz: Vector3 = sp[0]
			mb.chamfer_box(sz, minf(sz.y, minf(sz.x, sz.z)) * 0.22, Transform3D.IDENTITY, sp[1])
			out.append([mb.build(null, MaterialLibrary.toon(Color.WHITE, sp[2])), sz])
		return out
	)


func _debris_count() -> int:
	return 9
