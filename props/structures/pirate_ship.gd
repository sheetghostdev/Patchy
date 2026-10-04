@tool
class_name PirateShip
extends PropNode
## The *Jolly Patch*, Patchy's own two-masted brig, as a visual-only model for
## the opening cutscene (no physics bodies). A lofted hull of dark warm
## strakes with Patchy's red stripe, a gold wale and a cream-gold cap rail;
## a raised stern castle (quarterdeck) with lit stern windows and two stern
## lanterns, a small forecastle, three gunports a side with cannon muzzles,
## a planked deck, a bowsprit with a golden parrot figurehead, two masts with
## course and topsail on each, a jib, rigging with ratlines, a crow's nest,
## Patchy's Jolly Roger (the skull wears an eyepatch) and a red pennant.
## Wood and sail colors match the beached wreck (props/structures/wreck).
##
## Ship space: waterline at y 0, bow toward -Z, origin at the hull's middle
## on the waterline. About 20 m from bowsprit tip to stern, 5.5 m beam, the
## main truck 16 m up. Animatable children (rock the PirateShip itself to
## bob the whole ship):
##   Hull        hull, decks, castle, cannons, deck details (pivot: origin)
##   Treasure    chests and spilled coins on the main deck (pivot: on deck)
##   ForeMast    pivot at its foot on deck; yards, sails, jib, rigging, pennant
##   MainMast    pivot at its foot on deck; course, lower rigging
##     MainMastTop  pivot at the break point BREAK_Y (8 m) up the mast; the
##                  upper mast, topsail, crow's nest, upper rigging and flag.
##                  Rotate it (e.g. rotation.x/z ~70 deg) to snap the mast.
## Sails are MeshInstance3Ds with their origin on the yard (head center):
## ForeCourse, ForeTopsail, MainCourse, MainTopsail (belly along -Z) and Jib
## (origin mid-luff, belly along +X); each has a "<name>Furled" roll beside
## it. Scale a sail's Y toward its yard to furl, its belly axis to billow.
## The flags (MainMastTop/JollyRoger, ForeMast/Pennant) have their origin
## at the hoist's top, streaming aft (+Z).
## Generated nodes are rebuilt when `damaged` changes: re-fetch them (the
## `rebuilt` signal fires) or use the `hull`, `main_mast_top`, `sails`...
## references below.

signal rebuilt

## Sails set (true) or furled into rolls on their yards (false). Only toggles
## visibility, so it can flip mid-cutscene without a rebuild.
@export var sails_set := true:
	set(v):
		sails_set = v
		_apply_sail_state()
## Battle damage: holed sails with ragged edges, a tattered flag, missing
## rail pieces and a splintered mainmast break. Rebuilds at once.
@export var damaged := false:
	set(v):
		if v == damaged:
			return
		damaged = v
		if is_inside_tree():
			_rebuild()
## How full the sails are: 0 slack and flat, 1 as modeled, up to 1.5 puffed.
@export_range(0.0, 1.5, 0.01) var billow_amount := 1.0:
	set(v):
		billow_amount = clampf(v, 0.0, 1.5)
		_apply_billow()
## Warm OmniLight3Ds in the stern lanterns (dusk / night shots).
@export var lantern_lights := false:
	set(v):
		lantern_lights = v
		_queue_rebuild()

# --- Hull shape (ship space) ------------------------------------------------------
## Station s runs 0 (stem foot) .. 1 (transom) over HULL_LEN from Z_BOW.
const Z_BOW := -7.4
const HULL_LEN := 15.0
const HALF_BEAM := 2.75
const KEEL_Y := -1.45
const MID_SHEER := 1.55
const BOW_RISE := 1.45
const STERN_RISE := 0.3
const CASTLE_RISE := 1.2
const DECK_MID := 0.75
const CAMBER := 0.06
const FC_HEIGHT := 0.8
const QD_HEIGHT := 1.6
const S_FORECASTLE := 0.17
const S_CASTLE := 0.71
const BOW_RAKE := 0.3
const STERN_RAKE := 0.12
const SECTION_N := 2.4
const BULWARK_T := 0.14
## Hull parameter p per metre above the base sheer (castle walls).
const H_REF := 1.5
const STRAKES := 8
## Cloth shader phase (UV.x) for every sail vertex.
const CLOTH_PHASE := 0.35

# --- Rig -------------------------------------------------------------------------------
const FORE_Z := -4.2
const MAIN_Z := 1.0
## Height of the mainmast break (MainMastTop's pivot).
const BREAK_Y := 8.0
const GUN_Z: Array[float] = [-2.6, -0.9, 0.8]
const BOWSPRIT_ROOT := Vector3(0, 2.25, -6.3)
const BOWSPRIT_TIP := Vector3(0, 4.15, -12.2)
const TREASURE_Z := 2.15
const WHEEL_Z := 4.3
const CAPSTAN_Z := -3.05
const HATCH_Z := -1.35

# --- Colors ----------------------------------------------------------------------------
const STRAKE_COLS: Array[Color] = [Color("8f5a33"), Color("a36a3c"), Color("7a4a2a")]
const RAIL_COL := Color("f4d48a")
const WALE_COL := PropPalette.HULL_TRIM
const RED := Palette.COAT
const MAST_COL := PropPalette.HULL
const MAST_COL_2 := PropPalette.HULL_LIGHT
const YARD_COL := Color("8c5530")
const CLOTH := Color("f7e2b4")
const STRIPE := PropPalette.SAIL_STRIPE
const PATCH_A := Color("e9b44c")
const PATCH_B := Color("6fb0d9")
const STITCH := Color("6b4a33")
const ROPE := Palette.ROPE
const SHROUD := Color("6e4b2e")
const FLAG_BLACK := Color("1d1f26")
const BONE := Color("f4efe2")
const IRON := PropPalette.IRON_DARK
const GOLD := Palette.GOLD

var hull: Node3D
var treasure: Node3D
var fore_mast: Node3D
var main_mast: Node3D
var main_mast_top: Node3D
## Sail MeshInstance3Ds by name (ForeCourse, ForeTopsail, MainCourse,
## MainTopsail, Jib).
var sails: Dictionary = {}
var _furled: Dictionary = {}
var _belly_axis: Dictionary = {}
var _st := PackedFloat32Array()


## Scales every sail's belly: 0 flat, 1 as modeled (same as billow_amount).
func billow(amount: float) -> void:
	billow_amount = amount


func _build() -> void:
	sails.clear()
	_furled.clear()
	_belly_axis.clear()
	_st = PackedFloat32Array()
	for i in 64:
		_st.append(pow(float(i) / 63.0, 1.3))
	hull = PropKit.pivot(self, "Hull")
	_build_hull()
	var tz := Vector3(0, deck_at(TREASURE_Z) + CAMBER, TREASURE_Z)
	treasure = PropKit.pivot(self, "Treasure", Transform3D(Basis.IDENTITY, tz))
	_build_treasure()
	_build_fore_mast()
	_build_main_mast()
	_apply_sail_state()
	_apply_billow()
	rebuilt.emit()


func _mesh(key: String, maker: Callable) -> Mesh:
	return PropKit.cached_mesh("pirate_ship_%s_%d" % [key, int(damaged)], maker)


func _apply_sail_state() -> void:
	for n: String in sails:
		var mi: Node3D = sails[n]
		if is_instance_valid(mi):
			mi.visible = sails_set
	for n: String in _furled:
		var f: Node3D = _furled[n]
		if is_instance_valid(f):
			f.visible = not sails_set


func _apply_billow() -> void:
	for n: String in sails:
		var mi: Node3D = sails[n]
		if not is_instance_valid(mi):
			continue
		var sc := mi.scale
		sc[int(_belly_axis.get(n, 2))] = maxf(billow_amount, 0.04)
		mi.scale = sc


# --- Hull shape functions ---------------------------------------------------------------

static func half_width(s: float) -> float:
	if s < 0.45:
		return HALF_BEAM * pow(sin(clampf(s / 0.45, 0.0, 1.0) * PI * 0.5), 0.55)
	if s < 0.6:
		return HALF_BEAM
	return HALF_BEAM * (1.0 - 0.25 * pow((s - 0.6) / 0.4, 2.0))


static func keel_y(s: float) -> float:
	var k := KEEL_Y
	if s < 0.28:
		k += 1.25 * pow(1.0 - s / 0.28, 2.0)
	if s > 0.82:
		k += 0.4 * pow((s - 0.82) / 0.18, 2.0)
	return k


## The base sheer line (top of the bulwark without the castle).
static func sheer_y(s: float) -> float:
	return MID_SHEER + BOW_RISE * pow(maxf(0.0, 1.0 - s / 0.42), 2.0) + STERN_RISE * pow(maxf(0.0, (s - 0.5) / 0.5), 2.0)


## Top of the hull side (the rail), sweeping up into the stern castle.
static func top_y(s: float) -> float:
	return sheer_y(s) + CASTLE_RISE * smoothstep(S_CASTLE - 0.12, S_CASTLE, s)


## Main deck height at the bulwarks (CAMBER more on the centerline).
static func deck_y(s: float) -> float:
	return DECK_MID + 0.6 * (sheer_y(s) - MID_SHEER)


static func qd_y(s: float) -> float:
	return deck_y(s) + QD_HEIGHT


static func fc_y() -> float:
	return deck_y(S_FORECASTLE) + FC_HEIGHT


## Outer skin point: side -1 (port) / +1 (starboard), station s, height y.
static func hull_point(side: float, s: float, y: float) -> Vector3:
	var k := keel_y(s)
	var sh := sheer_y(s)
	var x: float
	if y <= sh:
		var t := clampf((y - k) / (sh - k), 0.0, 1.0)
		x = pow(1.0 - pow(1.0 - t, SECTION_N), 1.0 / SECTION_N) * (1.0 - 0.03 * smoothstep(0.6, 1.0, t))
	else:
		x = 0.97 - 0.04 * (y - sh)
	x *= half_width(s)
	var z := Z_BOW + s * HULL_LEN - BOW_RAKE * pow(1.0 - s, 3.0) * (y - k) + STERN_RAKE * smoothstep(0.8, 1.0, s) * (y - k)
	return Vector3(side * x, y, z)


## Height -> skin parameter p (0 keel .. 1 base sheer, then metres / H_REF):
## round-bilge sections sampled evenly along their curve.
static func y_to_p(s: float, y: float) -> float:
	var k := keel_y(s)
	var sh := sheer_y(s)
	if y >= sh:
		return 1.0 + (y - sh) / H_REF
	var t := clampf((y - k) / (sh - k), 0.0, 1.0)
	return acos(clampf(pow(1.0 - t, SECTION_N * 0.5), 0.0, 1.0)) / (PI * 0.5)


static func p_to_y(s: float, p: float) -> float:
	var k := keel_y(s)
	var sh := sheer_y(s)
	if p >= 1.0:
		return sh + (p - 1.0) * H_REF
	var t := 1.0 - pow(cos(clampf(p, 0.0, 1.0) * PI * 0.5), 2.0 / SECTION_N)
	return k + (sh - k) * t


static func skin(side: float, s: float, p: float) -> Vector3:
	return hull_point(side, s, p_to_y(s, p))


static func skin_normal(side: float, s: float, p: float) -> Vector3:
	var e := 0.0025
	var ds := skin(side, minf(s + e, 1.0), p) - skin(side, maxf(s - e, 0.0), p)
	var dp := skin(side, s, p + e) - skin(side, s, maxf(p - e, 0.0))
	var n := ds.cross(dp)
	if n.length_squared() < 1e-12:
		return Vector3(side, 0, 0)
	n = n.normalized()
	if n.dot(Vector3(side, minf(p, 1.0) - 1.0, 0.0)) < 0.0:
		n = -n
	return n


## Station whose skin point at height y lies at z.
static func s_at(z: float, y: float) -> float:
	var lo := 0.0
	var hi := 1.0
	for i in 28:
		var m := (lo + hi) * 0.5
		if hull_point(1.0, m, y).z < z:
			lo = m
		else:
			hi = m
	return (lo + hi) * 0.5


## Main deck height (at the bulwarks) at z.
static func deck_at(z: float) -> float:
	return deck_y(s_at(z, 1.0))


