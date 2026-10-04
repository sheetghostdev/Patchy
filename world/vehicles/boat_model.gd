class_name BoatModel
## How Patchy's boat looks (ShipUpgrades.spec()): the hull (plain planks,
## copper-bottomed, or iron-banded with a plated bow), the sail (Gus's
## patched sail, Betty's spare, or the racing rig) in its colors, the flag
## at the masthead, a figurehead on the bow and the bow cannon. Built in
## code as one Node3D in boat space (bow toward -Z, the waterline at y 0):
## TinyBoat wears it, and the shipyard turns one in its window.

const LENGTH := 3.8
const HALF_WIDTH := 0.86
const KEEL_Y := -0.4
const GUNWALE_Y := 0.48
const SEAT_Z := 0.78
const MAST_Z := -0.75
## The masthead, by sail level.
const MAST_TOP: Array[float] = [3.0, 3.6, 4.3]
## The bow cannon's muzzle.
const MUZZLE := Vector3(0, 0.55, -1.72)

const HULL := Color("8a5a36")
const HULL_INSIDE := Color("c08a55")
const COPPER := Color("c8743a")
const IRON := Color("4b5058")


## The whole boat for `spec` (ShipUpgrades.spec(); missing keys are the
## plain dinghy).
static func make(spec: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "BoatModel"
	var level := int(spec.get("sail", 0))
	_add(root, "Hull", hull_mesh(int(spec.get("hull", 0))))
	_add(root, "Sail", sail_mesh(level, int(spec.get("colors", ShipUpgrades.sail_colors(level, -1))), int(spec.get("flag", 0))))
	var fig := figurehead_mesh(int(spec.get("figurehead", 0)))
	if fig != null:
		_add(root, "Figurehead", fig)
	if bool(spec.get("cannon", false)):
		_add(root, "Cannon", cannon_mesh())
	return root


static func _add(root: Node3D, name: String, mesh: Mesh) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	root.add_child(mi)


# --- Hull ------------------------------------------------------------------------------

## Half-width and gunwale height along the hull, s = 0 at the bow, 1 at the stern.
static func _section(s: float) -> Vector2:
	var w := 0.0
	if s < 0.62:
		w = 0.06 + 0.94 * pow(sin(s / 0.62 * PI * 0.5), 0.75)
	else:
		w = 1.0 - 0.3 * pow((s - 0.62) / 0.38, 2.0)
	var top := GUNWALE_Y + 0.26 * pow(1.0 - s, 2.2)
	return Vector2(w * HALF_WIDTH, top)


static func _hull_rows(scale_w: float, keel_lift: float, top_drop: float) -> Array:
	var rows: Array = []
	var nrows := 14
	var ncols := 11
	for j in nrows:
		var s := float(j) / (nrows - 1)
		var z := -LENGTH * 0.5 + s * LENGTH
		var sec := _section(s)
		var w := sec.x * scale_w
		var top := sec.y - top_drop
		var keel := KEEL_Y + keel_lift + 0.18 * pow(1.0 - s, 3.0)
		var row := PackedVector3Array()
		for i in ncols:
			var a := -PI * 0.5 + PI * float(i) / (ncols - 1)
			var x := w * sin(a)
			var y := keel + (top - keel) * (1.0 - pow(cos(a), 0.7))
			row.append(Vector3(x, y, z))
		rows.append(row)
	return rows


static func _out(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y - GUNWALE_Y, 0.0).normalized()


## The hull: 0 plain planks (also drawn upside down on Gus's trestles),
## 1 copper-bottomed, 2 iron-banded with a plated bow.
static func hull_mesh(level := 0) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var outer := _hull_rows(1.0, 0.0, 0.0)
	var inner := _hull_rows(0.86, 0.12, 0.03)
	var hull_color := HULL if level < 2 else HULL.darkened(0.18)
	mb.grid(outer, hull_color, func(p: Vector3) -> Vector3: return _out(p) + Vector3(0, 0, -0.3 if p.z < -1.2 else 0.0))
	mb.grid(inner, HULL_INSIDE, func(p: Vector3) -> Vector3: return -_out(p))
	# Transom (flat stern) and gunwale rails.
	var last: PackedVector3Array = outer[outer.size() - 1]
	var center := Vector3(0, (KEEL_Y + GUNWALE_Y) * 0.5, LENGTH * 0.5)
	for i in last.size() - 1:
		mb.triangle(center, last[i], last[i + 1], hull_color.darkened(0.1), true)
	mb.triangle(last[0], last[last.size() - 1], center, hull_color.darkened(0.1), true)
	for side: int in [0, 10]:
		var rail := PackedVector3Array()
		var radii := PackedFloat32Array()
		for j in outer.size():
			var p: Vector3 = outer[j][side]
			rail.append(p + Vector3(0, 0.02, 0))
			radii.append(0.06)
		mb.tube(rail, radii, IRON if level >= 2 else Palette.WOOD_DARK, 6, true)
	var stern_rail := PackedVector3Array([last[0] + Vector3(0, 0.02, 0), last[last.size() - 1] + Vector3(0, 0.02, 0)])
	mb.tube(stern_rail, PackedFloat32Array([0.06, 0.06]), IRON if level >= 2 else Palette.WOOD_DARK, 6, true)
	# A colorful band along the hull (Patchy's red).
	for j in outer.size() - 1:
		for side: int in [1, 9]:
			var a: Vector3 = outer[j][side]
			var b: Vector3 = outer[j + 1][side]
			var o := Vector3(signf(a.x) * 0.012, 0, 0)
			mb.box(Vector3(0.02, 0.07, a.distance_to(b) + 0.02), Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5 + o), Palette.COAT)
	if level >= 1:
		_copper(mb, outer)
	if level >= 2:
		_iron(mb, outer)
	# Thwarts (seats), rudder and tiller.
	mb.box(Vector3(HALF_WIDTH * 1.7, 0.07, 0.34), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, SEAT_Z)), Palette.WOOD)
	mb.box(Vector3(HALF_WIDTH * 1.6, 0.07, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, 0.22, -0.55)), Palette.WOOD)
	mb.box(Vector3(0.08, 0.9, 0.5), Transform3D(Basis.IDENTITY, Vector3(0, -0.05, LENGTH * 0.5 + 0.12)), IRON if level >= 2 else Palette.WOOD_DARK)
	mb.cylinder(0.035, 0.035, 0.9, Transform3D(Basis.from_euler(Vector3(PI * 0.5 - 0.25, 0, 0)), Vector3(0, 0.42, LENGTH * 0.5 - 0.18)), Palette.WOOD_DARK, 6)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))


