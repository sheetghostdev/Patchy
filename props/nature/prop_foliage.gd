class_name PropFoliage
## Procedural foliage generators shared by the nature props and PropScatter:
## pinnate fronds (palms, ferns), grass tufts, flower patches, ferns and
## bushes. Mesh builders are static and deterministic per seed, so the same
## parameters always give the same mesh (and can be cached / MultiMeshed).
##
## Foliage geometry goes in the swaying, double-sided foliage bucket; UV.y
## holds the sway weight (0 at the root, 1 at the tip) and UV.x a phase.


## One pinnate frond: a bare petiole, then serrated leaflets that hang from
## the rachis in an inverted V and point toward the tip like a feather.
class Frond:
	var origin := Vector3.ZERO
	## Horizontal heading (XZ); the frond arches up then droops along it.
	var direction := Vector3.FORWARD
	var length := 3.0
	## Leaflet length (each side) at the widest point.
	var width := 0.7
	## Initial elevation of the frond above horizontal (deg).
	var lift_deg := 30.0
	## Parabolic droop: higher sends the tip lower.
	var droop := 0.8
	var segments := 12
	## Leaflet hang angle below the frond plane at the base / tip (deg).
	var fold_deg := Vector2(22.0, 50.0)
	## Notch depth between leaflets (fraction of leaflet length kept).
	var notch := 0.42
	## Bare petiole fraction before the first leaflet.
	var start := 0.1
	## Random leaflet length variation.
	var jag := 0.14
	var petiole_radius := 0.045
	var base_color := PropPalette.FROND_BASE
	var mid_color := PropPalette.FROND_MID
	var tip_color := PropPalette.FROND_TIP
	var rib_color := PropPalette.FROND_RIB
	## Sway phase (UV.x).
	var phase := 0.0
	## Sway weight scale (UV.y multiplier).
	var sway := 1.0


static func frond(mb: PropBuilder, f: Frond, rng: RandomNumberGenerator) -> void:
	var h := Vector3(f.direction.x, 0.0, f.direction.z)
	h = h.normalized() if h.length_squared() > 0.0001 else Vector3.FORWARD
	var side := h.cross(Vector3.UP).normalized()
	var lift := deg_to_rad(f.lift_deg)
	var n := maxi(f.segments, 2)
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	for k in n + 1:
		var s := float(k) / n
		pts.append(_frond_point(f, h, lift, s))
		tans.append(_frond_tangent(f, h, lift, s))
	# Petiole: short bare stem from the attach point to the first leaflets.
	var m := mb.mark()
	var petiole := PackedVector3Array([_frond_point(f, h, lift, 0.0), _frond_point(f, h, lift, f.start * 0.5), _frond_point(f, h, lift, f.start + 0.02)])
	mb.tube(petiole, PackedFloat32Array([f.petiole_radius, f.petiole_radius * 0.85, f.petiole_radius * 0.55]), f.base_color.darkened(0.1), 4, false)
	mb.uv_since(m, Vector2(f.phase, f.start * 0.4 * f.sway))
	# Leaflets, one side at a time.
	for sigma: float in [-1.0, 1.0]:
		for k in n:
			var s0 := float(k) / n
			var s1 := float(k + 1) / n
			if s1 <= f.start:
				continue
			var t := tans[k]
			var up := side.cross(t).normalized()
			var fold := deg_to_rad(lerpf(f.fold_deg.x, f.fold_deg.y, s0))
			var d := (side * sigma * cos(fold) - up * sin(fold)).normalized()
			var w0 := _frond_width(f, (s0 + s1) * 0.5) * (1.0 + rng.randf_range(-f.jag, f.jag))
			var w1 := _frond_width(f, s1)
			# Skip sliver leaflets (near-zero width): they add nothing visually
			# and needle-thin triangles alias badly.
			if w0 < f.width * 0.12:
				continue
			var tip_s := minf(s0 + (s1 - s0) * 1.7, 1.0)
			var r0 := pts[k]
			var r1 := pts[k + 1]
			var e := _frond_point(f, h, lift, tip_s) + d * w0
			var c := r1 + d * w1 * f.notch
			var leaf_n := t.cross(d).normalized()
			if leaf_n.dot(up) < 0.0:
				leaf_n = -leaf_n
			var rib_n := (leaf_n + up * 1.2).normalized()
			var col0 := _frond_color(f, s0)
			var col1 := _frond_color(f, s1)
			var ir0 := mb.vert(r0, rib_n, col0.lerp(f.rib_color, 0.45), Vector2(f.phase, s0 * f.sway))
			var ie := mb.vert(e, leaf_n, _frond_color(f, tip_s).lightened(0.04), Vector2(f.phase, tip_s * f.sway))
			var ic := mb.vert(c, leaf_n, col1.darkened(0.05), Vector2(f.phase, s1 * f.sway))
			var ir1 := mb.vert(r1, rib_n, col1.lerp(f.rib_color, 0.45), Vector2(f.phase, s1 * f.sway))
			mb.tri(ir0, ie, ic, leaf_n)
			if c.distance_squared_to(r1) > 0.00001:
				mb.tri(ir0, ic, ir1, leaf_n)