## Inner face of the bulwark at station s and height y.
static func inner_point(side: float, s: float, y: float) -> Vector3:
	var p := y_to_p(s, y)
	var q := skin(side, s, p) - skin_normal(side, s, p) * BULWARK_T
	if side * q.x < 0.02:
		q.x = side * 0.02
	return q


static func _frame(out: Vector3, up: Vector3 = Vector3.UP) -> Basis:
	var z := out.normalized()
	var x := up.cross(z).normalized()
	return Basis(x, z.cross(x).normalized(), z)


func _stations(s0: float, s1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([s0])
	for s: float in _st:
		if s > s0 + 0.004 and s < s1 - 0.004:
			out.append(s)
	out.append(s1)
	return out


func _line(mb: PropBuilder, a: Vector3, b: Vector3, r: float = 0.03, col: Color = SHROUD, sag: float = 0.0) -> void:
	if sag <= 0.0:
		mb.tube(PackedVector3Array([a, b]), PackedFloat32Array([r]), col, 4, false)
		return
	var pts := PackedVector3Array()
	for k in 5:
		var f := k / 4.0
		pts.append(a.lerp(b, f) + Vector3.DOWN * sag * sin(f * PI))
	mb.tube(pts, PackedFloat32Array([r]), col, 4, false)


## Moves every bucket of `parts` from ship space into a node placed at `origin`.
static func _local(parts: PropParts, origin: Vector3) -> ArrayMesh:
	if origin != Vector3.ZERO:
		var x := Transform3D(Basis.IDENTITY, -origin)
		for b: PropBuilder in [parts.matte, parts.soft, parts.glossy, parts.metal, parts.foliage, parts.glow, parts.gem]:
			b.transform_since(0, x)
	return parts.build()


# --- Hull ------------------------------------------------------------------------------------

func _build_hull() -> void:
	add_mesh(_mesh("hull", _hull_mesh), "HullMesh", hull)
	# Barrels (the kit's barrel mesh, no physics).
	var barrels := [[Vector3(-2.0, 0, 2.75), 1], [Vector3(-1.95, 0, 1.9), 2], [Vector3(1.55, 0, -3.75), 3]]
	for b: Array in barrels:
		var p: Vector3 = b[0]
		p.y = deck_at(p.z) + CAMBER * (1.0 - pow(p.x / 2.5, 2.0))
		var seed_v: int = b[1]
		var mesh := PropKit.cached_mesh("barrel_%.2f_%.2f_%d_%d" % [1.0, 0.4, Barrel.Hoops.IRON, seed_v], func() -> Mesh:
			return Barrel.build_mesh(1.0, 0.4, Barrel.Hoops.IRON, seed_v)
		)
		add_mesh(mesh, "Barrel%d" % seed_v, hull).transform = Transform3D(Basis(Vector3.UP, seed_v * 1.3), p)
	if lantern_lights:
		for side: float in [-1.0, 1.0]:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.8, 0.5)
			l.light_energy = 1.4
			l.omni_range = 7.0
			l.position = _lantern_pos(side)
			PropKit.add_generated(hull, l, "LanternLight%s" % ("L" if side < 0.0 else "R"))


func _hull_mesh() -> Mesh:
	var parts := PropParts.new()
	parts.glow_color = Color("ffbf4a")
	var rng := PropKit.make_rng(11, 2024)
	_hull_skin(parts, rng)
	_transom(parts)
	_bulwarks_and_decks(parts, rng)
	_rails(parts)
	_keel_stem_rudder(parts)
	_gunports(parts)
	_stern_details(parts)
	_castle_front(parts)
	_bowsprit(parts)
	_figurehead(parts.metal)
	_deck_gear(parts)
	_channels(parts)
	_anchor(parts)
	return parts.build()


