class_name PropBuilder
extends MeshBuilder
## MeshBuilder with the extra primitives the props kit needs: chamfered
## boxes, lathes (surfaces of revolution), banded tubes with crisp color
## rings, extruded/bevelled polygons, sheets with holes, plus range tools
## (transform, recolor, UV tagging, smooth normals). Same conventions as
## MeshBuilder: vertex colors in sRGB, callers think in outward normals.
##
## UV doubles as animation data for the swaying foliage shader
## (props/shaders/foliage_sway.gdshader): UV.y = sway weight (0 rooted,
## 1 free tip), UV.x = phase offset.


# --- Raw access ------------------------------------------------------------------

## Current vertex count; pass to the *_since helpers to edit what follows.
func mark() -> int:
	return _v.size()


func index_mark() -> int:
	return _i.size()


func triangle_count() -> int:
	return floori(_i.size() / 3.0)


func vert(p: Vector3, n: Vector3, c: Color, uv: Vector2 = Vector2.ZERO) -> int:
	_v.append(p)
	_n.append(n.normalized())
	_c.append(c)
	_uv.append(uv)
	return _v.size() - 1


func tri(a: int, b: int, c: int, outward: Vector3) -> void:
	_tri(a, b, c, outward)


func quad(a: int, b: int, c: int, d: int, outward: Vector3) -> void:
	_quad(a, b, c, d, outward)


## Flat quad from four positions (in order around the quad) facing `normal`.
func flat_quad(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3, color: Color, uv: Vector2 = Vector2.ZERO) -> void:
	var i0 := vert(p0, normal, color, uv)
	vert(p1, normal, color, uv)
	vert(p2, normal, color, uv)
	vert(p3, normal, color, uv)
	_quad(i0, i0 + 1, i0 + 2, i0 + 3, normal)


## Flat triangle facing `normal` (computed from winding when zero).
func flat_tri(p0: Vector3, p1: Vector3, p2: Vector3, color: Color, normal: Vector3 = Vector3.ZERO, uv: Vector2 = Vector2.ZERO) -> void:
	var n := normal
	if n == Vector3.ZERO:
		n = (p2 - p0).cross(p1 - p0)
	var i0 := vert(p0, n, color, uv)
	vert(p1, n, color, uv)
	vert(p2, n, color, uv)
	_tri(i0, i0 + 1, i0 + 2, n)


## Appends another builder's geometry, keeping its colors and UVs.
func append(other: MeshBuilder, xform: Transform3D = Transform3D.IDENTITY) -> PropBuilder:
	var base := _v.size()
	var nb := xform.basis.inverse().transposed()
	for k in other._v.size():
		_v.append(xform * other._v[k])
		_n.append((nb * other._n[k]).normalized())
		_c.append(other._c[k])
		_uv.append(other._uv[k])
	var first := _i.size()
	for k: int in other._i:
		_i.append(base + k)
	if xform.basis.determinant() < 0.0:
		_flip_range(first, _i.size())
	return self


# --- Range edits -------------------------------------------------------------------

## Transforms vertices added since `from` (no mirroring).
func transform_since(from: int, xform: Transform3D) -> PropBuilder:
	var nb := xform.basis.inverse().transposed()
	for k in range(from, _v.size()):
		_v[k] = xform * _v[k]
		_n[k] = (nb * _n[k]).normalized()
	return self


func uv_since(from: int, uv: Vector2) -> PropBuilder:
	for k in range(from, _uv.size()):
		_uv[k] = uv
	return self


## Sets UVs from `fn.call(position) -> Vector2` for vertices since `from`.
func uv_fn_since(from: int, fn: Callable) -> PropBuilder:
	for k in range(from, _uv.size()):
		_uv[k] = fn.call(_v[k])
	return self


## `fn.call(position, normal, color) -> Color` for vertices since `from`.
func recolor(fn: Callable, from: int = 0) -> PropBuilder:
	for k in range(from, _c.size()):
		_c[k] = fn.call(_v[k], _n[k], _c[k])
	return self


## Moves vertices since `from` through `fn.call(position) -> Vector3`.
## Normals are kept; re-run smooth_normals() or flat_shade() after big warps.
func warp(fn: Callable, from: int = 0) -> PropBuilder:
	for k in range(from, _v.size()):
		_v[k] = fn.call(_v[k])
	return self


