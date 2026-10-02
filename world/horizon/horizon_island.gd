@tool
class_name HorizonIsland
extends Node3D
## A far-off island on the horizon (spec §194: "across the bright ocean are
## several strange islands"; §117: sailing should spark curiosity). Each is
## a big, simple silhouette of a place still to come, shaped to be told
## apart through the haze half a kilometer away, in the direction the sea
## chart sketches it. Decoration only: no collision and no shadows, and the
## boat's world limit keeps it out of reach.
## Subclasses build in _build() with the helpers below. The origin sits at
## sea level and the island's face looks down -Z (toward Castaway Cay).

const SAND := Color("f0d9a4")
const TRUNK := Color("8a5a36")
const JUNGLE: Array[Color] = [Color("3f8f34"), Color("4fa53b"), Color("5fb84a"), Color("37802f")]

@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

var _root: Node3D
var _pending := false
var _puffs: Array[MeshInstance3D] = []


func _ready() -> void:
	_rebuild()
	set_process(not Engine.is_editor_hint())


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	if _root != null:
		_root.free()
	_puffs.clear()
	_root = Node3D.new()
	_root.name = "Silhouette"
	add_child(_root, false, Node.INTERNAL_MODE_FRONT)
	_build()


## Override: build the island with add_part() and the shape helpers.
func _build() -> void:
	pass


## The node every part hangs from (animate it to move the whole island).
func get_root() -> Node3D:
	return _root


## Adds a finished builder as a shadowless mesh.
func add_part(mb: MeshBuilder, finish: StringName = &"matte", parent: Node3D = null, color := Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(color, finish))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else _root).add_child(mi)
	return mi


# --- Shapes -------------------------------------------------------------------------