## Outer skin: strakes in three warm tones, the red stripe and a dark sheer strake.
func _hull_skin(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var ss := _stations(0.0, 1.0)
	var p_low := func(s: float) -> float: return y_to_p(s, top_y(s) - 0.6)
	var p_red := func(s: float) -> float: return y_to_p(s, top_y(s) - 0.15)
	var p_top := func(s: float) -> float: return y_to_p(s, top_y(s))
	for side: float in [-1.0, 1.0]:
		for k in STRAKES:
			var lo := func(s: float) -> float: return float(p_low.call(s)) * k / STRAKES
			var hi := func(s: float) -> float: return float(p_low.call(s)) * (k + 1) / STRAKES
			var col := PropKit.jitter(STRAKE_COLS[k % STRAKE_COLS.size()], rng, 0.025)
			_band(parts.matte, side, ss, lo, hi, col, 2)
		_band(parts.glossy, side, ss, p_low, p_red, RED, 2)
		_band(parts.matte, side, ss, p_red, p_top, PropPalette.HULL_DARK, 1)
		# Gold wale along the top of the planking.
		var wale := PackedVector3Array()
		for s: float in ss:
			var p: float = p_low.call(s)
			wale.append(skin(side, s, p) + skin_normal(side, s, p) * 0.02)
		parts.glossy.tube(wale, PackedFloat32Array([0.06]), WALE_COL, 6, true)


## One band of hull skin between skin parameters lo(s) and hi(s), pushed
## `offset` along the normal; `inner` faces it inward (bulwark insides).
func _band(mb: PropBuilder, side: float, ss: PackedFloat32Array, lo: Callable, hi: Callable, col: Color, rows: int, offset: float = 0.0, inner: bool = false) -> void:
	var nr := rows + 1
	var base := mb.mark()
	var ns: Array[Vector3] = []
	for s: float in ss:
		var p0: float = lo.call(s)
		var p1: float = hi.call(s)
		for j in nr:
			var p := lerpf(p0, p1, float(j) / rows)
			var n := skin_normal(side, s, p)
			var pt := skin(side, s, p) + n * offset
			if inner:
				n = -n
				if side * pt.x < 0.02:
					pt.x = side * 0.02
			mb.vert(pt, n, col)
			ns.append(n)
	for i in ss.size() - 1:
		for j in rows:
			var a := base + i * nr + j
			mb.quad(a, a + nr, a + nr + 1, a + 1, ns[i * nr + j] + ns[(i + 1) * nr + j + 1])


static func transom_point(x: float, y: float) -> Vector3:
	return Vector3(x, y, Z_BOW + HULL_LEN + STERN_RAKE * (y - keel_y(1.0)))


static func transom_normal() -> Vector3:
	return Vector3(0, -STERN_RAKE, 1).normalized()


## The flat, raked transom, banded like the sides.
func _transom(parts: PropParts) -> void:
	var outline := PackedVector2Array()
	var pt := y_to_p(1.0, top_y(1.0))
	var steps := 28
	for i in steps + 1:
		var q := skin(-1.0, 1.0, pt * (1.0 - float(i) / steps))
		outline.append(Vector2(q.x, q.y))
	for i in range(1, steps + 1):
		var q := skin(1.0, 1.0, pt * float(i) / steps)
		outline.append(Vector2(q.x, q.y))
	var n := transom_normal()
	var pl := y_to_p(1.0, top_y(1.0) - 0.6)
	var bands: Array = []
	for k in STRAKES:
		bands.append([p_to_y(1.0, pl * k / STRAKES), p_to_y(1.0, pl * (k + 1) / STRAKES), STRAKE_COLS[k % STRAKE_COLS.size()], parts.matte])
	bands.append([top_y(1.0) - 0.6, top_y(1.0) - 0.15, RED, parts.glossy])
	bands.append([top_y(1.0) - 0.15, top_y(1.0) + 0.01, PropPalette.HULL_DARK, parts.matte])
	for b: Array in bands:
		var y0: float = b[0]
		var y1: float = b[1]
		var rect := PackedVector2Array([Vector2(-9, y0), Vector2(9, y0), Vector2(9, y1), Vector2(-9, y1)])
		var mb: PropBuilder = b[3]
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(outline, rect):
			var tris := Geometry2D.triangulate_polygon(poly)
			var base := mb.mark()
			for v2: Vector2 in poly:
				mb.vert(transom_point(v2.x, v2.y), n, b[2])
			for t in range(0, tris.size(), 3):
				mb.tri(base + tris[t], base + tris[t + 1], base + tris[t + 2], n)
	# Wale across the transom.
	var yw := top_y(1.0) - 0.6
	var xw := skin(1.0, 1.0, y_to_p(1.0, yw)).x
	parts.glossy.tube(PackedVector3Array([transom_point(-xw, yw) + n * 0.02, transom_point(xw, yw) + n * 0.02]), PackedFloat32Array([0.06]), WALE_COL, 6, true)
	# Dark molding around the transom's edge hides the seam.
	var edge := PackedVector3Array()
	for v2: Vector2 in outline:
		edge.append(transom_point(v2.x, v2.y) + n * 0.01)
	parts.matte.tube(edge, PackedFloat32Array([0.05]), PropPalette.HULL_DARK.darkened(0.1), 5, false)


## Bulwark insides, the three decks and the bulkheads between them.
func _bulwarks_and_decks(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var mt := parts.matte
	var fy := fc_y()
	var p_top := func(s: float) -> float: return y_to_p(s, top_y(s))
	var regions := [
		[0.0, S_FORECASTLE, func(_s: float) -> float: return fy],
		[S_FORECASTLE, S_CASTLE, func(s: float) -> float: return deck_y(s)],
		[S_CASTLE, 1.0, func(s: float) -> float: return qd_y(s)],
	]
	for r: Array in regions:
		var ss := _stations(r[0], r[1])
		var floor_fn: Callable = r[2]
		var p_floor := func(s: float) -> float: return y_to_p(s, float(floor_fn.call(s)) - 0.02)
		for side: float in [-1.0, 1.0]:
			_band(mt, side, ss, p_floor, p_top, PropPalette.HULL_INNER, 1, -BULWARK_T, true)
		_deck(mt, ss, floor_fn, 18, rng)
	# Inside of the transom above the quarterdeck.
	var zt := Z_BOW + HULL_LEN - BULWARK_T
	var yq := qd_y(1.0)
	var yt := top_y(1.0)
	var xq := inner_point(1.0, 1.0, yq).x
	var xt := inner_point(1.0, 1.0, yt).x
	mt.flat_quad(Vector3(-xq, yq - 0.02, zt + STERN_RAKE * (yq - keel_y(1.0))), Vector3(xq, yq - 0.02, zt + STERN_RAKE * (yq - keel_y(1.0))),
			Vector3(xt, yt, zt + STERN_RAKE * (yt - keel_y(1.0))), Vector3(-xt, yt, zt + STERN_RAKE * (yt - keel_y(1.0))), Vector3.FORWARD, PropPalette.HULL_INNER)
	# Forecastle bulkhead (faces aft) with a trim beam.
	_bulkhead(mt, S_FORECASTLE, deck_y(S_FORECASTLE), fy, Vector3.BACK, PropPalette.HULL_INNER.lightened(0.05))
	var xa := inner_point(1.0, S_FORECASTLE, fy).x
	var za := inner_point(1.0, S_FORECASTLE, fy).z
	mt.beam(Vector3(-xa, fy - 0.02, za + 0.05), Vector3(xa, fy - 0.02, za + 0.05), 0.14, 0.12, 0.03, RAIL_COL, Vector3.UP)


func _bulkhead(mb: PropBuilder, s: float, y0: float, y1: float, facing: Vector3, col: Color) -> void:
	var a := inner_point(1.0, s, y0)
	var b := inner_point(1.0, s, y1)
	mb.flat_quad(Vector3(-a.x, y0, a.z), Vector3(a.x, y0, a.z), Vector3(b.x, y1, b.z), Vector3(-b.x, y1, b.z), facing, col)


## Planks along the ship between the bulwarks, over a dark underlay (seams).
func _deck(mb: PropBuilder, ss: PackedFloat32Array, floor_fn: Callable, planks: int, rng: RandomNumberGenerator) -> void:
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	var zs := PackedFloat32Array()
	for s: float in ss:
		var y: float = floor_fn.call(s)
		var q := inner_point(1.0, s, y)
		xs.append(q.x + 0.01)
		ys.append(y)
		zs.append(q.z)
	var under := mb.mark()
	for k in ss.size():
		mb.vert(Vector3(-xs[k], ys[k] - 0.012, zs[k]), Vector3.UP, PropPalette.WOOD_DEEP)
		mb.vert(Vector3(xs[k], ys[k] - 0.012, zs[k]), Vector3.UP, PropPalette.WOOD_DEEP)
	for k in ss.size() - 1:
		var a := under + k * 2
		mb.quad(a, a + 1, a + 3, a + 2, Vector3.UP)
	for i in planks:
		var u0 := -1.0 + 2.0 * i / planks + 0.006
		var u1 := -1.0 + 2.0 * (i + 1) / planks - 0.006
		var col := PropKit.jitter(PropPalette.PLANK if i % 2 == 0 else PropPalette.PLANK_LIGHT, rng, 0.04)
		var base := mb.mark()
		for k in ss.size():
			for u: float in [u0, u1]:
				mb.vert(Vector3(u * xs[k], ys[k] + CAMBER * (1.0 - u * u), zs[k]), Vector3.UP, col)
		for k in ss.size() - 1:
			var a := base + k * 2
			mb.quad(a, a + 1, a + 3, a + 2, Vector3.UP)


## Gaps in the rails when damaged: [side, s0, s1].
func _rail_gaps() -> Array:
	if not damaged:
		return []
	return [[1.0, 0.33, 0.42], [-1.0, 0.25, 0.31], [-1.0, 0.47, 0.53], [1.0, 0.8, 0.86]]


func _in_gap(side: float, s: float) -> bool:
	for g: Array in _rail_gaps():
		if is_equal_approx(float(g[0]), side) and s > float(g[1]) and s < float(g[2]):
			return true
	return false


## Cap rails on the bulwarks and transom, balustrades round the forecastle
## and quarterdeck.
func _rails(parts: PropParts) -> void:
	var mt := parts.matte
	var gl := parts.glossy
	for side: float in [-1.0, 1.0]:
		# Split the cap rail around damage gaps.
		var runs: Array = [[0.0, 1.0]]
		for g: Array in _rail_gaps():
			if not is_equal_approx(float(g[0]), side):
				continue
			var next: Array = []
			for r: Array in runs:
				if float(g[1]) > float(r[0]) and float(g[2]) < float(r[1]):
					next.append([r[0], g[1]])
					next.append([g[2], r[1]])
				else:
					next.append(r)
			runs = next
			for s: float in [float(g[1]), float(g[2])]:
				_splinters(mt, _rail_center(side, s) + Vector3.UP * 0.02, 3, s * 100.0)
		for r: Array in runs:
			var ins := PackedVector3Array()
			var outs := PackedVector3Array()
			for s: float in _stations(r[0], r[1]):
				var p := y_to_p(s, top_y(s))
				var q := skin(side, s, p)
				var n := skin_normal(side, s, p)
				var h := Vector3(n.x, 0, n.z).normalized()
				ins.append(q - h * (BULWARK_T + 0.04) + Vector3.UP * 0.05)
				outs.append(q + h * 0.08 + Vector3.UP * 0.05)
			gl.board_strip(ins, outs, 0.12, RAIL_COL, Vector3.UP)
	# Transom cap rail.
	var yt := top_y(1.0) + 0.05
	var xt := skin(1.0, 1.0, y_to_p(1.0, top_y(1.0))).x + 0.08
	var n := transom_normal()
	var tin := PackedVector3Array([transom_point(-xt, yt) - n * (BULWARK_T + 0.04), transom_point(xt, yt) - n * (BULWARK_T + 0.04)])
	var tout := PackedVector3Array([transom_point(-xt, yt) + n * 0.08, transom_point(xt, yt) + n * 0.08])
	gl.board_strip(tin, tout, 0.12, RAIL_COL, Vector3.UP)
	# Balustrades.
	var fy := fc_y() + 0.8
	var fc_rail := func(_s: float) -> float: return fy
	var qd_rail := func(s: float) -> float: return qd_y(s) + 0.95
	for side: float in [-1.0, 1.0]:
		_balustrade(parts, side, 0.012, S_FORECASTLE + 0.01, fc_rail)
		_balustrade(parts, side, S_CASTLE - 0.005, 1.0, qd_rail)
	# Forecastle breast rail (across its aft edge).
	var fa := inner_point(1.0, S_FORECASTLE + 0.01, fc_y())
	_cross_rail(parts, fa.x + BULWARK_T * 0.5, fc_y() + 0.06, fy, fa.z - 0.02, [])
	# Quarterdeck breast rail, open over the ladder (port side).
	var qa := inner_point(1.0, S_CASTLE, qd_y(S_CASTLE))
	_cross_rail(parts, qa.x + BULWARK_T * 0.5, qd_y(S_CASTLE) + 0.04, qd_y(S_CASTLE) + 0.95, qa.z + 0.05, [Vector2(-1.55, -0.85)])
	# Stern rail across the transom.
	var ys := qd_y(1.0) + 0.95
	var zs := transom_point(0, ys).z - 0.03
	var posts := 9
	for i in posts:
		var x := lerpf(-xt + 0.15, xt - 0.15, float(i) / (posts - 1))
		mt.box(Vector3(0.08, ys - yt - 0.06, 0.08), Transform3D(Basis.IDENTITY, Vector3(x, (yt + ys) * 0.5, transom_point(x, (yt + ys) * 0.5).z - 0.05)), RAIL_COL)
	gl.beam(Vector3(-xt + 0.05, ys, zs), Vector3(xt - 0.05, ys, zs), 0.16, 0.09, 0.025, RAIL_COL)


func _rail_center(side: float, s: float) -> Vector3:
	var p := y_to_p(s, top_y(s))
	var n := skin_normal(side, s, p)
	return skin(side, s, p) - Vector3(n.x, 0, n.z).normalized() * (BULWARK_T * 0.5 - 0.02) + Vector3.UP * 0.11


## Posts on the cap rail up to a rail at rail_fn(s) between stations s0..s1.
func _balustrade(parts: PropParts, side: float, s0: float, s1: float, rail_fn: Callable) -> void:
	var ss := _stations(s0, s1)
	var pts := PackedVector3Array()
	for s: float in ss:
		var c := _rail_center(side, s)
		c.y = rail_fn.call(s)
		pts.append(c)
	# Posts every ~0.45 m along the rail.
	var acc := 0.0
	for k in ss.size():
		if k > 0:
			acc += pts[k].distance_to(pts[k - 1])
		if k > 0 and k < ss.size() - 1 and acc < 0.45:
			continue
		acc = 0.0
		var s := ss[k]
		var bottom := _rail_center(side, s)
		var h := pts[k].y - bottom.y
		if h < 0.12 or _in_gap(side, s):
			continue
		parts.matte.box(Vector3(0.08, h, 0.08), Transform3D(Basis.IDENTITY, bottom + Vector3.UP * h * 0.5), RAIL_COL)
	# The rail itself, split around gaps.
	var run_a := PackedVector3Array()
	var run_b := PackedVector3Array()
	for k in ss.size() + 1:
		var broken := k == ss.size() or _in_gap(side, ss[mini(k, ss.size() - 1)])
		if not broken:
			var t := (pts[mini(k + 1, ss.size() - 1)] - pts[maxi(k - 1, 0)])
			var w := Vector3(-t.z, 0, t.x).normalized() * 0.08
			run_a.append(pts[k] - w)
			run_b.append(pts[k] + w)
		if broken and run_a.size() >= 2:
			parts.glossy.board_strip(run_a, run_b, 0.09, RAIL_COL, Vector3.UP)
		if broken:
			run_a = PackedVector3Array()
			run_b = PackedVector3Array()


## A rail across the ship at z from y0 to y1, with posts; `skip` holds x ranges left open.
func _cross_rail(parts: PropParts, half: float, y0: float, y1: float, z: float, skip: Array) -> void:
	var count := int(half * 2.0 / 0.42)
	for i in count + 1:
		var x := lerpf(-half + 0.1, half - 0.1, float(i) / count)
		var open := false
		for r: Vector2 in skip:
			if x > r.x - 0.05 and x < r.y + 0.05:
				open = true
		if not open:
			parts.matte.box(Vector3(0.08, y1 - y0, 0.08), Transform3D(Basis.IDENTITY, Vector3(x, (y0 + y1) * 0.5, z)), RAIL_COL)
	var xs: Array[float] = [-half]
	for r: Vector2 in skip:
		xs.append(r.x)
		xs.append(r.y)
	xs.append(half)
	for k in range(0, xs.size(), 2):
		parts.glossy.beam(Vector3(xs[k], y1, z), Vector3(xs[k + 1], y1, z), 0.16, 0.09, 0.025, RAIL_COL)


func _splinters(mb: PropBuilder, at: Vector3, count: int, seed_f: float) -> void:
	var rng := PropKit.make_rng(int(seed_f * 13.0), 77)
	for k in count:
		var off := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.12, 0.12))
		var tip := at + off + Vector3(rng.randf_range(-0.1, 0.1), rng.randf_range(0.12, 0.3), rng.randf_range(-0.15, 0.15))
		mb.rod(at + off - Vector3.UP * 0.05, tip, 0.045, 0.0, PropPalette.PLANK_LIGHT, 4, true)


## Keel, stem post and the rudder.
func _keel_stem_rudder(parts: PropParts) -> void:
	var mt := parts.matte
	var dark := PropPalette.HULL_DARK.darkened(0.12)
	var kb := PackedVector3Array()
	var kt := PackedVector3Array()
	for s: float in _stations(0.0, 1.0):
		var q := hull_point(0.0, s, keel_y(s))
		kb.append(q + Vector3.DOWN * 0.3)
		kt.append(q + Vector3.UP * 0.05)
	mt.board_strip(kb, kt, 0.26, dark, Vector3.RIGHT)
	# Stem: from the forefoot up past the rail.
	var sb := PackedVector3Array()
	var sf := PackedVector3Array()
	var k0 := keel_y(0.0)
	var steps := 10
	for i in steps + 1:
		var y := lerpf(k0 - 0.3, top_y(0.0) + 0.35, float(i) / steps)
		var q := hull_point(0.0, 0.0, minf(y, top_y(0.0)))
		if y > top_y(0.0):
			q += Vector3(0, y - top_y(0.0), -(y - top_y(0.0)) * 0.3)
		sb.append(q + Vector3(0, 0, 0.05))
		sf.append(q + Vector3(0, 0, -0.22))
	mt.board_strip(sb, sf, 0.26, dark, Vector3.RIGHT)
	# Rudder behind the raked sternpost, with gold pintles.
	var ry0 := keel_y(1.0) + 0.05
	var ry1 := 1.55
	var n := transom_normal()
	var up := (transom_point(0, ry1) - transom_point(0, ry0)).normalized()
	var mid := (transom_point(0, ry0) + transom_point(0, ry1)) * 0.5 + n * 0.38
	var rb := Basis(Vector3.RIGHT, up, Vector3.RIGHT.cross(up))
	mt.chamfer_box(Vector3(0.2, ry1 - ry0, 0.75), 0.05, Transform3D(rb, mid), dark)
	mt.chamfer_box(Vector3(0.24, ry1 - ry0 + 0.1, 0.22), 0.04, Transform3D(rb, (transom_point(0, ry0) + transom_point(0, ry1)) * 0.5 + n * 0.08), dark.lightened(0.05))
	for f: float in [0.2, 0.5, 0.8]:
		var c := (transom_point(0, lerpf(ry0, ry1, f)) + n * 0.3)
		parts.metal.chamfer_box(Vector3(0.26, 0.08, 0.6), 0.02, Transform3D(rb, c), GOLD.darkened(0.15))