## Copper sheathing from just above the waterline down over the keel.
static func _copper(mb: MeshBuilder, outer: Array) -> void:
	var rows: Array = []
	for row: PackedVector3Array in outer:
		var r := PackedVector3Array()
		for i in range(1, 10):
			r.append(row[i] + _out(row[i]) * 0.014)
		rows.append(r)
	mb.grid(rows, COPPER, func(p: Vector3) -> Vector3: return _out(p))
	# A brighter strake where the copper meets the planks.
	for side: int in [1, 9]:
		var line := PackedVector3Array()
		var radii := PackedFloat32Array()
		for row: PackedVector3Array in outer:
			line.append(row[side] + _out(row[side]) * 0.02)
			radii.append(0.022)
		mb.tube(line, radii, COPPER.lightened(0.25), 5, true)


## Iron bands round the hull and a plate over the bow.
static func _iron(mb: MeshBuilder, outer: Array) -> void:
	for j: int in [3, 6, 9, 12]:
		var row: PackedVector3Array = outer[j]
		var band := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in row.size():
			band.append(row[i] + _out(row[i]) * 0.035)
			radii.append(0.035)
		mb.tube(band, radii, IRON, 5, true)
		for i: int in [0, 3, 7, 10]:
			mb.sphere(0.03, Transform3D(Basis.IDENTITY, row[i] + _out(row[i]) * 0.07), IRON.lightened(0.35), 3, 5)
	# The plated stem: a wedge of iron up the bow.
	var stem := PackedVector3Array()
	var radii := PackedFloat32Array()
	for j in 4:
		var p: Vector3 = (outer[j] as PackedVector3Array)[5]
		var top: Vector3 = (outer[j] as PackedVector3Array)[0].lerp((outer[j] as PackedVector3Array)[10], 0.5)
		stem.append(p.lerp(top, 0.5) + Vector3(0, 0, -0.04))
		radii.append(lerpf(0.09, 0.05, j / 3.0))
	mb.tube(stem, radii, IRON, 6, true)


