@tool
class_name StylizedRock
extends PropBody
## Chunky faceted rock: a low-poly ellipsoid, nudged with noise and then
## chiselled by a few random planes so it gets big flat facets, flat-shaded
## with per-facet color variation, lighter sunlit tops, darker undersides and
## an optional moss/grass cap on the upward faces. Origin at ground level;
## the rock sinks a little below it so it sits well on uneven ground.
## Collision: a ConvexPolygonShape3D from the mesh points.

enum Preset { SAND_ROCK, CLIFF_ROCK, DARK_ROCK, MOSSY }

@export var preset := Preset.CLIFF_ROCK:
	set(v):
		preset = v
		_queue_rebuild()
@export var size := Vector3(1.6, 1.1, 1.4):
	set(v):
		size = v.max(Vector3.ONE * 0.1)
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
## Moss / grass cap on upward faces (MOSSY always has at least 0.6).
@export_range(0.0, 1.0, 0.01) var moss := 0.0:
	set(v):
		moss = v
		_queue_rebuild()
## Number of chisel cuts (more = blockier).
@export_range(0, 10) var facets := 6:
	set(v):
		facets = v
		_queue_rebuild()
## Fraction of the height buried below the origin.
@export_range(0.0, 0.5, 0.01) var sink := 0.12:
	set(v):
		sink = v
		_queue_rebuild()
@export var collision := true:
	set(v):
		collision = v
		_queue_rebuild()

var last_triangle_count := 0


func _surface() -> StringName:
	return &"stone"


func _build() -> void:
	# Rocks with identical parameters share one mesh and point set.
	var key := "rock_%d_%s_%d_%.2f_%d_%.2f" % [preset, size, seed, moss, facets, sink]
	var data: Dictionary = PropKit.cached(key, func() -> Dictionary:
		var mb := build_rock(preset, size, seed, moss, facets, sink)
		var tris := mb.triangle_count()
		var pts := mb.unique_points()
		return {"mesh": mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte")), "points": pts, "tris": tris}
	)
	last_triangle_count = data.tris
	add_mesh(data.mesh, "Rock")
	if collision:
		var shape := ConvexPolygonShape3D.new()
		shape.points = data.points
		add_shape(shape)


static func preset_colors(p: Preset) -> Array:
	match p:
		Preset.SAND_ROCK:
			return PropPalette.ROCK_SAND
		Preset.DARK_ROCK:
			return PropPalette.ROCK_DARK
		Preset.MOSSY:
			return PropPalette.ROCK_MOSSY
	return PropPalette.ROCK_CLIFF


## Builds a colored, flat-shaded rock (also used for pebbles by PropScatter).
static func build_rock(p: Preset, rock_size: Vector3, rock_seed: int, moss_amount: float = 0.0, cuts: int = 6, sink_fraction: float = 0.12) -> PropBuilder:
	var rng := PropKit.make_rng(rock_seed, 31 + int(p))
	var half := rock_size * 0.5
	var mb := PropBuilder.new()
	mb.sphere(1.0, Transform3D.IDENTITY, Color.WHITE, 5, 8)
	var noise := FastNoiseLite.new()
	noise.seed = rock_seed
	noise.frequency = 0.9
	var amp := 0.17
	# Ellipsoid + low-frequency lumps (position based, so seams stay closed).
	var spin := Basis(Vector3.UP, rng.randf() * TAU)
	mb.warp(func(v: Vector3) -> Vector3:
		var d := v.normalized() if v.length_squared() > 0.0 else Vector3.UP
		var bump := 1.0 + noise.get_noise_3dv(spin * d * 1.7) * amp * 2.0
		return spin * (d * bump) * half
	)
	# Chisel: clamp everything beyond a few random planes onto them.
	var planes: Array[Plane] = []
	for k in cuts:
		var n: Vector3
		if k == 0:
			n = Vector3(rng.randf_range(-0.25, 0.25), 1.0, rng.randf_range(-0.25, 0.25)).normalized()
		else:
			var a := rng.randf() * TAU
			n = Vector3(cos(a), rng.randf_range(-0.35, 0.75), sin(a)).normalized()
		var extent := (n * half).length()
		planes.append(Plane(n, extent * rng.randf_range(0.46, 0.72)))
	var flat_bottom := -half.y * 0.55
	mb.warp(func(v: Vector3) -> Vector3:
		var q := v
		for pl in planes:
			var dist := pl.normal.dot(q) - pl.d
			if dist > 0.0:
				q -= pl.normal * dist
		q.y = maxf(q.y, flat_bottom)
		return q
	)
	# Sit on the origin with a little buried below it.
	var box := mb.aabb()
	var lift := -box.position.y - box.size.y * sink_fraction
	mb.warp(func(v: Vector3) -> Vector3: return v + Vector3.UP * lift)
	mb.flat_shade()
	# Facet colors: lighter tops, darker undersides, moss caps.
	var cols := preset_colors(p)
	var base: Color = cols[0]
	var top: Color = cols[1]
	var dark: Color = cols[2]
	var moss_amt := maxf(moss_amount, 0.6) if p == Preset.MOSSY else moss_amount
	var height := box.size.y
	mb.recolor_faces(func(pos: Vector3, nrm: Vector3, _c: Color) -> Color:
		var c := base
		if nrm.y > 0.45:
			c = base.lerp(top, smoothstep(0.45, 0.85, nrm.y))
		elif nrm.y < -0.1:
			c = base.lerp(dark, smoothstep(-0.1, -0.55, nrm.y))
		# Slightly darker toward the ground (painted ambient occlusion).
		c = c.darkened(0.1 * (1.0 - smoothstep(0.0, height * 0.4, pos.y)))
		if moss_amt > 0.0:
			var wob := noise.get_noise_2d(pos.x * 3.0, pos.z * 3.0) * 0.25
			var thresh := lerpf(0.95, 0.2, moss_amt) + wob
			if nrm.y > thresh:
				c = PropPalette.MOSS if noise.get_noise_2d(pos.z * 5.0, pos.x * 5.0) > -0.2 else PropPalette.MOSS_DARK
		return c
	)
	mb.tint_faces(rng, 0.07)
	return mb