## Three gunports a side in the red stripe: gold frame, dark port, an open
## lid and an iron muzzle on a red carriage behind the bulwark.
func _gunports(parts: PropParts) -> void:
	var prof := PackedVector2Array([
		Vector2(0.0, -0.1), Vector2(0.07, -0.09), Vector2(0.05, -0.03), Vector2(0.15, 0.0), Vector2(0.16, 0.12),
		Vector2(0.13, 0.15), Vector2(0.115, 1.25), Vector2(0.15, 1.29), Vector2(0.15, 1.42), Vector2(0.09, 1.43),
		Vector2(0.08, 1.3), Vector2(0.0, 1.3),
	])
	var cols := PackedColorArray()
	for k in prof.size() - 1:
		cols.append(Color("15161c") if k >= prof.size() - 3 else IRON)
	for side: float in [-1.0, 1.0]:
		for z: float in GUN_Z:
			var s := s_at(z, 1.1)
			var dy := deck_y(s)
			var y := dy + 0.42
			var p := y_to_p(s, y)
			var q := skin(side, s, p)
			var n := skin_normal(side, s, p)
			var nh := Vector3(n.x, 0, n.z).normalized()
			var fb := _frame(n)
			parts.metal.chamfer_box(Vector3(0.62, 0.54, 0.06), 0.02, Transform3D(fb, q + n * 0.02), GOLD.darkened(0.08))
			parts.matte.box(Vector3(0.48, 0.4, 0.04), Transform3D(fb, q + n * 0.04), Color("1c1714"))
			# Lid hinged on the top edge, swung up and out.
			var hinge := q + fb.y * 0.27 + n * 0.06
			var lb := fb * Basis(Vector3.RIGHT, -1.25)
			parts.matte.chamfer_box(Vector3(0.58, 0.5, 0.06), 0.02, Transform3D(lb, hinge + lb * Vector3(0, -0.25, 0.03)), PropPalette.HULL_DARK)
			parts.glossy.chamfer_box(Vector3(0.44, 0.36, 0.02), 0.008, Transform3D(lb, hinge + lb * Vector3(0, -0.25, -0.005)), RED)
			# Barrel: breech inboard, muzzle 0.4 m proud of the hull.
			var breech := Vector3(q.x, y, q.z) - nh * 1.0
			parts.metal.lathe(prof, 12, Transform3D(PropKit.basis_y(nh), breech), IRON, cols, true)
			# Carriage on deck.
			var cb := _frame(nh)
			var cc := breech + nh * 0.15
			cc.y = dy + 0.2
			parts.glossy.chamfer_box(Vector3(0.5, 0.28, 0.78), 0.04, Transform3D(cb, cc), RED.darkened(0.08))
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-0.26, 0.26]:
					var wc := cc + cb.x * sx * 0.27 + cb.z * sz + Vector3.DOWN * 0.08
					parts.matte.cylinder(0.12, 0.12, 0.07, Transform3D(cb * Basis(Vector3.BACK, PI * 0.5), wc), PropPalette.WOOD_DEEP, 8)


## Stern windows (lit), gold trim, and the two stern lanterns.
func _stern_details(parts: PropParts) -> void:
	var n := transom_normal()
	var right := Vector3.RIGHT
	var up := n.cross(right).normalized()
	var tb := Basis(right, up, n)
	var wy := 1.72
	var arch := PackedVector2Array()
	for k in 9:
		var a := PI * float(k) / 8.0
		arch.append(Vector2(cos(a) * 0.29, 0.12 + sin(a) * 0.29))
	arch.append(Vector2(-0.29, -0.36))
	arch.append(Vector2(0.29, -0.36))
	var pane := PackedVector2Array()
	for k in 9:
		var a := PI * float(k) / 8.0
		pane.append(Vector2(cos(a) * 0.21, 0.12 + sin(a) * 0.21))
	pane.append(Vector2(-0.21, -0.28))
	pane.append(Vector2(0.21, -0.28))
	for x: float in [-1.2, -0.4, 0.4, 1.2]:
		var c := transom_point(x, wy)
		parts.metal.extrude(arch, 0.08, Transform3D(tb, c + n * 0.03), GOLD.darkened(0.05), 0.02)
		parts.glow.extrude(pane, 0.04, Transform3D(tb, c + n * 0.07), Color.WHITE)
		parts.matte.box(Vector3(0.035, 0.66, 0.03), Transform3D(tb, c + n * 0.095 + up * 0.03), PropPalette.WOOD_DEEP)
		parts.matte.box(Vector3(0.42, 0.035, 0.03), Transform3D(tb, c + n * 0.095 + up * 0.02), PropPalette.WOOD_DEEP)
	# A gold sill and a carved gold band over the windows.
	parts.metal.chamfer_box(Vector3(3.4, 0.08, 0.1), 0.025, Transform3D(tb, transom_point(0, wy - 0.42) + n * 0.05), GOLD.darkened(0.1))
	# Stern lanterns on iron brackets at the quarterdeck's corners.
	for side: float in [-1.0, 1.0]:
		var lp := _lantern_pos(side)
		var post := Vector3(lp.x - side * 0.05, qd_y(1.0) + 0.95, lp.z - 0.32)
		parts.metal.rod(post, post + Vector3(0, 0.75, 0), 0.04, 0.035, IRON, 6)
		parts.metal.rod(post + Vector3(0, 0.7, 0), lp + Vector3(0, 0.42, 0), 0.03, 0.03, IRON, 6)
		parts.glow.cylinder(0.17, 0.2, 0.46, Transform3D(Basis.IDENTITY, lp), Color.WHITE, 6)
		for k in 6:
			var a := TAU * (k + 0.5) / 6.0
			parts.metal.rod(lp + Vector3(cos(a) * 0.205, -0.23, sin(a) * 0.205), lp + Vector3(cos(a) * 0.175, 0.23, sin(a) * 0.175), 0.018, 0.018, IRON, 4, false)
		parts.metal.cylinder(0.24, 0.24, 0.06, Transform3D(Basis.IDENTITY, lp + Vector3(0, -0.25, 0)), IRON, 8)
		parts.metal.cylinder(0.0, 0.27, 0.24, Transform3D(Basis.IDENTITY, lp + Vector3(0, 0.36, 0)), IRON, 8)
		parts.metal.sphere(0.06, Transform3D(Basis.IDENTITY, lp + Vector3(0, 0.5, 0)), GOLD, 4, 6)
		parts.metal.sphere(0.07, Transform3D(Basis.IDENTITY, lp + Vector3(0, -0.32, 0)), GOLD, 4, 6)


func _lantern_pos(side: float) -> Vector3:
	var y := qd_y(1.0) + 1.35
	var x := skin(1.0, 1.0, y_to_p(1.0, top_y(1.0))).x - 0.05
	return Vector3(side * x, y, transom_point(0, y).z + 0.25)


## The quarterdeck's front bulkhead: door, two lit windows, a ladder.
func _castle_front(parts: PropParts) -> void:
	var y0 := deck_y(S_CASTLE)
	var y1 := qd_y(S_CASTLE)
	var mt := parts.matte
	_bulkhead(mt, S_CASTLE, y0 - 0.02, y1, Vector3.FORWARD, Color("c98e58"))
	var z := inner_point(1.0, S_CASTLE, y0).z - 0.005
	var half := inner_point(1.0, S_CASTLE, y1).x
	# Trim beams (top and vertical pilasters).
	parts.glossy.beam(Vector3(-half, y1 - 0.04, z - 0.04), Vector3(half, y1 - 0.04, z - 0.04), 0.16, 0.12, 0.03, RAIL_COL)
	for x: float in [-half + 0.1, -0.62, 0.62, half - 0.1]:
		mt.box(Vector3(0.12, y1 - y0, 0.06), Transform3D(Basis.IDENTITY, Vector3(x, (y0 + y1) * 0.5, z - 0.03)), PropPalette.HULL_DARK)
	# Door with a gold knob and frame.
	var dh := 1.18
	parts.metal.chamfer_box(Vector3(0.86, dh + 0.08, 0.05), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, y0 + dh * 0.5 + 0.04, z - 0.02)), GOLD.darkened(0.12))
	for k in 3:
		mt.chamfer_box(Vector3(0.23, dh - 0.02, 0.06), 0.015, Transform3D(Basis.IDENTITY, Vector3(-0.24 + k * 0.24, y0 + dh * 0.5 + 0.02, z - 0.05)), PropKit.jitter(PropPalette.WOOD_DEEP, PropKit.make_rng(k, 5), 0.06))
	parts.metal.sphere(0.04, Transform3D(Basis.IDENTITY, Vector3(0.26, y0 + 0.6, z - 0.1)), GOLD, 4, 6)
	# Round lit windows either side.
	for x: float in [-1.55, 1.55]:
		var c := Vector3(x, y0 + 0.85, z - 0.02)
		parts.metal.torus(0.17, 0.25, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c), GOLD.darkened(0.05), 14, 6)
		parts.glow.cylinder(0.18, 0.18, 0.04, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), c), Color.WHITE, 12)
	# Ladder up the port side.
	var lx := -1.2
	var foot := Vector3(lx, y0 + CAMBER * 0.6, z - 0.95)
	var head := Vector3(lx, y1 + 0.02, z - 0.02)
	for sx: float in [-0.3, 0.3]:
		mt.beam(foot + Vector3(sx, 0, 0), head + Vector3(sx, 0, 0), 0.07, 0.14, 0.02, PropPalette.WOOD_FRAME)
	for k in 6:
		var f := (k + 0.6) / 6.5
		var c := foot.lerp(head, f)
		mt.chamfer_box(Vector3(0.56, 0.05, 0.18), 0.015, Transform3D(Basis.IDENTITY, c), PropPalette.PLANK_LIGHT)


## Bowsprit with iron bands, the bobstay and a little jib-boom cap.
func _bowsprit(parts: PropParts) -> void:
	var a := BOWSPRIT_ROOT
	var b := BOWSPRIT_TIP
	var d := (b - a).normalized()
	parts.matte.banded_tube(PackedVector3Array([a, a.lerp(b, 0.35), a.lerp(b, 0.7), b]), PackedFloat32Array([0.2, 0.18, 0.15, 0.11]), PackedColorArray([MAST_COL, MAST_COL_2, MAST_COL]), 10, Transform3D.IDENTITY, true)
	for f: float in [0.3, 0.55, 0.72]:
		var r := lerpf(0.2, 0.11, f)
		parts.metal.torus(r * 0.9, r * 1.18, Transform3D(PropKit.basis_y(d), a.lerp(b, f)), IRON, 14, 4)
	parts.metal.sphere(0.12, Transform3D(Basis.IDENTITY, b + d * 0.05), GOLD, 5, 8)
	# Bobstay down to the cutwater, and a dolphin striker.
	var stem_low := hull_point(0.0, 0.0, 0.5) + Vector3(0, 0, -0.15)
	_line(parts.matte, b - d * 0.3, stem_low, 0.04, SHROUD)
	var strike := a.lerp(b, 0.7)
	parts.matte.rod(strike, strike + Vector3(0, -0.9, 0), 0.05, 0.04, YARD_COL, 6)
	_line(parts.matte, strike + Vector3(0, -0.9, 0), b - d * 0.15, 0.03, SHROUD)
	_line(parts.matte, strike + Vector3(0, -0.9, 0), hull_point(0.0, 0.0, 1.6) + Vector3(0, 0, -0.15), 0.03, SHROUD)


## Golden parrot figurehead on the stem head, under the bowsprit, leaning
## out over the water with its wings swept back along the bow.
func _figurehead(me: PropBuilder) -> void:
	var stem := hull_point(0.0, 0.0, 2.0)
	var base := Transform3D(Basis(Vector3.RIGHT, -0.45).scaled(Vector3.ONE * 1.3), stem + Vector3(0, -0.1, -0.5))
	var gold := Color("ffc23a")
	var deep := Color("e8961f")
	var light := Color("ffe08a")
	var ink := Color("2b2135")
	me.ellipsoid(Vector3(0.33, 0.48, 0.36), base * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.06)), gold, 8, 12)
	me.ellipsoid(Vector3(0.25, 0.32, 0.2), base * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, -0.21)), light, 6, 10)
	var head := base * Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, 0.5, -0.2))
	me.sphere(0.28, head, gold, 8, 12)
	# A big hooked beak, upper and lower.
	me.ellipsoid(Vector3(0.11, 0.14, 0.15), head * Transform3D(Basis.IDENTITY, Vector3(0, -0.03, -0.28)), ink, 6, 8)
	me.cylinder(0.0, 0.085, 0.24, head * Transform3D(Basis(Vector3.RIGHT, -PI * 0.78), Vector3(0, -0.14, -0.38)), ink, 6)
	me.ellipsoid(Vector3(0.08, 0.06, 0.09), head * Transform3D(Basis.IDENTITY, Vector3(0, -0.15, -0.22)), ink.lightened(0.15), 4, 6)
	# Crest of red feathers.
	for k in 3:
		me.chamfer_box(Vector3(0.07, 0.32, 0.11), 0.025, head * Transform3D(Basis(Vector3.RIGHT, 0.45 + k * 0.38), Vector3(0, 0.28 - k * 0.03, 0.03 + k * 0.09)), RED)
	for sx: float in [-1.0, 1.0]:
		me.sphere(0.085, head * Transform3D(Basis.IDENTITY, Vector3(sx * 0.19, 0.08, -0.13)), BONE, 5, 8)
		me.sphere(0.05, head * Transform3D(Basis.IDENTITY, Vector3(sx * 0.235, 0.09, -0.17)), ink, 4, 6)
		# Wings swept back along the bow, a red tip on each.
		var wing := base * Transform3D(Basis(Vector3.RIGHT, 0.75) * Basis(Vector3.FORWARD, sx * 0.25), Vector3(sx * 0.31, 0.06, 0.34))
		me.ellipsoid(Vector3(0.1, 0.44, 0.66), wing, deep, 6, 10)
		me.ellipsoid(Vector3(0.08, 0.2, 0.3), wing * Transform3D(Basis.IDENTITY, Vector3(sx * 0.03, -0.24, 0.42)), RED, 5, 8)
		# Feet gripping the stem.
		me.ellipsoid(Vector3(0.08, 0.06, 0.12), base * Transform3D(Basis.IDENTITY, Vector3(sx * 0.14, -0.44, 0.12)), ink.lightened(0.2), 4, 6)
	# Tail feathers down the stem.
	for k in 3:
		me.chamfer_box(Vector3(0.12, 0.08, 0.62), 0.03, base * Transform3D(Basis(Vector3.RIGHT, -0.9) * Basis(Vector3.UP, (k - 1) * 0.25), Vector3((k - 1) * 0.08, -0.5, 0.3)), [deep, RED, deep][k])