## Blends normals toward "away from center" (soft foliage volumes).
func spherize_normals(center: Vector3, amount: float, from: int = 0) -> PropBuilder:
	for k in range(from, _n.size()):
		var out := _v[k] - center
		if out.length_squared() > 0.000001:
			_n[k] = _n[k].lerp(out.normalized(), amount).normalized()
	return self


## Colors whole triangles: `fn.call(centroid, face_normal, color) -> Color`.
## Use after flat_shade() so every face keeps one crisp color (no gradients
## that MSAA could extrapolate on thin facets).
func recolor_faces(fn: Callable, from_index: int = 0) -> PropBuilder:
	var k := from_index
	while k + 2 < _i.size():
		var a := _i[k]
		var b := _i[k + 1]
		var c := _i[k + 2]
		var centroid := (_v[a] + _v[b] + _v[c]) / 3.0
		var fnrm := (_v[c] - _v[a]).cross(_v[b] - _v[a])
		fnrm = fnrm.normalized() if fnrm.length_squared() > 0.0 else _n[a]
		var col: Color = fn.call(centroid, fnrm, _c[a])
		_c[a] = col
		_c[b] = col
		_c[c] = col
		k += 3
	return self


## Varies the color of each triangle (use after flat_shade()).
func tint_faces(rng: RandomNumberGenerator, amount: float, from_index: int = 0) -> PropBuilder:
	var k := from_index
	while k + 2 < _i.size():
		var f := rng.randf_range(-amount, amount)
		for t in 3:
			var vi := _i[k + t]
			var c := _c[vi]
			_c[vi] = c.lightened(f) if f > 0.0 else c.darkened(-f)
		k += 3
	return self


## Area-weighted vertex normals, welding equal positions so seams stay soft.
func smooth_normals(from: int = 0) -> PropBuilder:
	var acc := {}
	var k := 0
	while k + 2 < _i.size():
		var a := _i[k]
		var b := _i[k + 1]
		var c := _i[k + 2]
		k += 3
		if a < from and b < from and c < from:
			continue
		var fn := (_v[c] - _v[a]).cross(_v[b] - _v[a])
		for vi: int in [a, b, c]:
			var key := _weld_key(_v[vi])
			acc[key] = acc.get(key, Vector3.ZERO) + fn
	for vi in range(from, _v.size()):
		var n: Vector3 = acc.get(_weld_key(_v[vi]), Vector3.ZERO)
		if n.length_squared() > 0.0:
			_n[vi] = n.normalized()
	return self


static func _weld_key(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x * 2000.0), roundi(p.y * 2000.0), roundi(p.z * 2000.0))


## Unique vertex positions (for convex collision shapes).
func unique_points(from: int = 0) -> PackedVector3Array:
	var seen := {}
	var out := PackedVector3Array()
	for k in range(from, _v.size()):
		var key := _weld_key(_v[k])
		if not seen.has(key):
			seen[key] = true
			out.append(_v[k])
	return out


func aabb() -> AABB:
	if _v.is_empty():
		return AABB()
	var bounds := AABB(_v[0], Vector3.ZERO)
	for p in _v:
		bounds = bounds.expand(p)
	return bounds


# --- Primitives ------------------------------------------------------------------------