# --- Sails and flags ------------------------------------------------------------------

## The mast, sail(s) and the flag at the masthead. Level 0 Gus's patched
## triangle, 1 Betty's striped spare with a jib, 2 the racing rig: a tall
## mast, a gaff mainsail, a topsail, two jibs and a bowsprit.
static func sail_mesh(level: int, colors: int, flag: int) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var c: Array = ShipUpgrades.SAIL_COLORS[posmod(colors, ShipUpgrades.SAIL_COLORS.size())]
	var cloth: Color = c[1]
	var stripe: Color = c[2]
	var patch: Color = c[3]
	var patch2: Color = c[4]
	var top: float = MAST_TOP[clampi(level, 0, MAST_TOP.size() - 1)]
	mb.cylinder(0.05 + level * 0.008, 0.065 + level * 0.008, top - 0.1, Transform3D(Basis.IDENTITY, Vector3(0, 0.1 + (top - 0.1) * 0.5, MAST_Z)), Palette.WOOD_DARK, 8)
	match level:
		0:
			_boom(mb, 1.7, 0.75)
			mb.triangle(Vector3(0, 2.85, MAST_Z), Vector3(0, 0.82, MAST_Z + 0.05), Vector3(0, 0.82, MAST_Z + 1.65), cloth, true)
			mb.triangle(Vector3(0.012, 2.85, MAST_Z), Vector3(0.012, 1.7, MAST_Z + 0.45), Vector3(0.012, 1.35, MAST_Z + 0.85), patch, true)
			mb.triangle(Vector3(-0.012, 1.0, MAST_Z + 0.6), Vector3(-0.012, 1.45, MAST_Z + 0.55), Vector3(-0.012, 1.0, MAST_Z + 1.05), patch2, true)
		1:
			_boom(mb, 2.0, 0.8)
			_striped(mb, 4, 1.85, 3.45, 1.15, 0.86, cloth, stripe)
			_square(mb, Vector3(0.1, 1.3, MAST_Z + 0.95), 0.3, patch)
			mb.triangle(Vector3(0, 3.3, MAST_Z), Vector3(0, 0.75, MAST_Z - 0.05), Vector3(0, 0.62, -LENGTH * 0.5 + 0.12), stripe, true)
		_:
			_boom(mb, 2.2, 0.82)
			# Gaff from high on the mast up and aft.
			var gaff_from := Vector3(0, 3.55, MAST_Z)
			var gaff_to := Vector3(0, 4.05, MAST_Z + 1.9)
			mb.tube(PackedVector3Array([gaff_from, gaff_to]), PackedFloat32Array([0.04, 0.03]), Palette.WOOD_DARK, 6, true)
			var strips := 5
			for k in strips:
				var t0 := float(k) / strips
				var t1 := float(k + 1) / strips
				var z0 := MAST_Z + 0.05 + 1.85 * t0
				var z1 := MAST_Z + 0.05 + 1.85 * t1
				var y0 := lerpf(gaff_from.y, gaff_to.y, t0) - 0.06
				var y1 := lerpf(gaff_from.y, gaff_to.y, t1) - 0.06
				var belly := 0.1 * sin(PI * (k + 0.5) / strips)
				var col := cloth if k % 2 == 0 else stripe
				mb.triangle(Vector3(belly, y0, z0), Vector3(belly, y1, z1), Vector3(belly, 0.88, z1), col, true)
				mb.triangle(Vector3(belly, y0, z0), Vector3(belly, 0.88, z1), Vector3(belly, 0.88, z0), col, true)
			_square(mb, Vector3(0.13, 1.5, MAST_Z + 1.25), 0.34, patch)
			# Topsail between the masthead and the gaff's end.
			mb.triangle(Vector3(0, top - 0.08, MAST_Z), Vector3(0, 3.62, MAST_Z + 0.1), Vector3(0, 4.0, MAST_Z + 1.75), stripe, true)
			# Bowsprit and two jibs.
			var sprit_end := Vector3(0, 0.95, -LENGTH * 0.5 - 0.85)
			mb.tube(PackedVector3Array([Vector3(0, 0.62, -LENGTH * 0.5 + 0.35), sprit_end]), PackedFloat32Array([0.05, 0.035]), Palette.WOOD_DARK, 6, true)
			mb.triangle(Vector3(0, top - 0.3, MAST_Z), Vector3(0, 0.8, MAST_Z - 0.05), Vector3(0, 0.7, -LENGTH * 0.5 + 0.1), stripe, true)
			mb.triangle(Vector3(0, top - 0.2, MAST_Z - 0.02), Vector3(0, 0.82, -LENGTH * 0.5 + 0.0), sprit_end, cloth, true)
	_flag(mb, flag, top)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


