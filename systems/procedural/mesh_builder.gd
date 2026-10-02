class_name MeshBuilder
extends RefCounted
## Accumulates vertex-colored geometry into one ArrayMesh surface. Used for
## Patchy, props and level blocks so cohesive stylized placeholders can be
## authored in code (spec §187) and share a few materials.
##
## Godot treats clockwise triangles as front-facing; helpers here take care
## of winding so callers only think in outward normals.

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _uv := PackedVector2Array()
var _i := PackedInt32Array()


func clear() -> MeshBuilder:
	_v.clear()
	_n.clear()
	_c.clear()
	_uv.clear()
	_i.clear()
	return self


func is_empty() -> bool:
	return _v.is_empty()


func vertex_count() -> int:
	return _v.size()


## Appends a surface from Mesh arrays, transformed and tinted.
func add_arrays(arrays: Array, xform: Transform3D, color: Color) -> MeshBuilder:
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
	var idx: Variant = arrays[Mesh.ARRAY_INDEX]
	var nb := xform.basis.inverse().transposed()
	var base := _v.size()
	for k in verts.size():
		_v.append(xform * verts[k])
		_n.append((nb * norms[k]).normalized())
		_c.append(color)
		_uv.append((uvs as PackedVector2Array)[k] if uvs is PackedVector2Array else Vector2.ZERO)
	var first_index := _i.size()
	if idx is PackedInt32Array and not (idx as PackedInt32Array).is_empty():
		for k: int in idx:
			_i.append(base + k)
	else:
		for k in verts.size():
			_i.append(base + k)
	if xform.basis.determinant() < 0.0:
		_flip_range(first_index, _i.size())
	return self


func add_primitive(mesh: PrimitiveMesh, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE) -> MeshBuilder:
	return add_arrays(mesh.get_mesh_arrays(), xform, color)


func box(size: Vector3, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE) -> MeshBuilder:
	var m := BoxMesh.new()
	m.size = size
	return add_primitive(m, xform, color)


func sphere(radius: float, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, rings: int = 10, segments: int = 16) -> MeshBuilder:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.rings = rings
	m.radial_segments = segments
	return add_primitive(m, xform, color)


func ellipsoid(radii: Vector3, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, rings: int = 10, segments: int = 16) -> MeshBuilder:
	return sphere(1.0, xform * Transform3D(Basis.from_scale(radii), Vector3.ZERO), color, rings, segments)


func cylinder(top_radius: float, bottom_radius: float, height: float, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, segments: int = 12, caps: bool = true) -> MeshBuilder:
	var m := CylinderMesh.new()
	m.top_radius = top_radius
	m.bottom_radius = bottom_radius
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	m.cap_top = caps
	m.cap_bottom = caps
	return add_primitive(m, xform, color)


func torus(inner_radius: float, outer_radius: float, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, rings: int = 20, ring_segments: int = 8) -> MeshBuilder:
	var m := TorusMesh.new()
	m.inner_radius = inner_radius
	m.outer_radius = outer_radius
	m.rings = rings
	m.ring_segments = ring_segments
	return add_primitive(m, xform, color)


## Box with rounded edges and corners; bottom-centered when `centered` is false.
func rounded_box(size: Vector3, radius: float, xform: Transform3D = Transform3D.IDENTITY, color: Color = Color.WHITE, seg: int = 3) -> MeshBuilder:
	var h := size * 0.5
	var r := clampf(radius, 0.0, minf(h.x, minf(h.y, h.z)) - 0.0005)
	if r <= 0.001:
		return box(size, xform, color)
	var inner := h - Vector3.ONE * r
	var nb := xform.basis.inverse().transposed()
	# (normal axis, sign, u axis, v axis)
	var faces := [[0, 1, 2, 1], [0, -1, 1, 2], [1, 1, 0, 2], [1, -1, 2, 0], [2, 1, 1, 0], [2, -1, 0, 1]]
	for f: Array in faces:
		var a: int = f[0]
		var sgn: float = f[1]
		var ua: int = f[2]
		var va: int = f[3]
		var us := _rb_samples(h[ua], r, seg)
		var vs := _rb_samples(h[va], r, seg)
		var base := _v.size()
		for j in vs.size():
			for k in us.size():
				var p := Vector3.ZERO
				p[a] = sgn * h[a]
				p[ua] = us[k]
				p[va] = vs[j]
				var q := p.clamp(-inner, inner)
				var nrm := (p - q).normalized()
				var pos := q + nrm * r
				_v.append(xform * pos)
				_n.append((nb * nrm).normalized())
				_c.append(color)
				_uv.append(Vector2(float(k) / (us.size() - 1), float(j) / (vs.size() - 1)))
		var w := us.size()
		var outward := Vector3.ZERO
		outward[a] = sgn
		for j in vs.size() - 1:
			for k in us.size() - 1:
				var i0 := base + j * w + k
				_quad(i0, i0 + 1, i0 + w + 1, i0 + w, xform.basis * outward)
	return self