## Box with a single flat chamfer on every edge and corner (44 triangles):
## crisp toon highlights on the edges for very little geometry.
func chamfer_box(size: Vector3, bevel: float, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE) -> PropBuilder:
	var h := size * 0.5
	var b := clampf(bevel, 0.0, minf(h.x, minf(h.y, h.z)) * 0.9)
	if b <= 0.0005:
		box(size, xform, color)
		return self
	var nb := xform.basis.inverse().transposed()
	# Faces.
	for a in 3:
		var u := (a + 1) % 3
		var w := (a + 2) % 3
		for sa: float in [-1.0, 1.0]:
			var pts: Array[Vector3] = []
			for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
				var s := Vector3.ZERO
				s[a] = sa
				s[u] = c.x
				s[w] = c.y
				pts.append(_cb_point(h, b, s, a))
			var n := Vector3.ZERO
			n[a] = sa
			_xquad(pts, n, color, xform, nb)
	# Edges.
	for e in 3:
		var a := (e + 1) % 3
		var c2 := (e + 2) % 3
		for sa: float in [-1.0, 1.0]:
			for sc: float in [-1.0, 1.0]:
				var s0 := Vector3.ZERO
				s0[e] = -1.0
				s0[a] = sa
				s0[c2] = sc
				var s1 := s0
				s1[e] = 1.0
				var n := Vector3.ZERO
				n[a] = sa
				n[c2] = sc
				_xquad([_cb_point(h, b, s0, a), _cb_point(h, b, s1, a), _cb_point(h, b, s1, c2), _cb_point(h, b, s0, c2)], n.normalized(), color, xform, nb)
	# Corners.
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var s := Vector3(sx, sy, sz)
				var n := s.normalized()
				var i0 := _v.size()
				for a in 3:
					_v.append(xform * _cb_point(h, b, s, a))
					_n.append((nb * n).normalized())
					_c.append(color)
					_uv.append(Vector2.ZERO)
				_tri(i0, i0 + 1, i0 + 2, xform.basis * n)
	return self


static func _cb_point(h: Vector3, b: float, s: Vector3, a: int) -> Vector3:
	var p := s * (h - Vector3.ONE * b)
	p[a] = s[a] * h[a]
	return p


func _xquad(pts: Array, n: Vector3, color: Color, xform: Transform3D, nb: Basis) -> void:
	var i0 := _v.size()
	var wn := (nb * n).normalized()
	for p: Vector3 in pts:
		_v.append(xform * p)
		_n.append(wn)
		_c.append(color)
		_uv.append(Vector2.ZERO)
	_quad(i0, i0 + 1, i0 + 2, i0 + 3, xform.basis * n)


## Cylinder (or cone) between two points.
func rod(a: Vector3, b: Vector3, radius_a: float, radius_b: float, color: Color, segments: int = 8, caps: bool = true) -> PropBuilder:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		return self
	var basis := PropKit.basis_y(d / length)
	cylinder(radius_b, radius_a, length, Transform3D(basis, (a + b) * 0.5), color, segments, caps)
	return self


## Chamfered beam between two points; `up` orients its cross-section.
func beam(a: Vector3, b: Vector3, width: float, height: float, bevel: float, color: Color, up: Vector3 = Vector3.UP) -> PropBuilder:
	var d := b - a
	var length := d.length()
	if length < 0.0001:
		return self
	var z := d / length
	var x := up.cross(z)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT.cross(z)
	x = x.normalized()
	var y := z.cross(x).normalized()
	chamfer_box(Vector3(width, height, length), bevel, Transform3D(Basis(x, y, z), (a + b) * 0.5), color)
	return self


## Surface of revolution around Y. `profile` holds Vector2(radius, height)
## from bottom to top. With `hard` every profile segment gets its own
## normals and color (crisp bands: hoops, rims, cannon rings); otherwise the
## profile is smooth and `colors` (optional) are per profile point.
func lathe(profile: PackedVector2Array, segments: int, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, colors: PackedColorArray = PackedColorArray(), hard: bool = false) -> PropBuilder:
	var count := profile.size()
	if count < 2:
		return self
	var nb := xform.basis.inverse().transposed()
	if hard:
		for k in count - 1:
			var p0 := profile[k]
			var p1 := profile[k + 1]
			var t := p1 - p0
			if t.length_squared() < 0.0000001:
				continue
			var n2 := Vector2(t.y, -t.x).normalized()
			var col := colors[mini(k, colors.size() - 1)] if not colors.is_empty() else color
			_lathe_ring_pair(p0, p1, n2, n2, col, col, segments, xform, nb, float(k) / (count - 1), float(k + 1) / (count - 1))
		return self
	var normals: Array[Vector2] = []
	for k in count:
		var t := profile[mini(k + 1, count - 1)] - profile[maxi(k - 1, 0)]
		normals.append(Vector2(t.y, -t.x).normalized() if t.length_squared() > 0.0 else Vector2.UP)
	var base := _v.size()
	var ring := segments + 1
	for k in count:
		var col := colors[mini(k, colors.size() - 1)] if not colors.is_empty() else color
		for s in ring:
			var ang := TAU * float(s) / segments
			var cs := Vector3(cos(ang), 0.0, sin(ang))
			var p := Vector3(cs.x * profile[k].x, profile[k].y, cs.z * profile[k].x)
			var n := Vector3(cs.x * normals[k].x, normals[k].y, cs.z * normals[k].x)
			_v.append(xform * p)
			_n.append((nb * n).normalized())
			_c.append(col)
			_uv.append(Vector2(float(s) / segments, float(k) / (count - 1)))
	for k in count - 1:
		for s in segments:
			var i0 := base + k * ring + s
			var ang := TAU * (float(s) + 0.5) / segments
			var cs := Vector3(cos(ang), 0.0, sin(ang))
			var n2 := (normals[k] + normals[k + 1]).normalized()
			var out := Vector3(cs.x * n2.x, n2.y, cs.z * n2.x)
			_quad(i0, i0 + 1, i0 + ring + 1, i0 + ring, xform.basis * out)
	return self


