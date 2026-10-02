@tool
class_name BeakRock
extends PropBody
## Beak Rock (spec §194): a weathered stack of stone on Driftwood Key that,
## seen from the side, is plainly a parrot's head: a round pate with a mossy
## cap and a crest of shards, two hollow eyes, and a great hooked beak of
## tawny rock peering down at the sand. The map from the Sunken Sloop
## sketches it, and the X lies where the beak points (beak_target()).
## Origin at ground level, the beak toward -Z. Deterministic by `seed`.

@warning_ignore("shadowed_global_identifier")
@export var seed := 3:
	set(v):
		seed = v
		_queue_rebuild()
## How far the head peers down at the sand (degrees).
@export_range(0.0, 35.0, 0.5) var head_pitch := 20.0:
	set(v):
		head_pitch = v
		_queue_rebuild()
@export_range(0.0, 1.0, 0.01) var moss := 0.3:
	set(v):
		moss = v
		_queue_rebuild()

## The head pitches about this point on top of the pedestal.
const NECK := Vector3(0, 2.55, 0.25)
## Head shape, relative to the neck before the pitch ("head space").
const HEAD_CENTER := Vector3(0, 0.55, -0.05)
const HEAD_RADII := Vector3(1.0, 0.95, 1.05)
## Upper mandible: a tube along this hooked line (head space). The parrot
## "points" along it, from the 2nd point through the 4th.
const BEAK_PATH: Array[Vector3] = [Vector3(0, 0.48, -0.55), Vector3(0, 0.55, -1.1), Vector3(0, 0.42, -1.6),
	Vector3(0, 0.04, -1.95), Vector3(0, -0.38, -1.9), Vector3(0, -0.6, -1.7)]
const BEAK_RADII: Array[float] = [0.48, 0.42, 0.32, 0.2, 0.1, 0.03]
const JAW_PATH: Array[Vector3] = [Vector3(0, 0.15, -0.5), Vector3(0, 0.08, -0.95), Vector3(0, 0.02, -1.28)]
const JAW_RADII: Array[float] = [0.34, 0.25, 0.1]
const BEAK_STONE := [Color("d9a050"), Color("f0c47c"), Color("a87236")]
const JAW_STONE := [Color("6a6168"), Color("847b80"), Color("4b444b")]
const EYE := Color("2f2a33")
const EYE_RING := Color("ddd5c2")


func _surface() -> StringName:
	return &"stone"


## The neck pivot with the head's downward peer applied.
func head_transform() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(head_pitch)), NECK)


## Where the beak points: its line carried on down to the ground (local
## space, y = 0). The treasure map's X goes here.
func beak_target() -> Vector3:
	var hx := head_transform()
	var from: Vector3 = hx * BEAK_PATH[3]
	var dir: Vector3 = hx.basis * (BEAK_PATH[3] - BEAK_PATH[1])
	if dir.y > -0.05:
		return Vector3(from.x, 0.0, from.z)
	return from + dir * (-from.y / dir.y)


func _build() -> void:
	var key := "beak_rock_%d_%.2f_%.2f" % [seed, head_pitch, moss]
	var data: Dictionary = PropKit.cached(key, _make)
	add_mesh(data.mesh, "BeakRock")
	for pts: PackedVector3Array in data.hulls:
		var shape := ConvexPolygonShape3D.new()
		shape.points = pts
		add_shape(shape)