## Ship's wheel on the quarterdeck, capstan and hatch on the main deck.
func _deck_gear(parts: PropParts) -> void:
	var mt := parts.matte
	var me := parts.metal
	# Wheel.
	var fy := qd_y(s_at(WHEEL_Z, 2.3)) + CAMBER
	var c := Vector3(0, fy + 1.05, WHEEL_Z - 0.18)
	var axle := Basis(Vector3.RIGHT, PI * 0.5)
	mt.chamfer_box(Vector3(0.26, 1.02, 0.34), 0.04, Transform3D(Basis.IDENTITY, Vector3(0, fy + 0.5, WHEEL_Z)), PropPalette.WOOD_FRAME)
	me.chamfer_box(Vector3(0.32, 0.06, 0.4), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, fy + 1.02, WHEEL_Z)), GOLD.darkened(0.1))
	mt.cylinder(0.05, 0.05, 0.4, Transform3D(axle, c + Vector3(0, 0, 0.12)), PropPalette.WOOD_DEEP, 8)
	mt.torus(0.48, 0.6, Transform3D(axle, c), Palette.WOOD, 24, 6)
	me.cylinder(0.11, 0.11, 0.16, Transform3D(axle, c), GOLD, 10)
	for k in 8:
		var a := TAU * k / 8.0
		var dir := Vector3(cos(a), sin(a), 0)
		mt.rod(c, c + dir * 0.78, 0.035, 0.03, PropPalette.WOOD_FRAME, 5, false)
		mt.sphere(0.05, Transform3D(Basis.IDENTITY, c + dir * 0.8), Palette.WOOD, 4, 6)
	# Capstan.
	var cy := deck_at(CAPSTAN_Z) + CAMBER
	var cprof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.46, 0.0), Vector2(0.46, 0.1), Vector2(0.34, 0.18), Vector2(0.28, 0.5),
		Vector2(0.33, 0.72), Vector2(0.44, 0.78), Vector2(0.44, 1.0), Vector2(0.32, 1.06), Vector2(0.0, 1.08)])
	var ccols := PackedColorArray([PropPalette.WOOD_DEEP, PropPalette.WOOD_DEEP, PropPalette.WOOD_FRAME, Palette.WOOD, Palette.WOOD, GOLD.darkened(0.15), PropPalette.WOOD_FRAME, PropPalette.WOOD_FRAME, GOLD])
	mt.lathe(cprof, 12, Transform3D(Basis.IDENTITY, Vector3(0, cy, CAPSTAN_Z)), Color.WHITE, ccols, true)
	for k in 8:
		var a := TAU * k / 8.0
		mt.beam(Vector3(cos(a) * 0.36, cy + 0.14, CAPSTAN_Z + sin(a) * 0.36), Vector3(cos(a) * 0.32, cy + 0.74, CAPSTAN_Z + sin(a) * 0.32), 0.08, 0.1, 0.02, PropPalette.WOOD_FRAME, Vector3(cos(a), 0, sin(a)))
	for k in 2:
		var a := PI * 0.25 + PI * 0.5 * k
		var dir := Vector3(cos(a), 0, sin(a))
		mt.rod(Vector3(0, cy + 0.89, CAPSTAN_Z) - dir * 0.85, Vector3(0, cy + 0.89, CAPSTAN_Z) + dir * 0.85, 0.045, 0.045, PropPalette.PLANK_LIGHT, 6)
	# Hatch: a coaming and a grating.
	var hy := deck_at(HATCH_Z) + CAMBER
	mt.chamfer_box(Vector3(1.5, 0.26, 1.3), 0.04, Transform3D(Basis.IDENTITY, Vector3(0, hy + 0.11, HATCH_Z)), PropPalette.HULL_DARK)
	mt.box(Vector3(1.32, 0.02, 1.12), Transform3D(Basis.IDENTITY, Vector3(0, hy + 0.235, HATCH_Z)), Color("2a1d14"))
	for k in 6:
		mt.box(Vector3(0.07, 0.05, 1.12), Transform3D(Basis.IDENTITY, Vector3(-0.55 + k * 0.22, hy + 0.255, HATCH_Z)), PropPalette.PLANK_LIGHT)
	for k in 5:
		mt.box(Vector3(1.32, 0.04, 0.07), Transform3D(Basis.IDENTITY, Vector3(0, hy + 0.25, HATCH_Z - 0.44 + k * 0.22)), PropPalette.PLANK)
	# Mast partners (collars where the masts pass the deck).
	for z: float in [FORE_Z, MAIN_Z]:
		var y := deck_at(z) + CAMBER
		mt.lathe(PackedVector2Array([Vector2(0.48, 0.0), Vector2(0.44, 0.1), Vector2(0.3, 0.14)]), 12, Transform3D(Basis.IDENTITY, Vector3(0, y - 0.02, z)), PropPalette.HULL_DARK)


## Channels: ledges on the hull sides where the shrouds are made fast.
func _channels(parts: PropParts) -> void:
	for z: float in [FORE_Z, MAIN_Z]:
		for side: float in [-1.0, 1.0]:
			var pts: Array[Vector3] = []
			for dz: float in [-0.25, 0.55, 1.35]:
				pts.append(_chain_point(side, z + dz))
			var a := pts[0] + Vector3(0, 0, -0.35)
			var b := pts[2] + Vector3(0, 0, 0.35)
			parts.matte.beam(a - Vector3(side * 0.12, 0.06, 0), b - Vector3(side * 0.12, 0.06, 0), 0.4, 0.09, 0.025, PropPalette.HULL_DARK)


## Where a shroud reaches the channel at z (outboard of the hull).
func _chain_point(side: float, z: float) -> Vector3:
	var s := s_at(z, 1.3)
	var y := top_y(s) - 0.32
	var q := hull_point(side, s, y)
	return Vector3(q.x + side * 0.3, y, q.z)


# --- Treasure ----------------------------------------------------------------------------------

func _build_treasure() -> void:
	var chest := TreasureChestModel.new()
	chest.seed = 4
	chest.open_amount = 0.62
	chest.transform = Transform3D(Basis(Vector3.UP, -0.35), Vector3(0.55, 0, 0.2))
	PropKit.add_generated(treasure, chest, "Chest")
	add_mesh(_mesh("treasure", _treasure_mesh), "Gold", treasure)


func _treasure_mesh() -> Mesh:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(5, 808)
	var me := parts.metal
	var chest := Transform3D(Basis(Vector3.UP, -0.35), Vector3(0.55, 0, 0.2))
	# Heap brimming over the open chest, coins on top and down the front.
	me.ellipsoid(Vector3(0.46, 0.17, 0.28), chest * Transform3D(Basis.IDENTITY, Vector3(0, 0.58, 0.0)), PropPalette.CHEST_GOLD_DARK, 6, 12)
	for k in 14:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf())
		var p := Vector3(cos(a) * r * 0.4, 0.0, sin(a) * r * 0.24)
		p.y = 0.58 + 0.17 * sqrt(maxf(1.0 - r * r, 0.0))
		_coin(me, chest * Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(-0.6, 0.6))), p), k)
	for k in 7:
		var x := rng.randf_range(-0.35, 0.35)
		var y := rng.randf_range(0.2, 0.55)
		_coin(me, chest * Transform3D(Basis(Vector3.RIGHT, PI * 0.5 + rng.randf_range(-0.4, 0.2)) * Basis(Vector3.UP, rng.randf() * TAU), Vector3(x, y, -0.39)), k)
	for k in 3:
		var a := rng.randf() * TAU
		parts.gem.append(PropMeshes.gem_builder([Palette.GEM_RED, Palette.GEM_BLUE, PropPalette.GEM_GREEN][k], 0.11), chest * Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf() * TAU, 0.3)), Vector3(cos(a) * 0.18, 0.72, sin(a) * 0.1)))
	# Spill on the deck in front of the chest.
	var spill := chest * Vector3(0, 0, -0.62)
	me.ellipsoid(Vector3(0.36, 0.07, 0.26), Transform3D(Basis.IDENTITY, spill + Vector3(0, 0.0, 0)), PropPalette.CHEST_GOLD_DARK, 5, 10)
	for k in 30:
		var a := rng.randf() * TAU
		var r := 0.15 + pow(rng.randf(), 0.7) * 0.9
		var p := spill + Vector3(cos(a) * r, 0.0, sin(a) * r * 0.7 - 0.1)
		var on_heap := r < 0.3
		p.y = 0.012 + (0.06 if on_heap else 0.0)
		_coin(me, Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12), rng.randf() * TAU, rng.randf_range(-0.12, 0.12))), p), k)
	# A couple of little stacks.
	for st: Vector3 in [Vector3(-0.15, 0, -0.55), Vector3(1.05, 0, -0.35)]:
		for k in 4 + int(st.x > 0.0) * 2:
			_coin(me, Transform3D(Basis(Vector3.UP, k * 0.7), st + Vector3(rng.randf_range(-0.01, 0.01), 0.012 + k * 0.024, rng.randf_range(-0.01, 0.01))), k)
	parts.gem.append(PropMeshes.gem_builder(PropPalette.GEM_PURPLE, 0.12), Transform3D(Basis.from_euler(Vector3(0.4, 1.0, 0.2)), spill + Vector3(0.3, 0.06, -0.2)))
	_small_chest(parts, Transform3D(Basis(Vector3.UP, 0.5), Vector3(-0.65, 0, 0.5)), rng)
	return parts.build()


## A small domed chest, lid ajar, coins tumbling out of the gap.
func _small_chest(parts: PropParts, xf: Transform3D, rng: RandomNumberGenerator) -> void:
	var w := 0.78
	var h := 0.42
	var d := 0.52
	var mt := parts.matte
	var me := parts.metal
	mt.chamfer_box(Vector3(w, h, d), 0.03, xf * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), PropPalette.CHEST_WOOD)
	mt.box(Vector3(w - 0.08, 0.02, d - 0.08), xf * Transform3D(Basis.IDENTITY, Vector3(0, h + 0.005, 0)), PropPalette.CHEST_GOLD_DARK)
	# Lid: a half-round dome hinged at the back, propped open a crack.
	var dome := PackedVector2Array()
	for k in 9:
		var a := PI * k / 8.0
		dome.append(Vector2(cos(a) * d * 0.5, sin(a) * d * 0.36))
	var hinge := xf * Transform3D(Basis(Vector3.RIGHT, -0.28), Vector3(0, h, d * 0.5))
	mt.extrude(dome, w, hinge * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, 0)) * Transform3D(Basis.IDENTITY, Vector3(d * 0.5, 0, 0)), PropPalette.CHEST_WOOD.lightened(0.05), 0.02, PropPalette.CHEST_WOOD_DARK)
	for bx: float in [-0.26, 0.26]:
		me.chamfer_box(Vector3(0.07, h + 0.01, d + 0.02), 0.01, xf * Transform3D(Basis.IDENTITY, Vector3(bx * w, h * 0.5, 0)), PropPalette.CHEST_BAND)
	me.chamfer_box(Vector3(0.14, 0.16, 0.03), 0.012, xf * Transform3D(Basis.IDENTITY, Vector3(0, h - 0.1, -d * 0.5 - 0.015)), PropPalette.GOLD_DEEP)
	for k in 9:
		var p := Vector3(rng.randf_range(-0.3, 0.3), 0.012, -d * 0.5 - rng.randf_range(0.05, 0.5))
		_coin(me, xf * Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, 0)), p), k)
	for k in 4:
		_coin(me, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5 - 0.3) * Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.25, 0.25), h - 0.04 - k * 0.07, -d * 0.5 - 0.03)), k)