## The noise behind lump(): build one per lump seed so lump_point() matches.
static func lump_noise(lump_seed: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = lump_seed
	n.frequency = 0.9
	return n


## A point on a lump's surface in direction `dir` (lump space, meters):
## an ellipsoid with gentle noise, clamped by flat chisel cuts.
static func lump_point(dir: Vector3, radii: Vector3, noise: FastNoiseLite, roughness: float, cuts: Array[Plane] = []) -> Vector3:
	var d := dir.normalized() if dir.length_squared() > 0.0 else Vector3.UP
	var q := d * (1.0 + noise.get_noise_3dv(d * 1.6) * roughness) * radii
	for pl in cuts:
		var dist := pl.normal.dot(q) - pl.d
		if dist > 0.0:
			q -= pl.normal * dist
	return q


## The outward normal of a lump's ellipsoid at a surface point (approximate).
static func lump_normal(q: Vector3, radii: Vector3) -> Vector3:
	return Vector3(q.x / (radii.x * radii.x), q.y / (radii.y * radii.y), q.z / (radii.z * radii.z)).normalized()


## A faceted lump of rock, flat-shaded, moved to `xform` (still white:
## paint() it).
static func lump(radii: Vector3, lump_seed: int, xform: Transform3D, roughness := 0.1, cuts: Array[Plane] = [], rings := 8, segments := 14) -> PropBuilder:
	var noise := lump_noise(lump_seed)
	var mb := PropBuilder.new()
	mb.sphere(1.0, Transform3D.IDENTITY, Color.WHITE, rings, segments)
	mb.warp(func(v: Vector3) -> Vector3: return lump_point(v, radii, noise, roughness, cuts))
	mb.transform_since(0, xform)
	mb.flat_shade()
	return mb


## A sheer-sided stack of rock: a jagged outline (x/z, around its own
## center) extruded from below the sea up to `height`, narrowing by `taper`
## toward the flat top. It is built in rings `band` meters apart, each
## jostled a little, so its walls are craggy and paint well in strata.
static func mesa(outline: PackedVector2Array, height: float, band: float, taper: float, rng_seed: int, at: Vector3 = Vector3.ZERO, base_y := -6.0) -> PropBuilder:
	var rng := PropKit.make_rng(rng_seed, 9)
	var mb := PropBuilder.new()
	var center := Vector2.ZERO
	for p in outline:
		center += p
	center /= outline.size()
	var rings := maxi(1, ceili((height - base_y) / band))
	var prev := PackedVector3Array()
	for r in rings + 1:
		var t := float(r) / rings
		var y := lerpf(base_y, height, t)
		var ring := PackedVector3Array()
		for p in outline:
			var q := center + (p - center) * (1.0 - taper * t)
			if r > 0 and r < rings:
				q += (p - center).normalized() * rng.randf_range(-0.3, 0.3) * band
			ring.append(at + Vector3(q.x, y, q.y))
		if r > 0:
			for k in ring.size():
				var k2 := (k + 1) % ring.size()
				var a := prev[k]
				var b := prev[k2]
				var c := ring[k2]
				var d := ring[k]
				var mid := (a + b + c + d) * 0.25
				var out := Vector3(mid.x - at.x - center.x, 0, mid.z - at.z - center.y)
				var n := (b - a).cross(d - a).normalized()
				if n.dot(out) < 0.0:
					n = -n
				mb.flat_quad(a, b, c, d, n, Color.WHITE)
		prev = ring
	var cap := at + Vector3(center.x, height, center.y)
	for k in prev.size():
		mb.flat_tri(prev[k], prev[(k + 1) % prev.size()], cap, Color.WHITE, Vector3.UP)
	return mb


## A jagged, roughly round outline for mesa(): `radius` with `jag` wobble.
static func outline_around(radius: Vector2, points: int, jag: float, rng_seed: int) -> PackedVector2Array:
	var rng := PropKit.make_rng(rng_seed, 13)
	var out := PackedVector2Array()
	for k in points:
		var a := TAU * k / points + rng.randf_range(-0.12, 0.12)
		out.append(Vector2(cos(a) * radius.x, sin(a) * radius.y) * rng.randf_range(1.0 - jag, 1.0 + jag * 0.5))
	return out


## Colors faces like the props kit's rocks: `cols` = [base, top, dark], with
## sunlit tops lighter, undersides darker and a little per-face tint.
## `fn.call(pos, nrm, color) -> Color` may restyle a face (bands, plates).
static func paint(mb: PropBuilder, cols: Array, tint_seed: int, tint := 0.06, fn: Callable = Callable()) -> PropBuilder:
	var base: Color = cols[0]
	var top: Color = cols[1]
	var dark: Color = cols[2]
	mb.recolor_faces(func(pos: Vector3, nrm: Vector3, _c: Color) -> Color:
		var c := base
		if nrm.y > 0.45:
			c = base.lerp(top, smoothstep(0.45, 0.85, nrm.y))
		elif nrm.y < -0.1:
			c = base.lerp(dark, smoothstep(-0.1, -0.55, nrm.y))
		if fn.is_valid():
			c = fn.call(pos, nrm, c)
		return c
	)
	mb.tint_faces(PropKit.make_rng(tint_seed, 5), tint)
	return mb


## Keeps each face's own color, lightening tops and darkening undersides
## (for parts built in color: jungle, wood, flags).
static func shade(mb: PropBuilder, tint_seed: int, tint := 0.05) -> PropBuilder:
	mb.recolor_faces(func(_pos: Vector3, nrm: Vector3, c: Color) -> Color:
		if nrm.y > 0.45:
			return c.lightened(0.16 * smoothstep(0.45, 0.85, nrm.y))
		if nrm.y < -0.1:
			return c.darkened(0.3 * smoothstep(-0.1, -0.55, nrm.y))
		return c
	)
	mb.tint_faces(PropKit.make_rng(tint_seed, 5), tint)
	return mb


## A tuft of jungle: a few overlapping low-poly canopy blobs.
static func canopy(mb: PropBuilder, at: Vector3, radius: float, rng: RandomNumberGenerator) -> void:
	var col: Color = JUNGLE[rng.randi() % JUNGLE.size()]
	for k in 3:
		var off := Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.15, 0.3), rng.randf_range(-0.6, 0.6)) * radius
		var r := radius * rng.randf_range(0.55, 0.85)
		mb.ellipsoid(Vector3(r, r * 0.72, r), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at + off), col.lightened(rng.randf_range(-0.06, 0.1)), 3, 6)