func _make() -> Dictionary:
	var rng := PropKit.make_rng(seed, 77)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.9
	var all := PropBuilder.new()
	var hulls: Array[PackedVector3Array] = []
	# Pedestal: a broad boulder half buried in the sand, the neck rock on it.
	var base := StylizedRock.build_rock(StylizedRock.Preset.CLIFF_ROCK, Vector3(3.8, 1.6, 3.4), seed, moss * 0.4, 6, 0.25)
	hulls.append(base.unique_points())
	all.append(base)
	var body := StylizedRock.build_rock(StylizedRock.Preset.CLIFF_ROCK, Vector3(2.5, 2.3, 2.4), seed + 7, 0.0, 5, 0.08)
	var body_xf := Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, 0.95, 0.3))
	hulls.append(_moved(body.unique_points(), body_xf))
	all.append(body, body_xf)
	# Folded wings: two long slabs swept back down the neck rock's flanks.
	var wings := PropBuilder.new()
	for side: float in [-1.0, 1.0]:
		var wb := Basis(Vector3.UP, side * 0.18) * Basis(Vector3.BACK, side * 0.1) * Basis(Vector3.RIGHT, -0.62)
		wings.ellipsoid(Vector3(0.22, 0.85, 0.5), Transform3D(wb, Vector3(side * 0.92, 1.75, 0.5)), Color.WHITE, 4, 7)
	wings.warp(func(v: Vector3) -> Vector3: return v + Vector3(noise.get_noise_3dv(v * 2.0), 0, noise.get_noise_3dv(v * 2.0 + Vector3(5, 0, 0))) * 0.06)
	hulls.append(wings.unique_points())
	var wing_cols := StylizedRock.preset_colors(StylizedRock.Preset.CLIFF_ROCK)
	_finish(wings, [(wing_cols[0] as Color).darkened(0.08), wing_cols[1], wing_cols[2]], 0.0, noise, rng)
	all.append(wings)
	var hx := head_transform()
	var cuts := _head_cuts()
	# The pate: a lumpy ball with a few flat chisel cuts (nape, chin, cheeks).
	var head := PropBuilder.new()
	head.sphere(1.0, Transform3D.IDENTITY, Color.WHITE, 7, 12)
	head.warp(func(v: Vector3) -> Vector3: return _head_point(v, noise, cuts))
	head.transform_since(0, hx)
	hulls.append(head.unique_points())
	_finish(head, StylizedRock.preset_colors(StylizedRock.Preset.CLIFF_ROCK), moss + 0.25, noise, rng)
	all.append(head)
	# A crest of three shards swept back over the pate.
	var crest := PropBuilder.new()
	var shard_dirs := [Vector3(0, 0.95, 0.2), Vector3(0, 0.78, 0.6), Vector3(0, 0.45, 0.9)]
	var shard_sizes := [Vector3(0.13, 0.62, 0.34), Vector3(0.12, 0.52, 0.3), Vector3(0.1, 0.4, 0.24)]
	for k in 3:
		var p := _head_point(shard_dirs[k], noise, cuts)
		crest.ellipsoid(shard_sizes[k], Transform3D(Basis(Vector3.RIGHT, 0.45 + k * 0.4), p), Color.WHITE, 3, 6)
	crest.warp(func(v: Vector3) -> Vector3: return v + Vector3(noise.get_noise_3dv(v * 3.0), noise.get_noise_3dv(v * 3.0 + Vector3(9, 0, 0)), 0) * 0.04)
	crest.transform_since(0, hx)
	_finish(crest, StylizedRock.preset_colors(StylizedRock.Preset.CLIFF_ROCK), 0.0, noise, rng)
	all.append(crest)
	# The great hooked beak (narrower than it is tall), and the jaw tucked under it.
	var beak := PropBuilder.new()
	beak.tube(PackedVector3Array(BEAK_PATH), PackedFloat32Array(BEAK_RADII), Color.WHITE, 7, true, Transform3D(Basis.from_scale(Vector3(0.8, 1, 1)), Vector3.ZERO))
	beak.warp(func(v: Vector3) -> Vector3: return v + Vector3(0, noise.get_noise_3dv(v * 2.5), noise.get_noise_3dv(v * 2.5 + Vector3(0, 7, 0))) * 0.035)
	beak.transform_since(0, hx)
	hulls.append(beak.unique_points())
	_finish(beak, BEAK_STONE, 0.0, noise, rng)
	all.append(beak)
	var jaw := PropBuilder.new()
	jaw.tube(PackedVector3Array(JAW_PATH), PackedFloat32Array(JAW_RADII), Color.WHITE, 6, true, Transform3D(Basis.from_scale(Vector3(0.85, 1, 1)), Vector3.ZERO))
	jaw.transform_since(0, hx)
	_finish(jaw, JAW_STONE, 0.0, noise, rng)
	all.append(jaw)
	# Hollow eyes in pale rings, under heavy stone brows.
	var eyes := PropBuilder.new()
	var brows := PropBuilder.new()
	for side: float in [-1.0, 1.0]:
		var d := Vector3(side * 0.6, 0.42, -0.68).normalized()
		var p := _head_point(d, noise, cuts)
		var q := p - HEAD_CENTER
		var nrm := Vector3(q.x / (HEAD_RADII.x * HEAD_RADII.x), q.y / (HEAD_RADII.y * HEAD_RADII.y), q.z / (HEAD_RADII.z * HEAD_RADII.z)).normalized()
		var face := Basis.looking_at(-nrm, Vector3.UP)
		eyes.ellipsoid(Vector3(0.25, 0.25, 0.06), Transform3D(face, p), EYE_RING, 4, 12)
		eyes.ellipsoid(Vector3(0.13, 0.16, 0.06), Transform3D(face, p + nrm * 0.035), EYE, 4, 10)
		var bp := _head_point(d + Vector3(0, 0.3, 0.06), noise, cuts)
		brows.ellipsoid(Vector3(0.32, 0.09, 0.16), Transform3D(face * Basis(Vector3.BACK, side * 0.3), bp), Color.WHITE, 3, 6)
	eyes.transform_since(0, hx)
	all.append(eyes)
	brows.transform_since(0, hx)
	_finish(brows, StylizedRock.preset_colors(StylizedRock.Preset.CLIFF_ROCK), 0.0, noise, rng)
	all.append(brows)
	return {"mesh": all.build(null, MaterialLibrary.toon(Color.WHITE, &"matte")), "hulls": hulls}