## A gold coin: a flattened cylinder.
func _coin(me: PropBuilder, xf: Transform3D, k: int) -> void:
	me.cylinder(0.075, 0.075, 0.022, xf, PropPalette.COIN if k % 3 else PropPalette.COIN_RIM, 8)


# --- Masts -----------------------------------------------------------------------------------

## A mast spar from y0 to y1 at z: banded wood with iron hoops.
func _spar(parts: PropParts, z: float, y0: float, y1: float, r0: float, r1: float, hoop_every: float) -> void:
	var segs := maxi(int((y1 - y0) / 1.6), 2)
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var cols := PackedColorArray()
	for k in segs + 1:
		var f := float(k) / segs
		pts.append(Vector3(0, lerpf(y0, y1, f), z))
		radii.append(lerpf(r0, r1, f))
		if k < segs:
			cols.append(MAST_COL if k % 2 == 0 else MAST_COL_2)
	parts.matte.banded_tube(pts, radii, cols, 12, Transform3D.IDENTITY, true)
	var y := y0 + hoop_every
	while y < y1 - 0.3:
		var r := lerpf(r0, r1, (y - y0) / (y1 - y0))
		parts.metal.torus(r * 0.92, r * 1.16, Transform3D(Basis.IDENTITY, Vector3(0, y, z)), IRON, 14, 4)
		y += hoop_every


## A yard across the mast's fore side at height y, tapering to its arms.
func _yard(parts: PropParts, z: float, y: float, half: float) -> void:
	var c := Vector3(0, y, z)
	parts.matte.rod(c + Vector3(-half, 0, 0), c, 0.09, 0.18, YARD_COL, 8, true)
	parts.matte.rod(c, c + Vector3(half, 0, 0), 0.18, 0.09, YARD_COL, 8, true)
	for sx: float in [-1.0, 1.0]:
		parts.metal.sphere(0.11, Transform3D(Basis.IDENTITY, c + Vector3(sx * half, 0, 0)), IRON, 4, 6)
		parts.metal.torus(0.1, 0.14, Transform3D(Basis(Vector3.BACK, PI * 0.5), c + Vector3(sx * (half - 0.35), 0, 0)), IRON, 10, 4)
	parts.matte.torus(0.17, 0.28, Transform3D(Basis(Vector3.BACK, PI * 0.5), c), PropPalette.ROPE_DARK, 12, 5)


## A flat top (platform) at the lower masthead.
func _top(parts: PropParts, z: float, y: float, half: float) -> void:
	parts.matte.chamfer_box(Vector3(half * 2.0, 0.12, 1.3), 0.04, Transform3D(Basis.IDENTITY, Vector3(0, y, z + 0.05)), PropPalette.HULL_DARK)
	for sx: float in [-1.0, 1.0]:
		parts.matte.beam(Vector3(sx * half, y - 0.06, z + 0.05), Vector3(sx * 0.1, y - 0.75, z + 0.05), 0.08, 0.08, 0.02, PropPalette.HULL_DARK)


## Shrouds from the masthead down to the channels, with ratlines.
func _shrouds(parts: PropParts, mast_z: float, head_y: float) -> void:
	for side: float in [-1.0, 1.0]:
		var tops: Array[Vector3] = []
		var bots: Array[Vector3] = []
		for dz: float in [-0.25, 0.55, 1.35]:
			var bot := _chain_point(side, mast_z + dz)
			var top := Vector3(side * 0.22, head_y, mast_z + dz * 0.12)
			_line(parts.matte, top, bot + Vector3.UP * 0.18, 0.032, SHROUD)
			parts.matte.cylinder(0.09, 0.09, 0.07, Transform3D(Basis(Vector3.BACK, PI * 0.5), bot + Vector3.UP * 0.18), PropPalette.WOOD_DEEP, 8)
			_line(parts.matte, bot + Vector3.UP * 0.12, bot - Vector3.UP * 0.05, 0.025, IRON)
			tops.append(top)
			bots.append(bot + Vector3.UP * 0.18)
		var y := bots[0].y + 0.45
		while y < head_y - 0.5:
			var pts := PackedVector3Array()
			for k in 3:
				var f := (y - bots[k].y) / (tops[k].y - bots[k].y)
				pts.append(bots[k].lerp(tops[k], f))
			parts.matte.tube(pts, PackedFloat32Array([0.016]), ROPE, 3, false)
			y += 0.45


## Topmast shrouds from a mast point down to the top's edges, with ratlines.
func _top_shrouds(parts: PropParts, mast_z: float, head_y: float, top_y_: float, half: float) -> void:
	for side: float in [-1.0, 1.0]:
		var tops: Array[Vector3] = []
		var bots: Array[Vector3] = []
		for dz: float in [-0.25, 0.35]:
			var top := Vector3(side * 0.14, head_y, mast_z + dz * 0.2)
			var bot := Vector3(side * (half - 0.08), top_y_ + 0.06, mast_z + dz)
			_line(parts.matte, top, bot, 0.026, SHROUD)
			tops.append(top)
			bots.append(bot)
		var y := bots[0].y + 0.45
		while y < head_y - 0.4:
			var pts := PackedVector3Array()
			for k in 2:
				var f := (y - bots[k].y) / (tops[k].y - bots[k].y)
				pts.append(bots[k].lerp(tops[k], f))
			parts.matte.tube(pts, PackedFloat32Array([0.014]), ROPE, 3, false)
			y += 0.42


func _truck(parts: PropParts, z: float, y: float) -> void:
	parts.metal.sphere(0.17, Transform3D(Basis.IDENTITY, Vector3(0, y, z)), GOLD, 6, 10)


func _build_fore_mast() -> void:
	var foot := Vector3(0, deck_at(FORE_Z) + CAMBER, FORE_Z)
	fore_mast = PropKit.pivot(self, "ForeMast", Transform3D(Basis.IDENTITY, foot))
	var course_y := 6.55
	var top_h := 7.0
	var topsail_y := 11.2
	var head := 13.5
	var cz := FORE_Z - 0.45
	var tz := FORE_Z - 0.37
	add_mesh(_mesh("fore", func() -> Mesh:
		var parts := PropParts.new()
		_spar(parts, FORE_Z, foot.y - 0.4, top_h + 0.6, 0.3, 0.23, 1.5)
		_spar(parts, FORE_Z, top_h - 0.3, head, 0.2, 0.12, 1.4)
		_top(parts, FORE_Z, top_h, 1.0)
		_yard(parts, cz, course_y, 4.1)
		_yard(parts, tz, topsail_y, 3.25)
		_truck(parts, FORE_Z, head + 0.1)
		_shrouds(parts, FORE_Z, top_h - 0.25)
		_top_shrouds(parts, FORE_Z, topsail_y + 0.45, top_h, 1.0)
		# Stays to the bowsprit, backstays to the rails.
		_line(parts.matte, Vector3(0, top_h - 0.1, FORE_Z - 0.26), BOWSPRIT_ROOT.lerp(BOWSPRIT_TIP, 0.45) + Vector3.UP * 0.14, 0.04)
		_line(parts.matte, Vector3(0, head - 0.6, FORE_Z - 0.14), BOWSPRIT_TIP + Vector3(0, 0.1, 0.25), 0.035)
		for side: float in [-1.0, 1.0]:
			_line(parts.matte, Vector3(side * 0.12, head - 0.7, FORE_Z + 0.06), _chain_point(side, FORE_Z + 2.4) + Vector3.UP * 0.18, 0.026)
		# Lifts and course sheets.
		for sx: float in [-1.0, 1.0]:
			_line(parts.matte, Vector3(sx * 0.15, topsail_y + 0.9, FORE_Z - 0.12), Vector3(sx * 3.05, topsail_y, tz), 0.018, ROPE)
			_line(parts.matte, Vector3(sx * 3.75, course_y - 3.55, cz), _chain_point(sx, FORE_Z + 2.0) + Vector3.UP * 0.25, 0.018, ROPE, 0.1)
		return _local(parts, foot)
	), "ForeMastMesh", fore_mast)
	_add_square_sail("ForeCourse", fore_mast, foot, Vector3(0, course_y - 0.16, cz), 3.85, 4.0, 3.45, 0.85, [[0.62, 0.55, 0.78, 0.72, PATCH_A, 0.06]], 21)
	_add_square_sail("ForeTopsail", fore_mast, foot, Vector3(0, topsail_y - 0.15, tz), 3.0, 3.7, 3.65, 0.7, [], 22)
	_add_jib(foot)
	var hoist := Vector3(0, head - 0.05, FORE_Z + 0.14)
	var pennant := add_mesh(_mesh("pennant", func() -> Mesh:
		var layers: Array = []
		var fly := 2.6 if not damaged else 1.9
		var body := PackedVector2Array([Vector2(0, 0), Vector2(fly, 0.22), Vector2(fly - 0.12, 0.27), Vector2(0, 0.5)])
		if damaged:
			body = PackedVector2Array([Vector2(0, 0), Vector2(fly, 0.18), Vector2(fly - 0.25, 0.25), Vector2(fly + 0.05, 0.31), Vector2(0, 0.5)])
		layers.append([body, RED, 0.0])
		var band := Geometry2D.intersect_polygons(body, PackedVector2Array([Vector2(0.12, -1), Vector2(0.34, -1), Vector2(0.34, 2), Vector2(0.12, 2)]))
		for b: PackedVector2Array in band:
			layers.append([b, PATCH_A, 0.012])
		return _local(_flag_parts(layers, hoist, fly, 3, 9.0, 0.25), hoist)
	), "Pennant", fore_mast)
	pennant.position = hoist - foot