func _lathe_ring_pair(p0: Vector2, p1: Vector2, n0: Vector2, n1: Vector2, c0: Color, c1: Color, segments: int, xform: Transform3D, nb: Basis, v0: float, v1: float) -> void:
	var base := _v.size()
	for s in segments + 1:
		var ang := TAU * float(s) / segments
		var cs := Vector3(cos(ang), 0.0, sin(ang))
		_v.append(xform * Vector3(cs.x * p0.x, p0.y, cs.z * p0.x))
		_n.append((nb * Vector3(cs.x * n0.x, n0.y, cs.z * n0.x)).normalized())
		_c.append(c0)
		_uv.append(Vector2(float(s) / segments, v0))
		_v.append(xform * Vector3(cs.x * p1.x, p1.y, cs.z * p1.x))
		_n.append((nb * Vector3(cs.x * n1.x, n1.y, cs.z * n1.x)).normalized())
		_c.append(c1)
		_uv.append(Vector2(float(s) / segments, v1))
	var nm := (n0 + n1).normalized()
	for s in segments:
		var i0 := base + s * 2
		var ang := TAU * (float(s) + 0.5) / segments
		var cs := Vector3(cos(ang), 0.0, sin(ang))
		var out := Vector3(cs.x * nm.x, nm.y, cs.z * nm.x)
		_quad(i0, i0 + 2, i0 + 3, i0 + 1, xform.basis * out)