## A palm reduced to its silhouette: a curved trunk and a star of fronds.
static func palm(mb: PropBuilder, at: Vector3, height: float, rng: RandomNumberGenerator) -> void:
	var a := rng.randf() * TAU
	var lean := Vector3(cos(a), 0, sin(a)) * height * rng.randf_range(0.1, 0.3)
	var top := at + lean + Vector3.UP * height
	mb.tube(PackedVector3Array([at, at.lerp(top, 0.5) + lean * 0.2, top]), PackedFloat32Array([height * 0.045, height * 0.035, height * 0.028]), TRUNK, 5, false)
	var frond: Color = JUNGLE[rng.randi() % JUNGLE.size()]
	for f in 6:
		var fa := TAU * f / 6.0 + rng.randf() * 0.4
		var d := Vector3(cos(fa), 0, sin(fa))
		var side := d.cross(Vector3.UP) * height * 0.07
		var mid := top + d * height * 0.24 + Vector3.UP * height * 0.04
		var tip := top + d * height * 0.46 + Vector3.DOWN * height * 0.16
		mb.triangle(top, mid + side, tip, frond, true)
		mb.triangle(top, tip, mid - side, frond.darkened(0.12), true)


## A low sandy rim at the waterline.
static func beach(mb: PropBuilder, center: Vector3, radii: Vector2, height := 2.0, yaw := 0.0) -> void:
	mb.ellipsoid(Vector3(radii.x, height, radii.y), Transform3D(Basis(Vector3.UP, yaw), center), SAND, 3, 18)


## A waterfall: a ribbon of streaming water along `points` (top first),
## `width` wide, facing `facing`, with mist at its foot.
func waterfall(points: PackedVector3Array, width: float, facing: Vector3) -> void:
	var mb := PropBuilder.new()
	var side := facing.cross(Vector3.UP).normalized() * width * 0.5
	var prev_l := -1
	var prev_r := -1
	for k in points.size():
		var t := float(k) / (points.size() - 1)
		var w := side * (1.0 + t * 0.5)
		var l := mb.vert(points[k] - w, facing, Color.WHITE, Vector2(0.0, t))
		var r := mb.vert(points[k] + w, facing, Color.WHITE, Vector2(1.0, t))
		if prev_l >= 0:
			mb.quad(prev_l, prev_r, r, l, facing)
		prev_l = l
		prev_r = r
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, _waterfall_material())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	var mist := PropBuilder.new()
	var foot := points[points.size() - 1]
	for k in 4:
		var off := Vector3((k - 1.5) * width * 0.35, width * 0.1 * (k % 2), 0)
		mist.ellipsoid(Vector3(width * 0.45, width * 0.3, width * 0.35), Transform3D(Basis.IDENTITY, foot + off), Color("f4fbff"), 3, 8)
	var mm := MeshInstance3D.new()
	mm.mesh = mist.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mm.transparency = 0.25
	_root.add_child(mm)


static func _waterfall_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://world/horizon/far_waterfall.gdshader")
	return m


# --- Smoke puffs -------------------------------------------------------------------

## A soft round puff that swells and fades (cannon fire, a steam vent...).
func puff(at: Vector3, size: float, time := 1.6, color := Color("f6f2ea")) -> void:
	var mi: MeshInstance3D = null
	for p in _puffs:
		if not p.visible:
			mi = p
			break
	if mi == null:
		mi = MeshInstance3D.new()
		var mb := PropBuilder.new()
		mb.sphere(1.0, Transform3D.IDENTITY, Color.WHITE, 4, 7)
		mi.mesh = mb.build(null, MaterialLibrary.toon(color, &"soft"))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_root.add_child(mi)
		_puffs.append(mi)
	mi.visible = true
	mi.position = at
	mi.scale = Vector3.ONE * size * 0.25
	mi.transparency = 0.0
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * size, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "position", at + Vector3.UP * size * 0.6, time)
	tw.tween_property(mi, "transparency", 1.0, time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void: mi.visible = false)
