class_name PropMeshes
## Shared visual meshes for collectibles scripted elsewhere (coins, gems).
## Meshes are cached per parameter set and carry their own shared materials,
## so any MeshInstance3D / MultiMesh can use them directly:
##   $Mesh.mesh = PropMeshes.coin()
##   $Mesh.mesh = PropMeshes.gem(Palette.GEM_BLUE)
## Coins stand upright facing +/-Z (spin them around Y); gems point down
## with the table facing up. Both are centered on their origin.


## Chunky gold coin: thick disc with a raised rim, chamfered edge and a raised
## star on both faces (metal finish). ~370 triangles at 16 segments.
static func coin(radius: float = 0.32, thickness: float = 0.09, segments: int = 16) -> ArrayMesh:
	return PropKit.cached_mesh("coin_%.3f_%.3f_%d" % [radius, thickness, segments], func() -> Mesh:
		var mb := coin_builder(radius, thickness, segments)
		return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	)


static func coin_builder(radius: float = 0.32, thickness: float = 0.09, segments: int = 16) -> PropBuilder:
	var mb := PropBuilder.new()
	var r := radius
	var h := thickness * 0.5
	var lip := thickness * 0.18
	# Profile from the bottom face center, around the rim, to the top center.
	var prof := PackedVector2Array([
		Vector2(0.0, -h), Vector2(r * 0.76, -h), Vector2(r * 0.8, -h - lip), Vector2(r * 0.95, -h - lip),
		Vector2(r, -h + lip * 0.3), Vector2(r, h - lip * 0.3), Vector2(r * 0.95, h + lip), Vector2(r * 0.8, h + lip),
		Vector2(r * 0.76, h), Vector2(0.0, h),
	])
	var cols := PackedColorArray([PropPalette.COIN, PropPalette.COIN_RIM, PropPalette.COIN_RIM, PropPalette.COIN_RIM, PropPalette.GOLD_DEEP, PropPalette.COIN_RIM, PropPalette.COIN_RIM, PropPalette.COIN_RIM, PropPalette.COIN])
	var face := Basis(Vector3.RIGHT, PI * 0.5)  # lathe axis Y -> Z: faces look along +/-Z
	mb.lathe(prof, segments, Transform3D(face, Vector3.ZERO), Color.WHITE, cols, true)
	# Raised star emblem on both faces.
	var star := PackedVector2Array()
	for k in 10:
		var a := PI * 0.5 + TAU * float(k) / 10.0
		var rr := r * (0.5 if k % 2 == 0 else 0.22)
		star.append(Vector2(cos(a), sin(a)) * rr)
	for sz: float in [1.0, -1.0]:
		var basis := Basis.IDENTITY if sz > 0.0 else Basis(Vector3.UP, PI)
		mb.extrude(star, lip * 1.6, Transform3D(basis, Vector3(0, 0, sz * (h + lip * 0.5))), PropPalette.COIN_RIM, lip * 0.35, PropPalette.GOLD_DEEP)
	return mb


## Faceted brilliant-cut gem (flat-shaded, glossy): light table, sparkling
## crown facets and a darker pavilion.
static func gem(color: Color = Palette.GEM_RED, size: float = 0.3) -> ArrayMesh:
	return PropKit.cached_mesh("gem_%s_%.3f" % [color.to_html(), size], func() -> Mesh:
		return gem_builder(color, size).build(null, PropKit.gem_material())
	)


static func gem_builder(color: Color, size: float = 0.3) -> PropBuilder:
	var mb := PropBuilder.new()
	var sides := 8
	var r := size * 0.5
	var table_y := size * 0.26
	var table_r := r * 0.55
	var girdle_y := 0.0
	var culet_y := -size * 0.5
	var light := color.lightened(0.08)
	var mid := color.darkened(0.22)
	var dark := color.darkened(0.55)
	var top_c := Vector3(0, table_y, 0)
	for k in sides:
		var a0 := TAU * float(k) / sides
		var a1 := TAU * float(k + 1) / sides
		var t0 := Vector3(cos(a0) * table_r, table_y, sin(a0) * table_r)
		var t1 := Vector3(cos(a1) * table_r, table_y, sin(a1) * table_r)
		var g0 := Vector3(cos(a0) * r, girdle_y, sin(a0) * r)
		var g1 := Vector3(cos(a1) * r, girdle_y, sin(a1) * r)
		var gm := Vector3(cos((a0 + a1) * 0.5) * r * 1.02, girdle_y + size * 0.02, sin((a0 + a1) * 0.5) * r * 1.02)
		# Table.
		mb.flat_tri(top_c, t0, t1, light, Vector3.UP)
		# Crown: a kite per side split in two for extra sparkle.
		mb.flat_tri(t0, g0, gm, mid if k % 2 == 0 else color, Vector3.ZERO)
		mb.flat_tri(t0, gm, t1, color.darkened(0.08), Vector3.ZERO)
		mb.flat_tri(t1, gm, g1, color if k % 2 == 0 else mid, Vector3.ZERO)
		# Pavilion.
		mb.flat_tri(g0, Vector3(0, culet_y, 0), gm, dark if k % 2 == 0 else color.darkened(0.38), Vector3.ZERO)
		mb.flat_tri(gm, Vector3(0, culet_y, 0), g1, color.darkened(0.38) if k % 2 == 0 else dark, Vector3.ZERO)
	# Make every face point outward from the center.
	_orient_outward(mb)
	return mb


static func _orient_outward(mb: PropBuilder) -> void:
	var k := 0
	while k + 2 < mb._i.size():
		var a := mb._i[k]
		var b := mb._i[k + 1]
		var c := mb._i[k + 2]
		var centroid := (mb._v[a] + mb._v[b] + mb._v[c]) / 3.0
		var n := (mb._v[c] - mb._v[a]).cross(mb._v[b] - mb._v[a])
		if n.dot(centroid) < 0.0:
			mb._i[k + 1] = c
			mb._i[k + 2] = b
			n = -n
		var nn := n.normalized()
		mb._n[a] = nn
		mb._n[b] = nn
		mb._n[c] = nn
		k += 3