## Tube along `points` with one color per segment (crisp rings) and
## per-segment normals that follow the radius slope, so flared rings catch
## the light. Parallel-transport frames keep segments aligned.
func banded_tube(points: PackedVector3Array, radii: PackedFloat32Array, colors: PackedColorArray, segments: int = 8, xform: Transform3D = Transform3D.IDENTITY, cap_end: bool = false) -> PropBuilder:
	var count := points.size()
	if count < 2:
		return self
	var tangents: Array[Vector3] = []
	for k in count:
		var t: Vector3
		if k == 0:
			t = points[1] - points[0]
		elif k == count - 1:
			t = points[k] - points[k - 1]
		else:
			t = points[k + 1] - points[k - 1]
		tangents.append(t.normalized())
	var ref := Vector3.FORWARD if absf(tangents[0].dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var normal := tangents[0].cross(ref).normalized()
	var frames: Array[Vector3] = []  # normal, binormal per point
	for k in count:
		if k > 0:
			var axis := tangents[k - 1].cross(tangents[k])
			if axis.length() > 0.0001:
				normal = normal.rotated(axis.normalized(), tangents[k - 1].angle_to(tangents[k]))
		frames.append(normal)
		frames.append(tangents[k].cross(normal).normalized())
	var nb := xform.basis.inverse().transposed()
	for k in count - 1:
		var col := colors[mini(k, colors.size() - 1)]
		var seg_len := points[k].distance_to(points[k + 1])
		var slope := (radii[mini(k + 1, radii.size() - 1)] - radii[mini(k, radii.size() - 1)]) / maxf(seg_len, 0.0001)
		var base := _v.size()
		for e in 2:
			var pk := k + e
			var r := radii[mini(pk, radii.size() - 1)]
			var tan_k := (points[k + 1] - points[k]).normalized()
			for s in segments + 1:
				var ang := TAU * float(s) / segments
				var dir := frames[pk * 2] * cos(ang) + frames[pk * 2 + 1] * sin(ang)
				_v.append(xform * (points[pk] + dir * r))
				_n.append((nb * (dir - tan_k * slope).normalized()).normalized())
				_c.append(col)
				_uv.append(Vector2(float(s) / segments, float(pk) / (count - 1)))
		var ring := segments + 1
		for s in segments:
			var i0 := base + s
			var mid := (points[k] + points[k + 1]) * 0.5
			_quad(i0, i0 + 1, i0 + ring + 1, i0 + ring, _v[i0] - xform * mid)
	if cap_end:
		var last := count - 1
		_cap(points[last], tangents[last], radii[mini(last, radii.size() - 1)], frames[last * 2], frames[last * 2 + 1], colors[colors.size() - 1], segments, xform)
	return self


## Thick board between two edge polylines (`bottom`, `top`, same count):
## hull strakes and other bent planks. `out_dir` picks which side is the
## outer face. Each face (outer, inner, edges, end caps) gets its own
## vertices so edges stay crisp; `inner_color` tints the inside face. For
## boards bent through large angles pass `away_from` (a point on the inside):
## each point's outer face then points away from it instead of `out_dir`.
func board_strip(bottom: PackedVector3Array, top: PackedVector3Array, thickness: float, color: Color, out_dir: Vector3, inner_color: Color = Color(0, 0, 0, 0), away_from: Vector3 = Vector3.INF) -> PropBuilder:
	var n := bottom.size()
	if n < 2 or top.size() != n:
		return self
	var inner_col := inner_color if inner_color.a > 0.0 else color
	var normals: Array[Vector3] = []
	var widths: Array[Vector3] = []
	for i in n:
		var tangent := (bottom[mini(i + 1, n - 1)] - bottom[maxi(i - 1, 0)]) + (top[mini(i + 1, n - 1)] - top[maxi(i - 1, 0)])
		var w := top[i] - bottom[i]
		var nn := tangent.cross(w).normalized()
		var ref := out_dir if away_from == Vector3.INF else (bottom[i] + top[i]) * 0.5 - away_from
		if nn.dot(ref) < 0.0:
			nn = -nn
		normals.append(nn)
		widths.append(w.normalized())
	var h := thickness * 0.5
	var ob := PackedVector3Array()
	var ot := PackedVector3Array()
	var it := PackedVector3Array()
	var ib := PackedVector3Array()
	for i in n:
		ob.append(bottom[i] + normals[i] * h)
		ot.append(top[i] + normals[i] * h)
		it.append(top[i] - normals[i] * h)
		ib.append(bottom[i] - normals[i] * h)
	# Long faces: [edge A, edge B, normal sign/type, color].
	var faces := [[ob, ot, 0, color], [ot, it, 1, color], [it, ib, 2, inner_col], [ib, ob, 3, color]]
	for f: Array in faces:
		var ea: PackedVector3Array = f[0]
		var eb: PackedVector3Array = f[1]
		var kind: int = f[2]
		var col: Color = f[3]
		var base := _v.size()
		for i in n:
			var nrm: Vector3
			match kind:
				0:
					nrm = normals[i]
				1:
					nrm = widths[i]
				2:
					nrm = -normals[i]
				_:
					nrm = -widths[i]
			vert(ea[i], nrm, col)
			vert(eb[i], nrm, col)
		for i in n - 1:
			var k := base + i * 2
			var mid_n := _n[k] + _n[k + 2]
			_quad(k, k + 2, k + 3, k + 1, mid_n)
	# End caps.
	for e: int in [0, n - 1]:
		var tangent := (bottom[mini(e + 1, n - 1)] - bottom[maxi(e - 1, 0)]).normalized()
		var cap_n := -tangent if e == 0 else tangent
		flat_quad(ob[e], ot[e], it[e], ib[e], cap_n, color.darkened(0.12))
	return self


## Extrudes a 2D polygon (XY plane) along Z, centered, with an optional flat
## bevel. `side_color` colors the rim (defaults to `color`).
func extrude(poly: PackedVector2Array, depth: float, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, bevel: float = 0.0, side_color: Color = Color(0, 0, 0, 0), back_color: Color = Color(0, 0, 0, 0)) -> PropBuilder:
	var outer := poly
	if _signed_area(outer) < 0.0:
		outer = outer.duplicate()
		outer.reverse()
	var rim := side_color if side_color.a > 0.0 else color
	var back := back_color if back_color.a > 0.0 else color
	var hd := depth * 0.5
	var b := clampf(bevel, 0.0, hd * 0.9)
	var inner := _inset(outer, b) if b > 0.0 else outer
	var nb := xform.basis.inverse().transposed()
	var tris := Geometry2D.triangulate_polygon(inner)
	for side: float in [1.0, -1.0]:
		var n := Vector3(0, 0, side)
		var base := _v.size()
		for p in inner:
			_v.append(xform * Vector3(p.x, p.y, side * hd))
			_n.append((nb * n).normalized())
			_c.append(color if side > 0.0 else back)
			_uv.append(Vector2.ZERO)
		for k in range(0, tris.size(), 3):
			_tri(base + tris[k], base + tris[k + 1], base + tris[k + 2], xform.basis * n)
	var count := outer.size()
	for k in count:
		var k1 := (k + 1) % count
		var e := outer[k1] - outer[k]
		var en := Vector3(e.y, -e.x, 0.0).normalized()
		if b > 0.0:
			for side: float in [1.0, -1.0]:
				var bn := (en + Vector3(0, 0, side)).normalized()
				_xquad([
					Vector3(inner[k].x, inner[k].y, side * hd), Vector3(inner[k1].x, inner[k1].y, side * hd),
					Vector3(outer[k1].x, outer[k1].y, side * (hd - b)), Vector3(outer[k].x, outer[k].y, side * (hd - b)),
				], bn, rim, xform, nb)
		_xquad([
			Vector3(outer[k].x, outer[k].y, hd - b), Vector3(outer[k1].x, outer[k1].y, hd - b),
			Vector3(outer[k1].x, outer[k1].y, -hd + b), Vector3(outer[k].x, outer[k].y, -hd + b),
		], en, rim, xform, nb)
	return self


static func _signed_area(poly: PackedVector2Array) -> float:
	var a := 0.0
	for k in poly.size():
		var p := poly[k]
		var q := poly[(k + 1) % poly.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


## Miter inset of a counter-clockwise polygon.
static func _inset(poly: PackedVector2Array, d: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var count := poly.size()
	for k in count:
		var prev := poly[(k - 1 + count) % count]
		var cur := poly[k]
		var nxt := poly[(k + 1) % count]
		var e0 := (cur - prev).normalized()
		var e1 := (nxt - cur).normalized()
		var n0 := Vector2(-e0.y, e0.x)
		var n1 := Vector2(-e1.y, e1.x)
		var bis := (n0 + n1)
		if bis.length_squared() < 0.000001:
			bis = n0
		bis = bis.normalized()
		var cos_half := maxf(bis.dot(n0), 0.35)
		out.append(cur + bis * d / cos_half)
	return out


## Smooth sheet through a grid of points. `color_fn.call(i, j) -> Color`,
## optional `keep_fn.call(i, j) -> bool` drops cells (holes, ragged edges),
## optional `uv_fn.call(i, j) -> Vector2`. `front` picks the face side.
func sheet(rows: Array, front: Vector3, color_fn: Callable, keep_fn: Callable = Callable(), uv_fn: Callable = Callable()) -> PropBuilder:
	var nr := rows.size()
	var nc := (rows[0] as PackedVector3Array).size()
	var base := _v.size()
	for j in nr:
		for i in nc:
			var p: Vector3 = rows[j][i]
			var du: Vector3 = rows[j][mini(i + 1, nc - 1)] - rows[j][maxi(i - 1, 0)]
			var dv: Vector3 = rows[mini(j + 1, nr - 1)][i] - rows[maxi(j - 1, 0)][i]
			var n := du.cross(dv).normalized()
			if n.dot(front) < 0.0:
				n = -n
			var uv := Vector2(float(i) / maxi(nc - 1, 1), float(j) / maxi(nr - 1, 1))
			if uv_fn.is_valid():
				uv = uv_fn.call(i, j)
			vert(p, n, color_fn.call(i, j), uv)
	for j in nr - 1:
		for i in nc - 1:
			if keep_fn.is_valid() and not keep_fn.call(i, j):
				continue
			var a := base + j * nc + i
			_quad(a, a + 1, a + nc + 1, a + nc, _n[a] + _n[a + nc + 1])
	return self