func _build_main_mast() -> void:
	var foot := Vector3(0, deck_at(MAIN_Z) + CAMBER, MAIN_Z)
	main_mast = PropKit.pivot(self, "MainMast", Transform3D(Basis.IDENTITY, foot))
	var brk := Vector3(0, BREAK_Y, MAIN_Z)
	main_mast_top = PropKit.pivot(main_mast, "MainMastTop", Transform3D(Basis.IDENTITY, brk - foot))
	var course_y := 7.2
	var top_h := 7.62
	var topsail_y := 12.3
	var nest_y := 13.15
	var head := 15.95
	var cz := MAIN_Z - 0.48
	var tz := MAIN_Z - 0.4
	add_mesh(_mesh("main_low", func() -> Mesh:
		var parts := PropParts.new()
		_spar(parts, MAIN_Z, foot.y - 0.4, BREAK_Y, 0.33, 0.26, 1.5)
		parts.metal.torus(0.22, 0.32, Transform3D(Basis.IDENTITY, Vector3(0, BREAK_Y - 0.06, MAIN_Z)), IRON, 14, 5)
		if damaged:
			_splinter_ring(parts.matte, Vector3(0, BREAK_Y, MAIN_Z), 0.25, 1.0, 31)
		_top(parts, MAIN_Z, top_h, 1.1)
		_yard(parts, cz, course_y, 4.45)
		_shrouds(parts, MAIN_Z, top_h - 0.25)
		# Main stay forward to the foremast's foot.
		_line(parts.matte, Vector3(0, top_h - 0.1, MAIN_Z - 0.3), Vector3(0, deck_at(FORE_Z) + 1.3, FORE_Z + 0.32), 0.04)
		for sx: float in [-1.0, 1.0]:
			_line(parts.matte, Vector3(sx * 4.1, course_y - 4.35, cz), _chain_point(sx, MAIN_Z + 2.2) + Vector3.UP * 0.25, 0.018, ROPE, 0.1)
			_line(parts.matte, Vector3(sx * 0.2, top_h - 0.1, MAIN_Z - 0.25), Vector3(sx * 4.0, course_y, cz), 0.018, ROPE)
		return _local(parts, foot)
	), "MainMastMesh", main_mast)
	add_mesh(_mesh("main_top", func() -> Mesh:
		var parts := PropParts.new()
		_spar(parts, MAIN_Z, BREAK_Y, head, 0.25, 0.13, 1.4)
		if damaged:
			_splinter_ring(parts.matte, Vector3(0, BREAK_Y, MAIN_Z), 0.24, -1.0, 32)
		_yard(parts, tz, topsail_y, 3.45)
		_crows_nest(parts, MAIN_Z, nest_y)
		_truck(parts, MAIN_Z, head + 0.1)
		_top_shrouds(parts, MAIN_Z, nest_y - 0.05, top_h, 1.1)
		# Topmast stay to the fore top; backstays to the stern rail.
		_line(parts.matte, Vector3(0, nest_y + 1.0, MAIN_Z - 0.14), Vector3(0, 7.1, FORE_Z + 0.24), 0.035)
		for side: float in [-1.0, 1.0]:
			var corner := Vector3(side * 1.75, qd_y(1.0) + 0.95, transom_point(0, 3.0).z - 0.45)
			_line(parts.matte, Vector3(side * 0.12, head - 0.9, MAIN_Z + 0.08), corner, 0.028)
			_line(parts.matte, Vector3(side * 0.15, nest_y - 0.1, MAIN_Z - 0.12), Vector3(side * 3.25, topsail_y, tz), 0.018, ROPE)
			_line(parts.matte, Vector3(side * 3.9, topsail_y - 3.95, tz), Vector3(side * 4.3, course_y + 0.1, cz), 0.02, ROPE)
		return _local(parts, brk)
	), "MainMastTopMesh", main_mast_top)
	_add_square_sail("MainCourse", main_mast, foot, Vector3(0, course_y - 0.16, cz), 4.2, 4.3, 4.2, 0.9, [[0.2, 0.52, 0.36, 0.7, PATCH_B, -0.08]], 31)
	_add_square_sail("MainTopsail", main_mast_top, brk, Vector3(0, topsail_y - 0.15, tz), 3.2, 4.0, 3.85, 0.75, [[0.58, 0.6, 0.72, 0.76, PATCH_A, 0.1]], 32)
	var hoist := Vector3(0, head - 0.1, MAIN_Z + 0.15)
	var flag := add_mesh(_mesh("jolly_roger", func() -> Mesh:
		return _local(_jolly_roger(hoist), hoist)
	), "JollyRoger", main_mast_top)
	flag.position = hoist - brk


## The bower anchor catted at the starboard bow, hanging against the hull.
func _anchor(parts: PropParts) -> void:
	var s := 0.11
	var y := top_y(s)
	var q := hull_point(1.0, s, y)
	var out := Vector3(1.0, 0.0, -0.3).normalized()
	var beam_end := q + out * 0.7 + Vector3.UP * 0.12
	parts.matte.beam(q - out * 0.35 + Vector3.UP * 0.12, beam_end, 0.2, 0.2, 0.04, PropPalette.HULL_DARK)
	var ring := beam_end + Vector3.DOWN * 0.35
	_line(parts.matte, beam_end, ring, 0.03, ROPE)
	var me := parts.metal
	var crown := ring + Vector3.DOWN * 1.55 + Vector3(-0.15, 0, 0.0)
	me.torus(0.08, 0.13, Transform3D(Basis(Vector3.UP, PI * 0.5), ring), IRON, 10, 4)
	me.rod(ring + Vector3.DOWN * 0.1, crown, 0.06, 0.07, IRON, 6)
	me.rod(ring + Vector3(0, -0.25, -0.5), ring + Vector3(0, -0.25, 0.5), 0.045, 0.045, PropPalette.HULL_DARK, 6)
	for sz: float in [-1.0, 1.0]:
		var arm := crown + Vector3(-0.05, 0.38, sz * 0.48)
		me.rod(crown, arm, 0.065, 0.05, IRON, 6)
		me.cylinder(0.0, 0.11, 0.24, Transform3D(Basis(Vector3.RIGHT, sz * 0.5), arm + Vector3(0, 0.08, sz * 0.03)), IRON, 6)


## Splinters round the break: dir +1 points up (lower stump), -1 down.
func _splinter_ring(mb: PropBuilder, c: Vector3, r: float, dir: float, seed_v: int) -> void:
	var rng := PropKit.make_rng(seed_v, 3)
	for k in 7:
		var a := TAU * (k + rng.randf_range(-0.3, 0.3)) / 7.0
		var off := Vector3(cos(a), 0, sin(a)) * r * rng.randf_range(0.35, 0.8)
		var tip := c + off * 1.1 + Vector3.UP * dir * rng.randf_range(0.15, 0.45)
		mb.rod(c + off - Vector3.UP * dir * 0.06, tip, r * rng.randf_range(0.3, 0.45), 0.0, PropPalette.PLANK_LIGHT, 4, true)


func _crows_nest(parts: PropParts, z: float, y: float) -> void:
	var prof := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.6, 0.0), Vector2(0.72, 0.1), Vector2(0.77, 0.42), Vector2(0.8, 0.62),
		Vector2(0.86, 0.66), Vector2(0.86, 0.78), Vector2(0.72, 0.78), Vector2(0.68, 0.16), Vector2(0.0, 0.16),
	])
	var cols := PackedColorArray([PropPalette.HULL_DARK, PropPalette.HULL_DARK, MAST_COL, RED, RAIL_COL, RAIL_COL, RAIL_COL, PropPalette.HULL_INNER, PropPalette.PLANK])
	parts.matte.lathe(prof, 16, Transform3D(Basis.IDENTITY, Vector3(0, y, z)), Color.WHITE, cols, true)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		parts.matte.beam(Vector3(0, y - 0.7, z), Vector3(cos(a) * 0.62, y + 0.02, z + sin(a) * 0.62), 0.07, 0.07, 0.02, PropPalette.HULL_DARK)


## A furled sail: a fat roll under its yard, tied with gaskets.
func _furl_mesh(half: float, r: float) -> ArrayMesh:
	var parts := PropParts.new()
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 9:
		var f := float(k) / 8.0
		pts.append(Vector3(lerpf(-half, half, f), -0.06 - 0.05 * sin(f * PI), -0.08))
		radii.append(r * (0.55 + 0.45 * sin(f * PI)))
	parts.soft.tube(pts, radii, CLOTH.darkened(0.04), 10, true)
	for k in 5:
		var f := (k + 0.5) / 5.0
		var p := Vector3(lerpf(-half, half, f), -0.06 - 0.05 * sin(f * PI), -0.08)
		parts.matte.torus(r * (0.55 + 0.45 * sin(f * PI)) * 0.92, r * (0.55 + 0.45 * sin(f * PI)) * 1.12, Transform3D(Basis(Vector3.BACK, PI * 0.5), p), ROPE, 10, 4)
	return parts.build()


## A square sail and its furled roll, both children of `parent` at `head`.
## patches: [u0, v0, u1, v1, color, tilt].
func _add_square_sail(sail_name: String, parent: Node3D, parent_origin: Vector3, head: Vector3, head_hw: float, foot_hw: float, drop: float, belly: float, patches: Array, seed_v: int) -> void:
	var mesh := _mesh(sail_name, func() -> Mesh: return _square_sail(head_hw, foot_hw, drop, belly, patches, seed_v))
	var mi := add_mesh(mesh, sail_name, parent)
	mi.position = head - parent_origin
	sails[sail_name] = mi
	_belly_axis[sail_name] = 2
	var furl := add_mesh(_mesh(sail_name + "_furl", func() -> Mesh: return _furl_mesh(head_hw, 0.2 + belly * 0.05)), sail_name + "Furled", parent)
	furl.position = head - parent_origin
	_furled[sail_name] = furl


## Sail cloth (foliage "cloth" material: double-sided, flutters). Origin at
## the head's center; hangs down and bellies toward -Z. Colors as on the
## wreck: cream with a red band.
func _square_sail(head_hw: float, foot_hw: float, drop: float, belly: float, patches: Array, seed_v: int) -> ArrayMesh:
	var parts := PropParts.new()
	parts.foliage_profile = &"cloth"
	var mb := parts.foliage
	var pt := func(u: float, v: float) -> Vector3:
		var hw := lerpf(head_hw, foot_hw, v)
		var y := -drop * v + 0.35 * sin(PI * u) * v * v
		var b := belly * (0.3 + 0.7 * sin(PI * u)) * sin(PI * 0.8 * v)
		return Vector3(lerpf(-hw, hw, u), y, -b)
	var torn := _tear_fn(seed_v, patches, 0.84)
	_cloth(mb, pt, 26 if damaged else 16, _sail_bands(), torn, Vector3.FORWARD)
	for p: Array in patches:
		_patch(mb, pt, p, (p[4] as Color))
	return parts.build()


## Color bands down a sail, as on the wreck: cream with a red band, plus a
## red hem along the foot. [v0, v1, rows, color]; finer when damaged.
func _sail_bands() -> Array:
	var d := damaged
	return [[0.0, 0.3, 6 if d else 4, CLOTH], [0.3, 0.44, 3 if d else 2, STRIPE], [0.44, 0.93, 10 if d else 6, CLOTH], [0.93, 1.0, 2 if d else 1, STRIPE]]


## Where a damaged sail is torn away: a ragged foot below `edge` and a few
## noisy holes (never through the patches). Always false when intact.
func _tear_fn(seed_v: int, patches: Array, edge: float) -> Callable:
	if not damaged:
		return func(_u: float, _v: float) -> bool: return false
	var rng := PropKit.make_rng(seed_v, 99)
	var noise := FastNoiseLite.new()
	noise.seed = seed_v
	noise.frequency = 0.9
	var holes: Array[Vector3] = []
	for h in 3:
		holes.append(Vector3(rng.randf_range(0.15, 0.85), rng.randf_range(0.5, 0.8), rng.randf_range(0.06, 0.11)))
	return func(u: float, v: float) -> bool:
		for p: Array in patches:
			if u > float(p[0]) - 0.03 and u < float(p[2]) + 0.03 and v > float(p[1]) - 0.03 and v < float(p[3]) + 0.03:
				return false
		if v > edge + 0.09 * noise.get_noise_2d(u * 9.0, 3.0) + 0.04 * noise.get_noise_2d(u * 31.0, 7.0):
			return true
		for h: Vector3 in holes:
			var d := Vector2((u - h.x) * 1.2, v - h.y).length()
			if d < h.z * (1.0 + 0.6 * noise.get_noise_2d(u * 14.0, v * 14.0)):
				return true
		return false


## Cloth over pt(u, v) (u across, v down from the head) in color bands
## [v0, v1, rows, color]: shared vertices per band, normals
## from the surface facing `front`. Vertices where torn(u, v) are dropped and
## a cell keeps any triangle whose corners all survive, so tears are jagged.
## UV: x phase (constant: per-column phases would wiggle the stripe
## edges), y sway weight for the cloth material.
func _cloth(mb: PropBuilder, pt: Callable, nc: int, bands: Array, torn: Callable, front: Vector3) -> void:
	var e := 0.004
	for band: Array in bands:
		var v0: float = band[0]
		var v1: float = band[1]
		var nr: int = band[2]
		var col: Color = band[3]
		var base := mb.mark()
		var ok := PackedByteArray()
		for j in nr + 1:
			var v := lerpf(v0, v1, float(j) / nr)
			for i in nc + 1:
				var u := float(i) / nc
				var du: Vector3 = pt.call(minf(u + e, 1.0), v) - pt.call(maxf(u - e, 0.0), v)
				var dv: Vector3 = pt.call(u, minf(v + e, 1.0)) - pt.call(u, maxf(v - e, 0.0))
				var n := du.cross(dv)
				n = n.normalized() if n.length_squared() > 1e-12 else front
				if n.dot(front) < 0.0:
					n = -n
				mb.vert(pt.call(u, v), n, col, Vector2(CLOTH_PHASE, v * 0.7))
				ok.append(0 if torn.call(u, v) else 1)
		var w := nc + 1
		for j in nr:
			for i in nc:
				var a := j * w + i
				var corners: Array[int] = [a, a + 1, a + w + 1, a + w]
				var alive: Array[int] = []
				for c: int in corners:
					if ok[c] == 1:
						alive.append(c)
				if alive.size() == 4:
					mb.quad(base + a, base + a + 1, base + a + w + 1, base + a + w, front)
				elif alive.size() == 3:
					mb.tri(base + alive[0], base + alive[1], base + alive[2], front)


