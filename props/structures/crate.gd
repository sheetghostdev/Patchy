@tool
class_name Crate
extends BreakableProp
## Chunky wooden crate: a thick bevelled frame around recessed planks over a
## dark core (the gaps read as plank seams). Readability rule: breakable
## crates (default) use light, honey-colored wood with a diagonal brace;
## sturdy crates use darker wood with iron corner caps and a band (metal =
## won't break). Origin at the bottom center. See BreakableProp for the
## hit / break / contents / persistence behavior.

enum Style { AUTO, SLATS, BRACED, BANDED }

@export var size := Vector3.ONE:
	set(v):
		size = v.max(Vector3.ONE * 0.2)
		_queue_rebuild()
## AUTO: BRACED when breakable, BANDED when not.
@export var style := Style.AUTO:
	set(v):
		style = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"wood"


func _center() -> Vector3:
	return Vector3.UP * size.y * 0.5


func resolved_style() -> Style:
	if style != Style.AUTO:
		return style
	return Style.BRACED if breakable else Style.BANDED


func _build() -> void:
	var st := resolved_style()
	var mesh := PropKit.cached_mesh("crate_%s_%d_%d_%d" % [size, st, int(breakable), seed], func() -> Mesh:
		return build_mesh(size, st, breakable, seed)
	)
	add_mesh(mesh, "Crate")
	add_shape(PropKit.box_shape(size), Transform3D(Basis.IDENTITY, Vector3.UP * size.y * 0.5))


static func build_mesh(s: Vector3, st: Style, light: bool, seed_value: int) -> ArrayMesh:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed_value, 55)
	var plank: Color = PropPalette.CRATE_BREAKABLE if light else PropPalette.PLANK
	var frame: Color = PropPalette.CRATE_BREAKABLE_FRAME if light else PropPalette.WOOD_FRAME
	var m := minf(s.x, minf(s.y, s.z))
	var t := m * 0.15
	var bev := t * 0.24
	var h := s * 0.5
	var c := Vector3(0, h.y, 0)
	var mt := parts.matte
	# Dark core shows through the seams between planks.
	mt.box(s - Vector3.ONE * t * 0.9, Transform3D(Basis.IDENTITY, c), PropPalette.WOOD_DEEP)
	# Frame: four posts and eight rails.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mt.chamfer_box(Vector3(t, s.y, t), bev, Transform3D(Basis.IDENTITY, c + Vector3(sx * (h.x - t * 0.5), 0, sz * (h.z - t * 0.5))), PropKit.jitter(frame, rng, 0.04))
	for sy: float in [-1.0, 1.0]:
		var y := sy * (h.y - t * 0.5)
		for sz: float in [-1.0, 1.0]:
			mt.chamfer_box(Vector3(s.x - t * 2.0, t, t), bev, Transform3D(Basis.IDENTITY, c + Vector3(0, y, sz * (h.z - t * 0.5))), PropKit.jitter(frame, rng, 0.04))
		for sx: float in [-1.0, 1.0]:
			mt.chamfer_box(Vector3(t, t, s.z - t * 2.0), bev, Transform3D(Basis.IDENTITY, c + Vector3(sx * (h.x - t * 0.5), y, 0)), PropKit.jitter(frame, rng, 0.04))
	# Recessed planks on the four sides and the top.
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	var recess := m * 0.035
	var pt := m * 0.05
	var gap := m * 0.03
	var count := 3
	for fi in faces.size():
		var f: Array = faces[fi]
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var su := absf(s.dot(u)) - t * 2.0
		var sv := absf(s.dot(v)) - t * 2.0
		var depth := absf(s.dot(n)) * 0.5
		var plank_w := (sv - gap * (count - 1)) / count
		for k in count:
			var off := -sv * 0.5 + plank_w * 0.5 + k * (plank_w + gap)
			var pos := c + n * (depth - recess - pt * 0.5) + v * off
			var orient := Basis(u, v, n)
			mt.box(Vector3(su + t * 0.4, plank_w, pt), Transform3D(orient, pos), PropKit.jitter(plank, rng, 0.06))
		var fc := c + n * (depth - recess * 0.4)
		if st == Style.BRACED and fi < 4:
			var dsign := 1.0 if fi % 2 == 0 else -1.0
			var a := fc - u * su * 0.5 * dsign - v * sv * 0.5
			var b := fc + u * su * 0.5 * dsign + v * sv * 0.5
			mt.beam(a, b, t * 0.8, t * 0.45, bev * 0.8, PropKit.jitter(frame, rng, 0.03), n)
		elif st == Style.BANDED and fi < 4:
			# Iron band around the middle.
			var bw := t * 0.55
			parts.metal.chamfer_box(Vector3(absf(s.dot(u)) + 0.02, bw, 0.035), 0.01, Transform3D(Basis(u, v, n), c + n * (depth + 0.012)), PropPalette.IRON)
	if st == Style.BANDED:
		# Iron corner caps.
		var cap := t * 1.3
		for sx: float in [-1.0, 1.0]:
			for sy: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var p := c + Vector3(sx * (h.x - t * 0.5), sy * (h.y - t * 0.5), sz * (h.z - t * 0.5))
					parts.metal.chamfer_box(Vector3.ONE * cap, cap * 0.2, Transform3D(Basis.IDENTITY, p), PropPalette.IRON_LIGHT)
	return parts.build()


func _debris_pieces() -> Array:
	var light := breakable
	var key := "crate_debris_%s_%d" % [size, int(light)]
	return PropKit.cached(key, func() -> Array:
		var plank: Color = PropPalette.CRATE_BREAKABLE if light else PropPalette.PLANK
		var frame: Color = PropPalette.CRATE_BREAKABLE_FRAME if light else PropPalette.WOOD_FRAME
		var m := minf(size.x, minf(size.y, size.z))
		var t := m * 0.15
		var specs := [
			Vector3(size.x * 0.78, m * 0.06, m * 0.22),
			Vector3(size.x * 0.48, m * 0.06, m * 0.22),
			Vector3(t, t, size.y * 0.62),
			Vector3(m * 0.3, m * 0.06, m * 0.12),
		]
		var out := []
		for k in specs.size():
			var mb := PropBuilder.new()
			var sz: Vector3 = specs[k]
			mb.chamfer_box(sz, minf(sz.y, sz.z) * 0.22, Transform3D.IDENTITY, frame if k == 2 else plank)
			out.append([mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte")), sz])
		return out
	)


func _debris_count() -> int:
	return 8