static func _boom(mb: MeshBuilder, length: float, y: float) -> void:
	mb.cylinder(0.035 + 0.005 * length, 0.035 + 0.005 * length, length, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, y, MAST_Z + length * 0.5)), Palette.WOOD_DARK, 6)


## A sail of vertical strips from the mast aft to the boom: the luff `luff`
## high at the mast, falling to `leech` at the clew `length` aft.
static func _striped(mb: MeshBuilder, strips: int, length: float, luff: float, leech: float, foot: float, a: Color, b: Color) -> void:
	for k in strips:
		var z0 := MAST_Z + 0.05 + length * k / strips
		var z1 := MAST_Z + 0.05 + length * (k + 1) / strips
		var top0 := luff - (luff - leech) * float(k) / strips
		var top1 := luff - (luff - leech) * float(k + 1) / strips
		var belly := 0.08 * sin(PI * (k + 0.5) / strips)
		var col := a if k % 2 == 0 else b
		mb.triangle(Vector3(belly, top0, z0), Vector3(belly, top1, z1), Vector3(belly, foot, z1), col, true)
		mb.triangle(Vector3(belly, top0, z0), Vector3(belly, foot, z1), Vector3(belly, foot, z0), col, true)


## A square patch stitched on (both faces of the sail).
static func _square(mb: MeshBuilder, corner: Vector3, size: float, col: Color) -> void:
	for side: float in [1.0, -1.0]:
		var o := Vector3(corner.x * side, corner.y, corner.z)
		mb.triangle(o + Vector3(0, size, 0), o + Vector3(0, size, size), o + Vector3(0, 0, size), col, true)
		mb.triangle(o + Vector3(0, size, 0), o + Vector3(0, 0, size), o, col, true)


## A flat shape in the flag's plane (x 0, streaming aft), given as (aft, up)
## points from the hoist's top, fanned from the first.
static func _flag_poly(mb: MeshBuilder, at: Vector3, pts: Array, col: Color, x := 0.0) -> void:
	for i in range(1, pts.size() - 1):
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[i]
		var d: Vector2 = pts[i + 1]
		mb.triangle(at + Vector3(x, a.y, a.x), at + Vector3(x, b.y, b.x), at + Vector3(x, d.y, d.x), col, true)