## A patch stitched on both faces of a sail (sail function `pt(u, v)`).
func _patch(mb: PropBuilder, pt: Callable, p: Array, col: Color) -> void:
	var u0: float = p[0]
	var v0: float = p[1]
	var u1: float = p[2]
	var v1: float = p[3]
	var tilt: float = p[5]
	var e := 0.01
	# Sail-space point tilted a little about the patch's center.
	var tilted := func(u: float, v: float) -> Vector2:
		var cu := (u0 + u1) * 0.5
		var cv := (v0 + v1) * 0.5
		return Vector2(cu + (u - cu) * cos(tilt) - (v - cv) * sin(tilt), cv + (u - cu) * sin(tilt) + (v - cv) * cos(tilt))
	var nrm := func(u: float, v: float) -> Vector3:
		var t: Vector2 = tilted.call(u, v)
		var n: Vector3 = (pt.call(t.x + e, t.y) - pt.call(t.x - e, t.y)).cross(pt.call(t.x, t.y + e) - pt.call(t.x, t.y - e)).normalized()
		return -n if n.z > 0.0 else n
	var at := func(u: float, v: float, off: float) -> Vector3:
		var t: Vector2 = tilted.call(u, v)
		return pt.call(t.x, t.y) + nrm.call(u, v) * off
	for f: float in [1.0, -1.0]:
		var base0 := mb.mark()
		for j in 3:
			for i in 3:
				var uu := lerpf(u0, u1, i / 2.0)
				var vv := lerpf(v0, v1, j / 2.0)
				mb.vert(at.call(uu, vv, 0.03 * f), nrm.call(uu, vv) * f, col, Vector2(CLOTH_PHASE, vv * 0.7))
		for j in 2:
			for i in 2:
				var c0 := base0 + j * 3 + i
				mb.quad(c0, c0 + 1, c0 + 4, c0 + 3, Vector3.FORWARD * f)
		# Cross stitches round the edge.
		for k in 4:
			var t := (k + 0.5) / 4.0
			for edge_pts: Array in [[Vector2(lerpf(u0, u1, t), v0), Vector2(0, 1)], [Vector2(lerpf(u0, u1, t), v1), Vector2(0, 1)], [Vector2(u0, lerpf(v0, v1, t)), Vector2(1, 0)], [Vector2(u1, lerpf(v0, v1, t)), Vector2(1, 0)]]:
				var c: Vector2 = edge_pts[0]
				var d: Vector2 = edge_pts[1]
				var a: Vector3 = at.call(c.x - d.x * 0.012, c.y - d.y * 0.02, 0.04 * f)
				var b: Vector3 = at.call(c.x + d.x * 0.012, c.y + d.y * 0.02, 0.04 * f)
				var w := (b - a).cross(Vector3.FORWARD).normalized() * 0.018
				var base := mb.mark()
				var nn: Vector3 = nrm.call(c.x, c.y) * f
				var uv := Vector2(CLOTH_PHASE, c.y * 0.7)
				for q: Vector3 in [a - w, a + w, b + w, b - w]:
					mb.vert(q, nn, STITCH, uv)
				mb.quad(base, base + 1, base + 2, base + 3, nn)


## The jib on the stay from the bowsprit up toward the foremast.
func _add_jib(foot: Vector3) -> void:
	var stay_top := Vector3(0, 13.5 - 0.6, FORE_Z - 0.12)
	var stay_bot := BOWSPRIT_TIP + Vector3(0, 0.1, 0.25)
	var tack := stay_bot.lerp(stay_top, 0.06)
	var head := stay_bot.lerp(stay_top, 0.62)
	var clew := Vector3(0, fc_y() + 1.35, -6.6)
	var origin := (tack + head) * 0.5
	var mesh := _mesh("jib", func() -> Mesh:
		var parts := PropParts.new()
		parts.foliage_profile = &"cloth"
		var mb := parts.foliage
		var pt := func(u: float, v: float) -> Vector3:
			var luff := tack.lerp(head, u)
			var q := luff.lerp(clew, v)
			return q + Vector3(0.55 * sin(PI * u) * sin(PI * v) * (1.0 - v * 0.3), 0, 0) - origin
		var d := damaged
		var bands := [[0.0, 0.3, 4 if d else 3, CLOTH], [0.3, 0.44, 2, STRIPE], [0.44, 1.0, 8 if d else 5, CLOTH]]
		_cloth(mb, pt, 18 if d else 12, bands, _tear_fn(41, [], 0.8), Vector3.RIGHT)
		return parts.build()
	)
	var mi := add_mesh(mesh, "Jib", fore_mast)
	mi.position = origin - foot
	sails["Jib"] = mi
	_belly_axis["Jib"] = 0
	var furl := add_mesh(_mesh("jib_furl", func() -> Mesh:
		var parts := PropParts.new()
		# Stowed along the top of the bowsprit, lashed down.
		var a := BOWSPRIT_ROOT.lerp(BOWSPRIT_TIP, 0.38) + Vector3.UP * 0.2 - origin
		var b := BOWSPRIT_ROOT.lerp(BOWSPRIT_TIP, 0.9) + Vector3.UP * 0.15 - origin
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for k in 6:
			var f := k / 5.0
			pts.append(a.lerp(b, f))
			radii.append(0.07 + 0.08 * sin(f * PI))
		parts.soft.tube(pts, radii, CLOTH.darkened(0.04), 8, true)
		for k in 3:
			var f := (k + 0.5) / 3.0
			var r := 0.07 + 0.08 * sin(f * PI)
			parts.matte.torus(r * 0.95, r * 1.2, Transform3D(PropKit.basis_y(b - a), a.lerp(b, f)), ROPE, 10, 4)
		return parts.build()
	), "JibFurled", fore_mast)
	furl.position = origin - foot
	_furled["Jib"] = furl


# --- Flags ---------------------------------------------------------------------------------------

static func _circle(c: Vector2, r: Vector2, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		out.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out


## A bar from a to b of width w (flag space).
static func _bar(a: Vector2, b: Vector2, w: float) -> PackedVector2Array:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * w * 0.5
	return PackedVector2Array([a - n, b - n, b + n, a + n])


static func _union(polys: Array) -> PackedVector2Array:
	var acc: PackedVector2Array = polys[0]
	for k in range(1, polys.size()):
		var merged := Geometry2D.merge_polygons(acc, polys[k])
		var best := acc
		var best_a := 0.0
		for m: PackedVector2Array in merged:
			var a := absf(PropBuilder._signed_area(m))
			if a > best_a:
				best_a = a
				best = m
		acc = best
	return acc


## Patchy's Jolly Roger: black, a white skull wearing an eyepatch over
## crossed bones. Flag space: a along the fly (aft), b down from the top.
func _jolly_roger(hoist: Vector3) -> PropParts:
	var fly := 1.9
	var drop := 1.25
	var layers: Array = []
	var cloth := PackedVector2Array([Vector2(0, 0), Vector2(fly, 0.04), Vector2(fly, drop - 0.02), Vector2(0, drop)])
	if damaged:
		cloth = PackedVector2Array([Vector2(0, 0), Vector2(fly - 0.1, 0.04), Vector2(fly - 0.35, 0.28), Vector2(fly - 0.05, 0.45), Vector2(fly - 0.42, 0.7),
			Vector2(fly - 0.15, 0.9), Vector2(fly - 0.3, drop - 0.05), Vector2(0, drop)])
	layers.append([cloth, FLAG_BLACK, 0.0])
	var c := Vector2(0.92, 0.56)
	# Crossed bones behind the skull.
	for k: float in [1.0, -1.0]:
		var a := c + Vector2(-0.42, 0.24 * k + 0.16)
		var b := c + Vector2(0.42, -0.24 * k + 0.16)
		var bone := _union([_bar(a, b, 0.1), _circle(a + Vector2(-0.02, -0.05), Vector2(0.065, 0.065), 10), _circle(a + Vector2(0.02, 0.05), Vector2(0.065, 0.065), 10),
			_circle(b + Vector2(0.02, -0.05), Vector2(0.065, 0.065), 10), _circle(b + Vector2(-0.02, 0.05), Vector2(0.065, 0.065), 10)])
		layers.append([bone, BONE, 0.012])
	var skull := _union([_circle(c + Vector2(0, -0.08), Vector2(0.3, 0.28), 20), _bar(c + Vector2(0, 0.08), c + Vector2(0, 0.3), 0.32), _circle(c + Vector2(-0.1, 0.27), Vector2(0.07, 0.07), 8), _circle(c + Vector2(0.1, 0.27), Vector2(0.07, 0.07), 8)])
	layers.append([skull, BONE, 0.02])
	# Face: one eye socket, the eyepatch with its strap, nose and teeth.
	var ink := FLAG_BLACK
	layers.append([_circle(c + Vector2(0.12, -0.04), Vector2(0.075, 0.08), 12), ink, 0.028])
	layers.append([_circle(c + Vector2(-0.12, -0.04), Vector2(0.11, 0.1), 14), ink, 0.028])
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(_bar(c + Vector2(-0.31, 0.07), c + Vector2(0.27, -0.25), 0.045), skull):
		layers.append([piece, ink, 0.028])
	layers.append([PackedVector2Array([c + Vector2(-0.045, 0.06), c + Vector2(0.045, 0.06), c + Vector2(0, 0.14)]), ink, 0.028])
	layers.append([_bar(c + Vector2(-0.13, 0.2), c + Vector2(0.13, 0.2), 0.025), ink, 0.028])
	for x: float in [-0.065, 0.0, 0.065]:
		layers.append([_bar(c + Vector2(x, 0.19), c + Vector2(x, 0.3), 0.022), ink, 0.028])
	return _flag_parts(layers, hoist, fly, 3, 10.0, 0.12)


## Flat cloth shapes in flag space (a along the fly, b down from the hoist's
## top) folded into `folds` planar panels zigzagging aft from `hoist`.
## layers: [polygon, color, offset]; offset 0 is the cloth (drawn once, the
## cloth material is double-sided), > 0 lies on both faces.
func _flag_parts(layers: Array, hoist: Vector3, length: float, folds: int, fold_deg: float, droop: float) -> PropParts:
	var parts := PropParts.new()
	parts.foliage_profile = &"cloth"
	var mb := parts.foliage
	var knots: Array[Vector3] = [hoist]
	var dirs: Array[Vector3] = []
	for k in folds:
		var ang := deg_to_rad(fold_deg) * (1.0 if k % 2 == 0 else -1.0)
		var d := Vector3(sin(ang), -droop / length, cos(ang)).normalized()
		dirs.append(d)
		knots.append(knots[k] + d * (length / folds))
	for layer: Array in layers:
		var poly: PackedVector2Array = layer[0]
		var col: Color = layer[1]
		var off: float = layer[2]
		for k in folds:
			var a0 := length * k / folds
			var a1 := length * (k + 1) / folds
			if k == folds - 1:
				a1 = 99.0
			if k == 0:
				a0 = -99.0
			var n := dirs[k].cross(Vector3.DOWN).normalized()
			var clip := PackedVector2Array([Vector2(a0, -50), Vector2(a1, -50), Vector2(a1, 50), Vector2(a0, 50)])
			var ka := length * k / folds
			for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, clip):
				var tris := Geometry2D.triangulate_polygon(piece)
				if tris.is_empty():
					continue
				var faces := [1.0] if off <= 0.0 else [1.0, -1.0]
				for f: float in faces:
					var base := mb.mark()
					for q: Vector2 in piece:
						var pos := knots[k] + dirs[k] * (q.x - ka) + Vector3(0, -q.y, 0) + n * off * f
						mb.vert(pos, n * f, col, Vector2(0.3, clampf(q.x / length, 0.0, 1.0)))
					for t in range(0, tris.size(), 3):
						mb.tri(base + tris[t], base + tris[t + 1], base + tris[t + 2], n * f)
	return parts