static func _rb_samples(half: float, r: float, seg: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for k in seg + 1:
		var t := float(k) / seg
		out.append(-half + r * (1.0 - cos(t * PI * 0.5)))
	for k in range(seg, -1, -1):
		var t := float(k) / seg
		var x := half - r * (1.0 - cos(t * PI * 0.5))
		if x > out[out.size() - 1] + 0.0001:
			out.append(x)
	return out


## Sweeps a circle along `points` (parallel-transport frames). `radii` may
## hold one radius or one per point for tapering.
func tube(points: PackedVector3Array, radii: PackedFloat32Array, color: Color = Color.WHITE, segments: int = 8, caps: bool = true, xform: Transform3D = Transform3D.IDENTITY) -> MeshBuilder:
	if points.size() < 2:
		return self
	var count := points.size()
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
	var ref := Vector3.UP if absf(tangents[0].dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
	var normal := tangents[0].cross(ref).normalized()
	var nb := xform.basis.inverse().transposed()
	var base := _v.size()
	for k in count:
		if k > 0:
			var axis := tangents[k - 1].cross(tangents[k])
			if axis.length() > 0.0001:
				var ang := tangents[k - 1].angle_to(tangents[k])
				normal = normal.rotated(axis.normalized(), ang)
		var binormal := tangents[k].cross(normal).normalized()
		var rad := radii[mini(k, radii.size() - 1)]
		for sgi in segments + 1:
			var ang := TAU * float(sgi) / segments
			var dir := normal * cos(ang) + binormal * sin(ang)
			_v.append(xform * (points[k] + dir * rad))
			_n.append((nb * dir).normalized())
			_c.append(color)
			_uv.append(Vector2(float(sgi) / segments, float(k) / (count - 1)))
	var ring := segments + 1
	for k in count - 1:
		for sgi in segments:
			var i0 := base + k * ring + sgi
			var mid := (points[k] + points[k + 1]) * 0.5
			var out_dir := (_v[i0] - xform * mid)
			_quad(i0, i0 + 1, i0 + ring + 1, i0 + ring, out_dir)
	if caps:
		_cap(points[0], -tangents[0], radii[0], normal, tangents[0].cross(normal).normalized(), color, segments, xform)
		var last := count - 1
		_cap(points[last], tangents[last], radii[mini(last, radii.size() - 1)], normal, tangents[last].cross(normal).normalized(), color, segments, xform)
	return self


func _cap(center: Vector3, outward: Vector3, rad: float, nrm: Vector3, binrm: Vector3, color: Color, segments: int, xform: Transform3D) -> void:
	var nb := xform.basis.inverse().transposed()
	var ci := _v.size()
	_v.append(xform * center)
	_n.append((nb * outward).normalized())
	_c.append(color)
	_uv.append(Vector2(0.5, 0.5))
	for sgi in segments + 1:
		var ang := TAU * float(sgi) / segments
		_v.append(xform * (center + (nrm * cos(ang) + binrm * sin(ang)) * rad))
		_n.append((nb * outward).normalized())
		_c.append(color)
		_uv.append(Vector2(0.5 + cos(ang) * 0.5, 0.5 + sin(ang) * 0.5))
	for sgi in segments:
		_tri(ci, ci + 1 + sgi, ci + 2 + sgi, xform.basis * outward)


## Adds a triangle oriented so its front face points along `outward`.
func _tri(a: int, b: int, c: int, outward: Vector3) -> void:
	var cw_normal := (_v[c] - _v[a]).cross(_v[b] - _v[a])
	if cw_normal.dot(outward) >= 0.0:
		_i.append_array([a, b, c])
	else:
		_i.append_array([a, c, b])


func _quad(a: int, b: int, c: int, d: int, outward: Vector3) -> void:
	_tri(a, b, c, outward)
	_tri(a, c, d, outward)


func _flip_range(from: int, to: int) -> void:
	for k in range(from, to - 2, 3):
		var tmp := _i[k + 1]
		_i[k + 1] = _i[k + 2]
		_i[k + 2] = tmp


## Smooth surface through a grid of points (`rows` of equal-length
## PackedVector3Arrays). `front` is called with a point and returns the
## direction its front face should look toward (e.g. UP for a brim top).
func grid(rows: Array, color: Color, front: Callable, closed_u: bool = false, xform: Transform3D = Transform3D.IDENTITY) -> MeshBuilder:
	var nr := rows.size()
	var nc := (rows[0] as PackedVector3Array).size()
	var nb := xform.basis.inverse().transposed()
	var base := _v.size()
	for j in nr:
		for i in nc:
			var p: Vector3 = rows[j][i]
			var iu0 := (i - 1 + nc) % nc if closed_u else maxi(i - 1, 0)
			var iu1 := (i + 1) % nc if closed_u else mini(i + 1, nc - 1)
			var du: Vector3 = rows[j][iu1] - rows[j][iu0]
			var dv: Vector3 = rows[mini(j + 1, nr - 1)][i] - rows[maxi(j - 1, 0)][i]
			var n := du.cross(dv).normalized()
			if n.dot(front.call(p)) < 0.0:
				n = -n
			_v.append(xform * p)
			_n.append((nb * n).normalized())
			_c.append(color)
			_uv.append(Vector2(float(i) / maxi(nc - 1, 1), float(j) / maxi(nr - 1, 1)))
	var cols := nc if closed_u else nc - 1
	for j in nr - 1:
		for i in cols:
			var i1 := (i + 1) % nc
			var a := base + j * nc + i
			var b := base + j * nc + i1
			var c := base + (j + 1) * nc + i1
			var d := base + (j + 1) * nc + i
			_quad(a, b, c, d, _n[a] + _n[c])
	return self


## Raw triangle with explicit positions (flat), e.g. leaves and sails.
func triangle(a: Vector3, b: Vector3, c: Vector3, color: Color, double_sided: bool = false) -> MeshBuilder:
	var n := (c - a).cross(b - a).normalized()
	var base := _v.size()
	for p: Vector3 in [a, b, c]:
		_v.append(p)
		_n.append(n)
		_c.append(color)
		_uv.append(Vector2.ZERO)
	_i.append_array([base, base + 1, base + 2])
	if double_sided:
		var base2 := _v.size()
		for p: Vector3 in [a, c, b]:
			_v.append(p)
			_n.append(-n)
			_c.append(color)
			_uv.append(Vector2.ZERO)
		_i.append_array([base2, base2 + 1, base2 + 2])
	return self


## Moves every vertex along its normal by `fn.call(position) -> float`.
## Identical positions get identical offsets, so seams stay closed.
func displace(fn: Callable) -> MeshBuilder:
	for k in _v.size():
		_v[k] += _n[k] * float(fn.call(_v[k]))
	return self


## Converts to flat shading (faceted rocks, crystals, low-poly foliage).
func flat_shade() -> MeshBuilder:
	var nv := PackedVector3Array()
	var nn := PackedVector3Array()
	var nc := PackedColorArray()
	var nuv := PackedVector2Array()
	var ni := PackedInt32Array()
	var k := 0
	while k + 2 < _i.size():
		var a := _v[_i[k]]
		var b := _v[_i[k + 1]]
		var c := _v[_i[k + 2]]
		var fn := (c - a).cross(b - a).normalized()
		for t in 3:
			var src := _i[k + t]
			nv.append(_v[src])
			nn.append(fn)
			nc.append(_c[src])
			nuv.append(_uv[src])
			ni.append(nv.size() - 1)
		k += 3
	_v = nv
	_n = nn
	_c = nc
	_uv = nuv
	_i = ni
	return self


func build(mesh: ArrayMesh = null, material: Material = null) -> ArrayMesh:
	var m := mesh if mesh != null else ArrayMesh.new()
	if _v.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_INDEX] = _i
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if material != null:
		m.surface_set_material(m.get_surface_count() - 1, material)
	clear()
	return m


## Collision triangles for a ConcavePolygonShape3D.
func get_faces() -> PackedVector3Array:
	var f := PackedVector3Array()
	for k in _i:
		f.append(_v[k])
	return f