static func _flag(mb: MeshBuilder, flag: int, top: float) -> void:
	var at := Vector3(0, top + 0.05, MAST_Z + 0.04)
	mb.sphere(0.06, Transform3D(Basis.IDENTITY, Vector3(0, top + 0.08, MAST_Z)), Color("f2c14e"), 4, 6)
	match flag:
		1:
			# Jolly Roger: black, a white skull over crossed bones.
			_flag_poly(mb, at, [Vector2(0, 0), Vector2(0.62, -0.02), Vector2(0.62, -0.42), Vector2(0, -0.42)], Color("1d1f26"))
			var mid := at + Vector3(0, -0.2, 0.31)
			for k: float in [1.0, -1.0]:
				mb.box(Vector3(0.024, 0.04, 0.34), Transform3D(Basis(Vector3.RIGHT, k * 0.65), mid + Vector3(0, -0.02, 0)), Color("f4efe2"))
			mb.ellipsoid(Vector3(0.022, 0.085, 0.08), Transform3D(Basis.IDENTITY, mid + Vector3(0, 0.03, 0)), Color("f4efe2"), 5, 8)
			mb.box(Vector3(0.024, 0.05, 0.08), Transform3D(Basis.IDENTITY, mid + Vector3(0, -0.06, 0)), Color("f4efe2"))
		2:
			# Parrot Tail: green, swallow-tailed, a yellow and a red band.
			_flag_poly(mb, at, [Vector2(0, 0), Vector2(0.7, -0.02), Vector2(0.5, -0.2), Vector2(0.7, -0.38), Vector2(0, -0.4)], Color("3fa34d"))
			for x: float in [0.012, -0.012]:
				_flag_poly(mb, at, [Vector2(0.06, -0.01), Vector2(0.16, -0.01), Vector2(0.16, -0.39), Vector2(0.06, -0.39)], Color("f2c14e"), x)
				_flag_poly(mb, at, [Vector2(0.16, -0.01), Vector2(0.24, -0.01), Vector2(0.24, -0.39), Vector2(0.16, -0.39)], Color("d8433a"), x)
		3:
			# Sea Star: deep blue with a gold star.
			_flag_poly(mb, at, [Vector2(0, 0), Vector2(0.62, 0), Vector2(0.62, -0.42), Vector2(0, -0.42)], Color("2f5f9e"))
			var star: Array = []
			for k in 10:
				var r := 0.15 if k % 2 == 0 else 0.065
				var a := -PI * 0.5 + TAU * k / 10.0
				star.append(Vector2(0.31 + cos(a) * r, -0.21 - sin(a) * r))
			for x: float in [0.012, -0.012]:
				star.push_front(Vector2(0.31, -0.21))
				star.append(star[1])
				_flag_poly(mb, at, star, Color("f2c14e"), x)
				star.pop_front()
				star.pop_back()
		4:
			# Checkers, red and cream.
			for i in 3:
				for j in 2:
					var col := Color("d8433a") if (i + j) % 2 == 0 else Color("f6ecd6")
					var z0 := 0.2 * i
					var y0 := -0.2 * j
					_flag_poly(mb, at, [Vector2(z0, y0), Vector2(z0 + 0.2, y0), Vector2(z0 + 0.2, y0 - 0.2), Vector2(z0, y0 - 0.2)], col)
		_:
			# Patchy's pennant.
			_flag_poly(mb, at, [Vector2(0, 0.12), Vector2(0.55, -0.02), Vector2(0, -0.14)], Palette.COAT)


# --- Figurehead and cannon -------------------------------------------------------------