static func _frond_point(f: Frond, h: Vector3, lift: float, s: float) -> Vector3:
	var reach := f.length * s * cos(lift)
	var rise := f.length * (s * sin(lift) - f.droop * s * s)
	return f.origin + h * reach + Vector3.UP * rise


static func _frond_tangent(f: Frond, h: Vector3, lift: float, s: float) -> Vector3:
	return (h * cos(lift) + Vector3.UP * (sin(lift) - 2.0 * f.droop * s)).normalized()


static func _frond_width(f: Frond, s: float) -> float:
	var u := clampf((s - f.start) / maxf(1.0 - f.start, 0.001), 0.0, 1.0)
	return f.width * pow(maxf(sin(PI * pow(u, 0.75)), 0.0), 0.8)


static func _frond_color(f: Frond, s: float) -> Color:
	if s < 0.5:
		return f.base_color.lerp(f.mid_color, s / 0.5)
	return f.mid_color.lerp(f.tip_color, (s - 0.5) / 0.5)


# --- Ground foliage ----------------------------------------------------------------------

enum Bloom { MIXED, RED, PINK, YELLOW, WHITE, ORANGE, PURPLE }

## Vertex alpha tag for "up-normal" foliage (grass, flowers, leaf cards): the
## foliage shader keeps their authored upward normals on both faces so a tuft
## shades evenly from every side instead of half its blades going dark.
const UP_NORMALS := 0.0


static func bloom_colors(bloom: Bloom) -> Array[Color]:
	match bloom:
		Bloom.RED:
			return [PropPalette.FLOWER_RED]
		Bloom.PINK:
			return [PropPalette.FLOWER_PINK]
		Bloom.YELLOW:
			return [PropPalette.FLOWER_YELLOW]
		Bloom.WHITE:
			return [PropPalette.FLOWER_WHITE]
		Bloom.ORANGE:
			return [PropPalette.FLOWER_ORANGE]
		Bloom.PURPLE:
			return [PropPalette.FLOWER_PURPLE]
	return [PropPalette.FLOWER_RED, PropPalette.FLOWER_PINK, PropPalette.FLOWER_YELLOW, PropPalette.FLOWER_WHITE, PropPalette.FLOWER_ORANGE, PropPalette.FLOWER_PURPLE]


static func _up(c: Color) -> Color:
	return Color(c.r, c.g, c.b, UP_NORMALS)


static func _shade(c: Color, f: float) -> Color:
	return c.lightened(f) if f > 0.0 else c.darkened(-f)