## Flat chisel planes on the pate, in head space around HEAD_CENTER.
static func _head_cuts() -> Array[Plane]:
	return [
		Plane(Vector3(0, 0.75, 0.66).normalized(), 0.8),
		Plane(Vector3(0, 0, 1), 0.86),
		Plane(Vector3(0, -0.92, -0.4).normalized(), 0.78),
		Plane(Vector3(0.95, -0.2, 0.25).normalized(), 0.9),
		Plane(Vector3(-0.95, -0.2, 0.25).normalized(), 0.9),
	]


## A point on the pate's surface in direction `dir` (head space).
static func _head_point(dir: Vector3, noise: FastNoiseLite, cuts: Array[Plane]) -> Vector3:
	var d := dir.normalized() if dir.length_squared() > 0.0 else Vector3.UP
	var q := d * (1.0 + noise.get_noise_3dv(d * 1.6) * 0.14) * HEAD_RADII
	for pl in cuts:
		var dist := pl.normal.dot(q) - pl.d
		if dist > 0.0:
			q -= pl.normal * dist
	return HEAD_CENTER + q


static func _moved(points: PackedVector3Array, xform: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in points:
		out.append(xform * p)
	return out


## Flat-shades a part and paints it like the rest of the rock: lighter tops,
## darker undersides, moss on the flattest tops.
static func _finish(mb: PropBuilder, cols: Array, moss_amt: float, noise: FastNoiseLite, rng: RandomNumberGenerator) -> void:
	mb.flat_shade()
	var base: Color = cols[0]
	var top: Color = cols[1]
	var dark: Color = cols[2]
	mb.recolor_faces(func(pos: Vector3, nrm: Vector3, _c: Color) -> Color:
		var c := base
		if nrm.y > 0.45:
			c = base.lerp(top, smoothstep(0.45, 0.85, nrm.y))
		elif nrm.y < -0.1:
			c = base.lerp(dark, smoothstep(-0.1, -0.55, nrm.y))
		if moss_amt > 0.0:
			var wob := noise.get_noise_2d(pos.x * 3.0, pos.z * 3.0) * 0.25
			if nrm.y > lerpf(0.95, 0.2, minf(moss_amt, 1.0)) + wob:
				c = PropPalette.MOSS if noise.get_noise_2d(pos.z * 5.0, pos.x * 5.0) > -0.2 else PropPalette.MOSS_DARK
		return c
	)
	mb.tint_faces(rng, 0.06)