## The figurehead on the stem (null for none).
static func figurehead_mesh(kind: int) -> ArrayMesh:
	if kind <= 0:
		return null
	var mb := MeshBuilder.new()
	# On the stem, leaning out over the water.
	var base := Transform3D(Basis(Vector3.RIGHT, 0.35).scaled(Vector3.ONE * 1.75), Vector3(0, 0.62, -LENGTH * 0.5 - 0.12))
	match kind:
		1:
			# A seagull, wings swept back.
			mb.ellipsoid(Vector3(0.11, 0.1, 0.2), base, Color("f6f4ee"), 6, 10)
			mb.sphere(0.085, base * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, -0.18)), Color("f6f4ee"), 6, 10)
			mb.cylinder(0.0, 0.03, 0.12, base * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.09, -0.3)), Color("f0a030"), 6)
			for s: float in [1.0, -1.0]:
				mb.box(Vector3(0.24, 0.025, 0.14), base * Transform3D(Basis(Vector3.UP, s * 0.5) * Basis(Vector3.FORWARD, s * 0.35), Vector3(s * 0.18, 0.05, 0.05)), Color("c9d3e6"))
				mb.sphere(0.018, base * Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.13, -0.24)), Color("1d1f26"), 3, 5)
		2:
			# A crab, claws up.
			mb.ellipsoid(Vector3(0.2, 0.1, 0.14), base, Color("d8433a"), 6, 10)
			for s: float in [1.0, -1.0]:
				mb.tube(PackedVector3Array([base * Vector3(s * 0.14, 0.02, -0.06), base * Vector3(s * 0.22, 0.14, -0.14), base * Vector3(s * 0.2, 0.26, -0.18)]), PackedFloat32Array([0.035, 0.03, 0.025]), Color("d8433a"), 6, true)
				mb.ellipsoid(Vector3(0.06, 0.08, 0.05), base * Transform3D(Basis.IDENTITY, Vector3(s * 0.2, 0.31, -0.18)), Color("e85a48"), 5, 8)
				mb.cylinder(0.012, 0.012, 0.1, base * Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.12, -0.1)), Color("d8433a"), 4)
				mb.sphere(0.03, base * Transform3D(Basis.IDENTITY, Vector3(s * 0.05, 0.18, -0.1)), Color("1d1f26"), 3, 5)
		3:
			# A leaping dolphin.
			var leap := base * Transform3D(Basis(Vector3.RIGHT, 0.25), Vector3.ZERO)
			mb.ellipsoid(Vector3(0.1, 0.11, 0.3), leap, Color("7d9cb8"), 6, 12)
			mb.cylinder(0.025, 0.045, 0.14, leap * Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.02, -0.34)), Color("7d9cb8"), 6)
			mb.triangle(leap * Vector3(0, 0.09, -0.02), leap * Vector3(0, 0.24, 0.1), leap * Vector3(0, 0.09, 0.14), Color("5f7d99"), true)
			mb.ellipsoid(Vector3(0.06, 0.07, 0.16), leap * Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.1)), Color("e6eef4"), 5, 8)
			for s: float in [1.0, -1.0]:
				mb.triangle(leap * Vector3(s * 0.02, 0, 0.26), leap * Vector3(s * 0.2, 0.02, 0.4), leap * Vector3(s * 0.04, 0.0, 0.36), Color("5f7d99"), true)
				mb.sphere(0.018, leap * Transform3D(Basis.IDENTITY, Vector3(s * 0.07, 0.04, -0.2)), Color("1d1f26"), 3, 5)
		_:
			# A golden parrot, in Crackers' honor.
			var gold := Color("f2c14e")
			mb.ellipsoid(Vector3(0.11, 0.15, 0.12), base, gold, 6, 10)
			mb.sphere(0.095, base * Transform3D(Basis.IDENTITY, Vector3(0, 0.17, -0.06)), gold, 6, 10)
			mb.cylinder(0.0, 0.04, 0.1, base * Transform3D(Basis(Vector3.RIGHT, -PI * 0.65), Vector3(0, 0.14, -0.16)), Color("3a3f4a"), 6)
			for k in 3:
				mb.box(Vector3(0.025, 0.12, 0.04), base * Transform3D(Basis(Vector3.RIGHT, -0.4 + k * 0.35), Vector3(0, 0.27, -0.04 + k * 0.04)), Color("d8433a"))
			for s: float in [1.0, -1.0]:
				mb.ellipsoid(Vector3(0.03, 0.12, 0.08), base * Transform3D(Basis(Vector3.FORWARD, s * 0.25), Vector3(s * 0.11, 0.0, 0.03)), gold.darkened(0.15), 5, 8)
				mb.sphere(0.02, base * Transform3D(Basis.IDENTITY, Vector3(s * 0.06, 0.2, -0.12)), Color("1d1f26"), 3, 5)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


## The little bronze bow cannon on its carriage.
static func cannon_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var bronze := Color("c2873a")
	var muzzle := MUZZLE
	var breech := muzzle + Vector3(0, -0.04, 0.62)
	var mid := (muzzle + breech) * 0.5
	var along := Basis.looking_at((muzzle - breech).normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
	mb.cylinder(0.075, 0.1, muzzle.distance_to(breech), Transform3D(along, mid), bronze, 10)
	mb.torus(0.07, 0.11, Transform3D(along, muzzle + Vector3(0, 0.0, 0.03)), bronze.lightened(0.15), 12, 6)
	mb.sphere(0.09, Transform3D(Basis.IDENTITY, breech + Vector3(0, 0, 0.02)), bronze.darkened(0.1), 6, 8)
	# Carriage on the foredeck.
	mb.box(Vector3(0.34, 0.12, 0.5), Transform3D(Basis.IDENTITY, mid + Vector3(0, -0.14, 0.05)), Palette.WOOD_DARK)
	for s: float in [1.0, -1.0]:
		for z: float in [-0.14, 0.2]:
			mb.cylinder(0.06, 0.06, 0.04, Transform3D(Basis(Vector3.FORWARD, PI * 0.5), mid + Vector3(s * 0.19, -0.17, z)), Palette.WOOD, 8)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