## A clump of tapered, outward-bending grass blades.
static func grass_tuft(mb: PropBuilder, origin: Vector3, rng: RandomNumberGenerator, height: float = 0.5, blades: int = 7, spread: float = 0.1, base_col: Color = PropPalette.GRASS_BASE, tip_col: Color = PropPalette.GRASS_TIP) -> void:
	for b in blades:
		var ang := TAU * (float(b) + rng.randf_range(-0.3, 0.3)) / blades
		var out := Vector3(cos(ang), 0.0, sin(ang))
		var root := origin + out * spread * rng.randf_range(0.1, 1.0)
		var h := height * rng.randf_range(0.6, 1.0)
		var lean := rng.randf_range(0.2, 0.65)
		var w := height * rng.randf_range(0.15, 0.2)
		var side := out.cross(Vector3.UP).normalized().rotated(Vector3.UP, rng.randf_range(-0.4, 0.4))
		var phase := rng.randf()
		var nrm := (Vector3.UP * 0.8 + out * 0.3).normalized()
		var tint := rng.randf_range(-0.05, 0.05)
		var prev_l := -1
		var prev_r := -1
		for t: float in [0.0, 0.45, 0.8]:
			var p := root + out * (lean * h * t * t) + Vector3.UP * (h * t)
			var ww := w * (1.0 - t * 0.7)
			var col := _up(_shade(base_col.lerp(tip_col, t), tint))
			var il := mb.vert(p - side * ww * 0.5, nrm, col, Vector2(phase, t))
			var ir := mb.vert(p + side * ww * 0.5, nrm, col, Vector2(phase, t))
			if prev_l >= 0:
				mb.quad(prev_l, prev_r, ir, il, nrm)
			prev_l = il
			prev_r = ir
		var tip := root + out * (lean * h) + Vector3.UP * h
		var it := mb.vert(tip, nrm, _up(_shade(tip_col, tint)), Vector2(phase, 1.0))
		mb.tri(prev_l, prev_r, it, nrm)


## Five-ish petal flower head facing `up`, with a domed center.
static func flower_head(mb: PropBuilder, center: Vector3, up: Vector3, radius: float, petals: int, petal_col: Color, center_col: Color, rng: RandomNumberGenerator, phase: float, sway: float) -> void:
	var u := up.normalized()
	var ref := Vector3.RIGHT if absf(u.x) < 0.9 else Vector3.FORWARD
	var side0 := u.cross(ref).normalized()
	var a0 := rng.randf() * TAU
	var cup := deg_to_rad(22.0)
	var uv := Vector2(phase, sway)
	for k in petals:
		var a := a0 + TAU * float(k) / petals + rng.randf_range(-0.12, 0.12)
		var d := side0.rotated(u, a)
		var dir := (d * cos(cup) + u * sin(cup)).normalized()
		var s := d.cross(u).normalized()
		var n := (u + d * 0.25).normalized()
		var mid := center + dir * radius * 0.5
		var ib := mb.vert(center + u * radius * 0.05, n, _up(petal_col.darkened(0.12)), uv)
		var il := mb.vert(mid + s * radius * 0.36, n, _up(petal_col), uv)
		var itp := mb.vert(center + dir * radius, n, _up(petal_col.lightened(0.12)), uv)
		var ir := mb.vert(mid - s * radius * 0.36, n, _up(petal_col), uv)
		mb.tri(ib, il, itp, n)
		mb.tri(ib, itp, ir, n)
	# Domed center: a short pentagonal pyramid.
	var apex := mb.vert(center + u * radius * 0.28, u, _up(center_col.lightened(0.1)), uv)
	var ring: Array[int] = []
	for k in 5:
		var d := side0.rotated(u, a0 + TAU * k / 5.0)
		ring.append(mb.vert(center + d * radius * 0.26 + u * radius * 0.1, (u + d * 0.5).normalized(), _up(center_col), uv))
	for k in 5:
		mb.tri(apex, ring[k], ring[(k + 1) % 5], u)


## A thin bent ribbon from `a` to `b` (stems). UV.y runs w0 -> w1.
static func stem(mb: PropBuilder, a: Vector3, b: Vector3, bend: Vector3, width: float, col: Color, phase: float, w0: float, w1: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	var n := Vector3.UP
	var prev_l := -1
	var prev_r := -1
	for t: float in [0.0, 0.5, 1.0]:
		var p := a.lerp(b, t) + bend * sin(t * PI) * 0.5
		var il := mb.vert(p - side * width * 0.5, n, _up(col), Vector2(phase, lerpf(w0, w1, t)))
		var ir := mb.vert(p + side * width * 0.5, n, _up(col), Vector2(phase, lerpf(w0, w1, t)))
		if prev_l >= 0:
			mb.quad(prev_l, prev_r, ir, il, side.cross(dir))
		prev_l = il
		prev_r = ir


## Diamond leaf from `base` along `dir`.
static func leaf(mb: PropBuilder, base: Vector3, dir: Vector3, length: float, width: float, col: Color, phase: float, sway: float) -> void:
	var d := dir.normalized()
	var s := d.cross(Vector3.UP)
	s = s.normalized() if s.length_squared() > 0.0001 else Vector3.RIGHT
	var n := s.cross(d).normalized()
	if n.y < 0.0:
		n = -n
	var mid := base + d * length * 0.45 - n * length * 0.06
	var ib := mb.vert(base, n, _up(col.darkened(0.1)), Vector2(phase, sway * 0.6))
	var il := mb.vert(mid + s * width * 0.5, n, _up(col), Vector2(phase, sway))
	var it := mb.vert(base + d * length - n * length * 0.12, n, _up(col.lightened(0.1)), Vector2(phase, sway))
	var ir := mb.vert(mid - s * width * 0.5, n, _up(col), Vector2(phase, sway))
	mb.tri(ib, il, it, n)
	mb.tri(ib, it, ir, n)


# --- Mesh factories (cached; used by the nodes and PropScatter) --------------------------

static func grass_mesh(seed_value: int, height: float = 0.5, blades: int = 8) -> ArrayMesh:
	return PropKit.cached_mesh("grass_%d_%.2f_%d" % [seed_value, height, blades], func() -> Mesh:
		var parts := PropParts.new()
		parts.foliage_profile = &"grass"
		var rng := PropKit.make_rng(seed_value, 101)
		grass_tuft(parts.foliage, Vector3.ZERO, rng, height, blades, height * 0.22)
		return parts.build()
	)


static func flower_patch_mesh(seed_value: int, bloom: Bloom = Bloom.MIXED, flowers: int = 5, height: float = 0.42) -> ArrayMesh:
	return PropKit.cached_mesh("flowers_%d_%d_%d_%.2f" % [seed_value, bloom, flowers, height], func() -> Mesh:
		var parts := PropParts.new()
		parts.foliage_profile = &"grass"
		var mb := parts.foliage
		var rng := PropKit.make_rng(seed_value, 202)
		var cols := bloom_colors(bloom)
		var pick := rng.randi() % cols.size()
		grass_tuft(mb, Vector3.ZERO, rng, height * 0.7, 6, height * 0.35)
		for k in flowers:
			var ang := TAU * (float(k) + rng.randf_range(-0.3, 0.3)) / flowers
			var r := height * rng.randf_range(0.1, 0.55)
			var base := Vector3(cos(ang) * r, 0.0, sin(ang) * r)
			var h := height * rng.randf_range(0.65, 1.0)
			var lean := Vector3(cos(ang), 0.0, sin(ang)) * h * rng.randf_range(0.05, 0.25)
			var head := base + lean + Vector3.UP * h
			var phase := rng.randf()
			stem(mb, base, head, lean * 0.3, height * 0.05, PropPalette.STEM, phase, 0.0, 1.0)
			leaf(mb, base.lerp(head, 0.35), Vector3(cos(ang + 1.2), 0.25, sin(ang + 1.2)), h * 0.42, h * 0.16, PropPalette.STEM.lightened(0.08), phase, 0.4)
			var col: Color = cols[(pick + k) % cols.size()] if bloom == Bloom.MIXED else cols[0]
			var up := (Vector3.UP + lean.normalized() * 0.35).normalized()
			flower_head(mb, head, up, height * rng.randf_range(0.2, 0.26), 5, PropKit.jitter(col, rng, 0.04), PropPalette.FLOWER_CENTER, rng, phase, 1.0)
		return parts.build()
	)


static func fern_mesh(seed_value: int, size: float = 0.8, fronds: int = 7) -> ArrayMesh:
	return PropKit.cached_mesh("fern_%d_%.2f_%d" % [seed_value, size, fronds], func() -> Mesh:
		var parts := PropParts.new()
		parts.foliage_profile = &"leaves"
		var rng := PropKit.make_rng(seed_value, 303)
		var a0 := rng.randf() * TAU
		for k in fronds:
			var ang := a0 + TAU * (float(k) + rng.randf_range(-0.25, 0.25)) / fronds
			var f := Frond.new()
			f.origin = Vector3(cos(ang), 0.0, sin(ang)) * size * 0.04
			f.direction = Vector3(cos(ang), 0.0, sin(ang))
			f.length = size * rng.randf_range(0.8, 1.05)
			f.width = f.length * 0.23
			f.lift_deg = rng.randf_range(50.0, 66.0)
			f.droop = rng.randf_range(0.75, 0.95)
			f.segments = 8
			f.notch = 0.35
			f.start = 0.12
			f.fold_deg = Vector2(8.0, 30.0)
			f.petiole_radius = size * 0.014
			f.phase = rng.randf()
			f.base_color = PropKit.jitter(PropPalette.FERN_BASE, rng, 0.05)
			f.mid_color = PropKit.jitter(PropPalette.FERN_BASE.lerp(PropPalette.FERN_TIP, 0.55), rng, 0.04)
			f.tip_color = PropKit.jitter(PropPalette.FERN_TIP, rng, 0.04)
			f.rib_color = PropPalette.FERN_TIP.lightened(0.15)
			frond(parts.foliage, f, rng)
		# A couple of young fronds curling up in the middle.
		for k in 2:
			var ang := a0 + PI * k + 0.7
			var f := Frond.new()
			f.direction = Vector3(cos(ang), 0.0, sin(ang))
			f.length = size * 0.45
			f.width = f.length * 0.16
			f.lift_deg = 75.0
			f.droop = 1.3
			f.segments = 5
			f.start = 0.15
			f.petiole_radius = size * 0.012
			f.phase = rng.randf()
			f.base_color = PropPalette.FERN_BASE
			f.mid_color = PropPalette.FERN_TIP
			f.tip_color = PropPalette.FERN_TIP.lightened(0.1)
			frond(parts.foliage, f, rng)
		return parts.build()
	)


## Soft, lumpy bush: a few noise-bumped blobs with normals bent away from the
## bush center (reads as one soft volume), small leaf cards breaking the
## silhouette and optional flowers. Gently wobbles in the wind.
static func bush_mesh(seed_value: int, size: Vector3 = Vector3(1.2, 0.9, 1.2), flowers: int = 0, bloom: Bloom = Bloom.PINK) -> ArrayMesh:
	return PropKit.cached_mesh("bush_%d_%s_%d_%d" % [seed_value, size, flowers, bloom], func() -> Mesh:
		var parts := PropParts.new()
		parts.foliage_profile = &"leaves"
		build_bush(parts, seed_value, size, flowers, bloom)
		return parts.build()
	)


static func build_bush(parts: PropParts, seed_value: int, size: Vector3, flowers: int, bloom: Bloom) -> void:
	var rng := PropKit.make_rng(seed_value, 404)
	var mb := parts.foliage
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 2.2
	var half := size * 0.5
	var lumps: Array[Array] = []  # [center, radii]
	lumps.append([Vector3(0, half.y * 0.95, 0), Vector3(half.x * 0.72, half.y * 0.95, half.z * 0.72)])
	var count := rng.randi_range(3, 5)
	var a0 := rng.randf() * TAU
	for k in count:
		var a := a0 + TAU * (float(k) + rng.randf_range(-0.2, 0.2)) / count
		var d := Vector3(cos(a) * half.x, 0.0, sin(a) * half.z) * rng.randf_range(0.42, 0.55)
		var rr := rng.randf_range(0.45, 0.58)
		lumps.append([d + Vector3.UP * half.y * rr * 0.95, Vector3(half.x * rr, half.y * rr * 1.05, half.z * rr)])
	# Faceted low-poly lumps (same crafted look as the rocks), colored per
	# facet: dark low down, bright where the top faces the sky.
	var lumps_mb := PropBuilder.new()
	for l: Array in lumps:
		var c: Vector3 = l[0]
		var r: Vector3 = l[1]
		var m := lumps_mb.mark()
		lumps_mb.sphere(1.0, Transform3D.IDENTITY, Color.WHITE, 4, 7)
		lumps_mb.warp(func(v: Vector3) -> Vector3:
			var bump := 1.0 + noise.get_noise_3dv(v * 1.3 + c) * 0.25
			var p := c + v * r * bump
			p.y = maxf(p.y, -0.02)
			return p
		, m)
	lumps_mb.flat_shade()
	lumps_mb.recolor_faces(func(p: Vector3, n: Vector3, _c: Color) -> Color:
		var t := clampf(p.y / size.y, 0.0, 1.0)
		var col := PropPalette.BUSH_DARK.lerp(PropPalette.BUSH, smoothstep(0.05, 0.6, t))
		return col.lerp(PropPalette.BUSH_LIGHT, smoothstep(0.5, 1.0, t) * clampf(n.y + 0.2, 0.0, 1.0))
	)
	lumps_mb.tint_faces(rng, 0.06)
	lumps_mb.uv_fn_since(0, func(p: Vector3) -> Vector2:
		return Vector2(0.0, clampf(p.y / size.y, 0.0, 1.0) * 0.3)
	)
	mb.append(lumps_mb)
	# Leaf cards poking out of the upper half.
	var cards := 18 + int(size.x * 6.0)
	for k in cards:
		var l: Array = lumps[rng.randi() % lumps.size()]
		var c: Vector3 = l[0]
		var r: Vector3 = l[1]
		var a := rng.randf() * TAU
		var el := rng.randf_range(-0.1, 1.0)
		var d := Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		var base := c + d * r * 0.9
		var out := (d + Vector3.UP * 0.3).normalized()
		var col := PropPalette.BUSH.lerp(PropPalette.BUSH_LIGHT, clampf(base.y / size.y, 0.0, 1.0))
		leaf(mb, base, out, size.x * rng.randf_range(0.2, 0.3), size.x * 0.14, col, rng.randf(), 0.4)
	# Flowers dotted over the top.
	var cols := bloom_colors(bloom)
	for k in flowers:
		var l: Array = lumps[rng.randi() % lumps.size()]
		var c: Vector3 = l[0]
		var r: Vector3 = l[1]
		var a := rng.randf() * TAU
		var el := rng.randf_range(0.15, 1.2)
		var d := Vector3(cos(a) * cos(el), sin(el), sin(a) * cos(el))
		flower_head(mb, c + d * r * 1.02, d, size.x * 0.09, 5, cols[k % cols.size()], PropPalette.FLOWER_CENTER, rng, rng.randf(), 0.35)
