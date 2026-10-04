@tool
class_name VillageHouse
extends PropBody
## A house in a pirate fishing village (Castaway Cay's Barnacle Bay): walls
## of painted clapboard, whitewash or stone, a shingled gable roof in a
## bright color, shuttered windows, a door, and optionally a chimney, stilts
## (out over the water), a front porch under an awning and a sign over the
## door. Roofs and awnings are walkable: villages are for climbing.
## Origin: the floor at the middle of the footprint; the front (door) faces
## -Z. Collision: the body (or, with `interior`, its four walls round a
## walkable floor and an open doorway), each roof slope, the porch and its
## awning, the chimney and the stilts. Footsteps report &"wood".

enum Walls { PLANKS, PLASTER, STONE }

## Footprint: width (x) and depth (z).
@export var size := Vector2(6.0, 5.0):
	set(v):
		size = v
		_queue_rebuild()
@export_range(2.0, 8.0, 0.05) var wall_height := 3.2:
	set(v):
		wall_height = v
		_queue_rebuild()
@export var walls := Walls.PLANKS:
	set(v):
		walls = v
		_queue_rebuild()
@export var wall_color := Color("5fa8d3"):
	set(v):
		wall_color = v
		_queue_rebuild()
## Corner posts, beams, door and window frames.
@export var trim_color := Color("f4ead6"):
	set(v):
		trim_color = v
		_queue_rebuild()
@export var roof_color := Color("d9483b"):
	set(v):
		roof_color = v
		_queue_rebuild()
## Shutters and the door.
@export var accent_color := Color("2f7d5b"):
	set(v):
		accent_color = v
		_queue_rebuild()
## Roof ridge height above the walls.
@export_range(0.5, 5.0, 0.05) var roof_pitch := 2.0:
	set(v):
		roof_pitch = v
		_queue_rebuild()
## Ridge running front to back (the gable faces the street).
@export var gable_front := false:
	set(v):
		gable_front = v
		_queue_rebuild()
@export_range(0.0, 1.2, 0.05) var overhang := 0.45:
	set(v):
		overhang = v
		_queue_rebuild()
## Door position along the front wall (x).
@export var door_offset := 0.0:
	set(v):
		door_offset = v
		_queue_rebuild()
@export var windows := true:
	set(v):
		windows = v
		_queue_rebuild()
@export var chimney := false:
	set(v):
		chimney = v
		_queue_rebuild()
## Posts down to this depth below the floor (0: on a stone plinth).
@export_range(0.0, 12.0, 0.05) var stilts := 0.0:
	set(v):
		stilts = v
		_queue_rebuild()
## A front deck this deep under an awning (0: none).
@export_range(0.0, 5.0, 0.05) var porch := 0.0:
	set(v):
		porch = v
		_queue_rebuild()
## Walk-in: an open doorway into a room with a floor (no closed body).
@export var interior := false:
	set(v):
		interior = v
		_queue_rebuild()
## Painted on a board over the door ("" = none).
@export var sign_text := "":
	set(v):
		sign_text = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const WALL := 0.22
const DOOR := Vector2(1.2, 2.2)
const SHINGLE := 0.42


func _surface() -> StringName:
	return &"wood"


## The doorway's center at the floor, outside the front wall (local).
func door_point() -> Vector3:
	return Vector3(door_offset, 0, -size.y * 0.5 - 0.4)


## Roof ridge height (local).
func ridge_height() -> float:
	return wall_height + roof_pitch


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed, 211)
	var w := size.x
	var d := size.y
	var h := wall_height
	_base(parts, rng)
	_walls(parts, rng)
	_trim(parts)
	if windows:
		_windows(parts, rng)
	_door(parts, rng)
	_roof(parts, rng)
	if chimney:
		_chimney(parts, rng)
	if porch > 0.0:
		_porch(parts, rng)
	if sign_text != "":
		_sign(parts)
	add_mesh(parts.build(), "House")
	# Collision.
	if interior:
		var t := WALL
		add_shape(PropKit.box_shape(Vector3(w, h, t)), Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, d * 0.5 - t * 0.5)), "WallBack")
		add_shape(PropKit.box_shape(Vector3(t, h, d)), Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0)), "WallLeft")
		add_shape(PropKit.box_shape(Vector3(t, h, d)), Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - t * 0.5, h * 0.5, 0)), "WallRight")
		var left := (door_offset - DOOR.x * 0.5) + w * 0.5
		var right := w * 0.5 - (door_offset + DOOR.x * 0.5)
		add_shape(PropKit.box_shape(Vector3(left, h, t)), Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 + left * 0.5, h * 0.5, -d * 0.5 + t * 0.5)), "WallFrontL")
		add_shape(PropKit.box_shape(Vector3(right, h, t)), Transform3D(Basis.IDENTITY, Vector3(w * 0.5 - right * 0.5, h * 0.5, -d * 0.5 + t * 0.5)), "WallFrontR")
		add_shape(PropKit.box_shape(Vector3(DOOR.x, h - DOOR.y, t)), Transform3D(Basis.IDENTITY, Vector3(door_offset, (h + DOOR.y) * 0.5, -d * 0.5 + t * 0.5)), "Lintel")
		add_shape(PropKit.box_shape(Vector3(w, 0.3, d)), Transform3D(Basis.IDENTITY, Vector3(0, -0.15, 0)), "Floor")
	else:
		add_shape(PropKit.box_shape(Vector3(w, h, d)), Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), "Body")
	_roof_shapes()
	if stilts > 0.0:
		for p in _stilt_points():
			add_shape(PropKit.cylinder_shape(0.16, stilts), Transform3D(Basis.IDENTITY, Vector3(p.x, -stilts * 0.5, p.y)), "Stilt")
		add_shape(PropKit.box_shape(Vector3(w + 0.6, 0.2, d + 0.6)), Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)), "Platform")
	if porch > 0.0:
		add_shape(PropKit.box_shape(Vector3(w, 0.2, porch)), Transform3D(Basis.IDENTITY, Vector3(0, -0.1, -d * 0.5 - porch * 0.5)), "Porch")
		var aw := _awning()
		add_shape(PropKit.box_shape(Vector3(w + 0.3, 0.16, aw.length)), Transform3D(aw.basis, aw.center), "Awning")
	if chimney:
		var c := _chimney_spot()
		add_shape(PropKit.box_shape(Vector3(0.8, 2.0, 0.8)), Transform3D(Basis.IDENTITY, Vector3(c.x, ridge_height() + 0.1, c.y)), "Chimney")


# --- Mesh -------------------------------------------------------------------------

func _base(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var w := size.x
	var d := size.y
	if stilts > 0.0:
		# A plank platform on posts, wet and dark near the water.
		parts.matte.chamfer_box(Vector3(w + 0.6, 0.2, d + 0.6), 0.03, Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)), PropPalette.PLANK_DARK)
		for p in _stilt_points():
			var pts := PackedVector3Array([Vector3(p.x, -stilts, p.y), Vector3(p.x, -stilts * 0.55, p.y), Vector3(p.x, -0.2, p.y)])
			parts.matte.banded_tube(pts, PackedFloat32Array([0.16, 0.16, 0.15]), PackedColorArray([PropPalette.WOOD_DEEP, PropPalette.WOOD_FRAME]), 8)
		for sx: float in [-1.0, 1.0]:
			parts.matte.beam(Vector3(sx * w * 0.5, -0.3, -d * 0.5), Vector3(sx * w * 0.5, -minf(stilts, 2.5) + 0.3, d * 0.5), 0.1, 0.12, 0.02, PropPalette.WOOD_FRAME)
	else:
		# A low plinth of fitted stones.
		var stone := Color("b7ad9c")
		parts.matte.chamfer_box(Vector3(w + 0.3, 0.4, d + 0.3), 0.06, Transform3D(Basis.IDENTITY, Vector3(0, -0.15, 0)), stone)
		for k in int((w + d) * 1.2):
			var along := rng.randf()
			var on_x := rng.randf() < w / (w + d)
			var s := rng.randf_range(0.3, 0.6)
			var p := Vector3((along - 0.5) * w, -0.05, (1 if rng.randf() < 0.5 else -1) * (d * 0.5 + 0.12)) if on_x else Vector3((1 if rng.randf() < 0.5 else -1) * (w * 0.5 + 0.12), -0.05, (along - 0.5) * d)
			parts.matte.chamfer_box(Vector3(s, 0.22, s * 0.6), 0.05, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.2, 0.2)), p), PropKit.jitter(stone, rng, 0.08))


func _walls(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var w := size.x
	var d := size.y
	var h := wall_height
	var t := WALL
	# The wall slabs.
	var slabs := [[Vector3(0, h * 0.5, d * 0.5 - t * 0.5), Vector3(w, h, t)], [Vector3(-w * 0.5 + t * 0.5, h * 0.5, 0), Vector3(t, h, d)],
		[Vector3(w * 0.5 - t * 0.5, h * 0.5, 0), Vector3(t, h, d)]]
	var dl := door_offset - DOOR.x * 0.5
	var dr := door_offset + DOOR.x * 0.5
	slabs.append([Vector3((-w * 0.5 + dl) * 0.5, h * 0.5, -d * 0.5 + t * 0.5), Vector3(dl + w * 0.5, h, t)])
	slabs.append([Vector3((w * 0.5 + dr) * 0.5, h * 0.5, -d * 0.5 + t * 0.5), Vector3(w * 0.5 - dr, h, t)])
	slabs.append([Vector3(door_offset, (h + DOOR.y) * 0.5, -d * 0.5 + t * 0.5), Vector3(DOOR.x, h - DOOR.y, t)])
	var body := wall_color if walls != Walls.PLANKS else wall_color.darkened(0.25)
	for s: Array in slabs:
		parts.matte.box(s[1], Transform3D(Basis.IDENTITY, s[0]), body)
	if interior:
		parts.matte.chamfer_box(Vector3(w - t * 2.0, 0.06, d - t * 2.0), 0.01, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), PropPalette.PLANK)
	match walls:
		Walls.PLANKS:
			# Clapboards: overlapping painted boards on every face.
			var rows := int(ceil(h / 0.34))
			for face in 4:
				var length := w if face < 2 else d
				for r in rows:
					var y := (r + 0.5) * h / rows
					var c := PropKit.jitter(wall_color, rng, 0.05)
					var segs := [[-length * 0.5, length * 0.5]]
					if face == 0 and y < DOOR.y:
						segs = [[-length * 0.5, dl], [dr, length * 0.5]]
					for sg: Array in segs:
						var a: float = sg[0]
						var b: float = sg[1]
						if b - a < 0.05:
							continue
						var mid := (a + b) * 0.5
						var board := b - a + (0.06 if face >= 2 else 0.0)
						var xf := _face_xform(face, mid, y, 0.03)
						parts.matte.chamfer_box(Vector3(board, h / rows * 1.05, 0.06), 0.015, xf * Transform3D(Basis(Vector3.RIGHT, -0.06), Vector3.ZERO), c)
		Walls.STONE:
			# Stone up to the sills, whitewash above.
			var sill := minf(1.1, h * 0.4)
			for face in 4:
				var length := w if face < 2 else d
				var row := 0
				while row * 0.34 < sill:
					var x := -length * 0.5 + (0.0 if row % 2 == 0 else -0.2)
					while x < length * 0.5:
						var sw := rng.randf_range(0.35, 0.65)
						var cx := clampf(x + sw * 0.5, -length * 0.5 + sw * 0.3, length * 0.5 - sw * 0.3)
						if not (face == 0 and cx > dl - 0.1 and cx < dr + 0.1):
							parts.matte.chamfer_box(Vector3(minf(sw - 0.04, length), 0.3, 0.1), 0.04, _face_xform(face, cx, 0.17 + row * 0.34, 0.05), PropKit.jitter(Color("a79e8d"), rng, 0.09))
						x += sw
					row += 1
		_:
			pass


## Where `x` along face `face` at height `y` sits, pushed `out` m off the
## wall (0 front, 1 back, 2 left, 3 right); the transform faces outward.
func _face_xform(face: int, x: float, y: float, out: float) -> Transform3D:
	var w := size.x
	var d := size.y
	match face:
		0:
			return Transform3D(Basis.IDENTITY, Vector3(x, y, -d * 0.5 - out))
		1:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(-x, y, d * 0.5 + out))
		2:
			return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-w * 0.5 - out, y, -x))
		_:
			return Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(w * 0.5 + out, y, x))


func _trim(parts: PropParts) -> void:
	var w := size.x
	var d := size.y
	var h := wall_height
	var trim := trim_color
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.matte.chamfer_box(Vector3(0.24, h + 0.05, 0.24), 0.04, Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 + 0.02), h * 0.5, sz * (d * 0.5 + 0.02))), trim)
	for face in 4:
		var length := w if face < 2 else d
		parts.matte.chamfer_box(Vector3(length + 0.1, 0.2, 0.12), 0.03, _face_xform(face, 0, h - 0.1, 0.08), trim)
		if walls == Walls.PLASTER:
			parts.matte.chamfer_box(Vector3(length + 0.1, 0.16, 0.1), 0.03, _face_xform(face, 0, 0.12, 0.06), trim)
			# Half-timbering: a brace either side.
			for side: float in [-1.0, 1.0]:
				var x0 := side * length * 0.5
				var x1 := side * length * 0.22
				var a := _face_xform(face, x0, 0.25, 0.06).origin
				var b := _face_xform(face, x1, h - 0.25, 0.06).origin
				if face == 0 and absf(x1 - door_offset) < DOOR.x:
					continue
				parts.matte.beam(a, b, 0.14, 0.08, 0.02, trim, _face_xform(face, 0, 0, 0).basis.z * -1.0)


func _windows(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var w := size.x
	var d := size.y
	var h := wall_height
	var y := minf(h * 0.58, h - 0.9)
	var spots: Array = []
	for x: float in [-w * 0.3, w * 0.3]:
		if absf(x - door_offset) > DOOR.x * 0.5 + 0.8 and absf(x) < w * 0.5 - 0.6:
			spots.append([0, x])
	spots.append([1, 0.0])
	for face in [2, 3]:
		if d > 4.2:
			spots.append([face, -d * 0.2])
			spots.append([face, d * 0.2])
		else:
			spots.append([face, 0.0])
	var glass := Color("2e4f6e")
	var porthole := walls == Walls.PLASTER
	for s: Array in spots:
		var xf := _face_xform(s[0], s[1], y, 0.1)
		if porthole:
			parts.matte.torus(0.32, 0.42, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO), trim_color, 14, 5)
			parts.glossy.cylinder(0.34, 0.34, 0.04, xf * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.02)), glass, 14)
			parts.matte.box(Vector3(0.06, 0.64, 0.03), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.01)), trim_color)
			parts.matte.box(Vector3(0.64, 0.06, 0.03), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.01)), trim_color)
			continue
		parts.glossy.box(Vector3(0.8, 0.9, 0.04), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.03)), glass)
		for k: float in [-0.43, 0.43]:
			parts.matte.chamfer_box(Vector3(0.1, 1.02, 0.1), 0.02, xf * Transform3D(Basis.IDENTITY, Vector3(k, 0, 0)), trim_color)
			parts.matte.chamfer_box(Vector3(0.96, 0.1, 0.1), 0.02, xf * Transform3D(Basis.IDENTITY, Vector3(0, k * 1.1, 0)), trim_color)
		parts.matte.box(Vector3(0.05, 0.9, 0.05), xf, trim_color)
		parts.matte.chamfer_box(Vector3(1.1, 0.1, 0.24), 0.02, xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.52, -0.08)), trim_color.darkened(0.1))
		# Shutters swung open, each a little askew.
		for side: float in [-1.0, 1.0]:
			var open := rng.randf_range(0.15, 0.5)
			var hinge := Vector3(side * 0.5, 0, -0.02)
			var sh := Transform3D(Basis(Vector3.UP, side * open), hinge) * Transform3D(Basis.IDENTITY, Vector3(side * 0.24, 0, 0))
			parts.matte.chamfer_box(Vector3(0.46, 0.92, 0.05), 0.015, xf * sh, PropKit.jitter(accent_color, rng, 0.04))
			for slat in 4:
				parts.matte.box(Vector3(0.36, 0.03, 0.02), xf * sh * Transform3D(Basis.IDENTITY, Vector3(0, -0.3 + slat * 0.2, -0.03)), accent_color.darkened(0.2))
		# A flower box under some sills.
		if rng.randf() < 0.5:
			parts.matte.chamfer_box(Vector3(0.9, 0.22, 0.24), 0.03, xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.68, -0.14)), PropPalette.PLANK_DARK)
			for k in 4:
				var col: Color = [PropPalette.FLOWER_RED, PropPalette.FLOWER_YELLOW, PropPalette.FLOWER_PINK, PropPalette.FLOWER_WHITE][rng.randi() % 4]
				parts.soft.sphere(0.09, xf * Transform3D(Basis.IDENTITY, Vector3(-0.3 + k * 0.2, -0.52, -0.14)), col, 3, 6)
				parts.soft.sphere(0.1, xf * Transform3D(Basis.IDENTITY, Vector3(-0.3 + k * 0.2 + 0.1, -0.56, -0.18)), PropPalette.BUSH, 3, 6)


func _door(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var d := size.y
	var z := -d * 0.5
	var x := door_offset
	var frame := trim_color
	parts.matte.chamfer_box(Vector3(0.16, DOOR.y + 0.1, 0.3), 0.03, Transform3D(Basis.IDENTITY, Vector3(x - DOOR.x * 0.5 - 0.06, DOOR.y * 0.5, z - 0.02)), frame)
	parts.matte.chamfer_box(Vector3(0.16, DOOR.y + 0.1, 0.3), 0.03, Transform3D(Basis.IDENTITY, Vector3(x + DOOR.x * 0.5 + 0.06, DOOR.y * 0.5, z - 0.02)), frame)
	parts.matte.chamfer_box(Vector3(DOOR.x + 0.5, 0.22, 0.34), 0.03, Transform3D(Basis.IDENTITY, Vector3(x, DOOR.y + 0.08, z - 0.02)), frame)
	parts.matte.chamfer_box(Vector3(DOOR.x + 0.3, 0.12, 0.6), 0.03, Transform3D(Basis.IDENTITY, Vector3(x, 0.04, z - 0.25)), Color("9c9282"))
	if interior:
		return
	# A plank door with iron straps and a ring handle, set back in the frame.
	var boards := 4
	for k in boards:
		var bx := x - DOOR.x * 0.5 + (k + 0.5) * DOOR.x / boards
		parts.matte.chamfer_box(Vector3(DOOR.x / boards - 0.02, DOOR.y - 0.02, 0.08), 0.015, Transform3D(Basis.IDENTITY, Vector3(bx, DOOR.y * 0.5, z + 0.06)), PropKit.jitter(accent_color.darkened(0.15), rng, 0.05))
	for y: float in [0.45, DOOR.y - 0.45]:
		parts.metal.box(Vector3(DOOR.x - 0.1, 0.07, 0.03), Transform3D(Basis.IDENTITY, Vector3(x, y, z + 0.01)), PropPalette.IRON)
	parts.metal.torus(0.05, 0.08, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(x + DOOR.x * 0.3, DOOR.y * 0.48, z)), PropPalette.IRON_LIGHT, 10, 4)


## The roof: two shingled slopes, a ridge beam, gable ends.
func _roof(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var h := wall_height
	# Work in the roof's frame: x along the ridge, z across it.
	var run := (size.y if gable_front else size.x) + overhang * 2.0
	var span := (size.x if gable_front else size.y) * 0.5 + overhang
	var rf := Transform3D(Basis(Vector3.UP, PI * 0.5) if gable_front else Basis.IDENTITY, Vector3.ZERO)
	var drop := overhang * roof_pitch / ((size.x if gable_front else size.y) * 0.5)
	var eave_y := h - drop
	var slope_len := Vector2(span, roof_pitch + drop).length()
	var rows := maxi(2, int(ceil(slope_len / SHINGLE)))
	for side: float in [-1.0, 1.0]:
		var eave := Vector3(0, eave_y, side * span)
		var ridge := Vector3(0, h + roof_pitch, 0)
		var up := (ridge - eave).normalized()
		var nrm := Vector3(0, span, side * (roof_pitch + drop)).normalized()
		var b := Basis.looking_at(-up, nrm)
		for r in rows:
			var t := (r + 0.5) / rows
			var p := eave.lerp(ridge, t) + nrm * 0.08
			var segs := maxi(1, int(run / 1.6))
			for s in segs:
				var x := -run * 0.5 + (s + 0.5) * run / segs + (0.0 if r % 2 == 0 else 0.2)
				var c := PropKit.jitter(roof_color, rng, 0.06).darkened(0.08 * (r % 2))
				var piece := run / segs + 0.04
				var xf := rf * Transform3D(b * Basis(Vector3.RIGHT, 0.08), p + Vector3(clampf(x, -run * 0.5 + piece * 0.5, run * 0.5 - piece * 0.5), 0, 0))
				parts.matte.chamfer_box(Vector3(piece, 0.09, slope_len / rows * 1.25), 0.025, xf, c)
		# The slope's underside.
		var mid := eave.lerp(ridge, 0.5)
		parts.matte.box(Vector3(run, 0.08, slope_len), rf * Transform3D(b, mid), roof_color.darkened(0.45))
	parts.matte.chamfer_box(Vector3(run + 0.1, 0.22, 0.26), 0.05, rf * Transform3D(Basis.IDENTITY, Vector3(0, h + roof_pitch + 0.08, 0)), trim_color.darkened(0.1))
	# Gable ends, filled with the wall's color.
	var half := (size.x if gable_front else size.y) * 0.5
	for end: float in [-1.0, 1.0]:
		var x := end * ((size.y if gable_front else size.x) * 0.5)
		var a := rf * Vector3(x, h, -half)
		var bb := rf * Vector3(x, h, half)
		var c := rf * Vector3(x, h + roof_pitch, 0)
		var n := rf.basis * Vector3(end, 0, 0)
		parts.matte.flat_tri(a, bb, c, wall_color, n)
		parts.matte.flat_tri(a + n * -0.2, c + n * -0.2, bb + n * -0.2, wall_color.darkened(0.3), -n)
		# A little round vent in the gable.
		parts.matte.torus(0.14, 0.22, Transform3D(Basis.looking_at(n) * Basis(Vector3.RIGHT, PI * 0.5), rf * Vector3(x + end * 0.02, h + roof_pitch * 0.42, 0)), trim_color, 10, 4)


## Collision boxes along each roof slope.
func _roof_shapes() -> void:
	var h := wall_height
	var run := (size.y if gable_front else size.x) + overhang * 2.0
	var span := (size.x if gable_front else size.y) * 0.5 + overhang
	var drop := overhang * roof_pitch / ((size.x if gable_front else size.y) * 0.5)
	var rf := Basis(Vector3.UP, PI * 0.5) if gable_front else Basis.IDENTITY
	for side: float in [-1.0, 1.0]:
		var eave := Vector3(0, h - drop, side * span)
		var ridge := Vector3(0, h + roof_pitch, 0)
		var up := (ridge - eave).normalized()
		var nrm := Vector3(0, span, side * (roof_pitch + drop)).normalized()
		var b := Basis.looking_at(-up, nrm)
		var length := eave.distance_to(ridge)
		add_shape(PropKit.box_shape(Vector3(run, 0.2, length)), Transform3D(rf * b, rf * ((eave + ridge) * 0.5 + nrm * 0.05)), "Roof")


func _chimney_spot() -> Vector2:
	var x := (size.x * 0.28) if not gable_front else 0.0
	var z := 0.0 if not gable_front else size.y * 0.25
	return Vector2(x, z)


func _chimney(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var c := _chimney_spot()
	var top := ridge_height() + 1.0
	var base := wall_height
	var y := base
	var stone := Color("a39a8a")
	while y < top:
		for k in 2:
			var off := Vector3((k - 0.5) * 0.36 + rng.randf_range(-0.03, 0.03), 0, 0)
			parts.matte.chamfer_box(Vector3(0.38, 0.26, 0.76), 0.04, Transform3D(Basis(Vector3.UP, 0.0 if int(y * 4) % 2 == 0 else PI * 0.5), Vector3(c.x, y + 0.13, c.y) + off), PropKit.jitter(stone, rng, 0.08))
		y += 0.27
	parts.matte.chamfer_box(Vector3(0.92, 0.14, 0.92), 0.03, Transform3D(Basis.IDENTITY, Vector3(c.x, top + 0.05, c.y)), stone.darkened(0.15))
	parts.matte.box(Vector3(0.5, 0.05, 0.5), Transform3D(Basis.IDENTITY, Vector3(c.x, top + 0.1, c.y)), Color("2b2321"))


func _porch(parts: PropParts, rng: RandomNumberGenerator) -> void:
	var w := size.x
	var d := size.y
	var z0 := -d * 0.5
	var count := maxi(int(porch / 0.3), 1)
	for k in count:
		var z := z0 - (k + 0.5) * porch / count
		parts.matte.chamfer_box(Vector3(w, 0.1, porch / count - 0.03), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, -0.05, z)), PropKit.jitter(PropPalette.PLANK, rng, 0.05))
	var aw := _awning()
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * (w * 0.5 - 0.15), 0, z0 - porch + 0.15)
		parts.matte.chamfer_box(Vector3(0.16, aw.edge_y, 0.16), 0.03, Transform3D(Basis.IDENTITY, p + Vector3.UP * aw.edge_y * 0.5), trim_color)
		if stilts > 0.0:
			parts.matte.cylinder(0.13, 0.13, stilts, Transform3D(Basis.IDENTITY, p + Vector3.DOWN * stilts * 0.5), PropPalette.WOOD_DEEP, 8)
	# A striped canvas awning.
	var stripes := maxi(4, int(w / 0.7))
	for k in stripes:
		var x := -w * 0.5 - 0.15 + (k + 0.5) * (w + 0.3) / stripes
		var col := accent_color if k % 2 == 0 else Color("f6efe0")
		parts.matte.box(Vector3((w + 0.3) / stripes, 0.06, aw.length), Transform3D(aw.basis, aw.center + Vector3(x, 0.04, 0)), col)
	parts.matte.beam(Vector3(-w * 0.5 - 0.15, aw.edge_y, z0 - porch + 0.15), Vector3(w * 0.5 + 0.15, aw.edge_y, z0 - porch + 0.15), 0.14, 0.14, 0.03, trim_color)


## The awning over the porch: from under the eaves down to the posts.
func _awning() -> Dictionary:
	var z0 := -size.y * 0.5
	var top := Vector3(0, wall_height - 0.35, z0)
	var edge_y := maxf(wall_height - 1.1, 2.3)
	var edge := Vector3(0, edge_y, z0 - porch - 0.2)
	var dir := (edge - top).normalized()
	var b := Basis.looking_at(dir, Vector3.UP.slide(dir).normalized())
	return {"center": (top + edge) * 0.5, "basis": b, "length": top.distance_to(edge), "edge_y": edge_y}


func _sign(parts: PropParts) -> void:
	var z := -size.y * 0.5 - (porch if porch > 0.0 else 0.0) - 0.2
	var y: float = DOOR.y + 0.7 if porch <= 0.0 else float(_awning()["edge_y"]) + 0.55
	var width := clampf(sign_text.length() * 0.22 + 0.6, 1.6, size.x - 0.4)
	parts.matte.chamfer_box(Vector3(width, 0.62, 0.1), 0.04, Transform3D(Basis.IDENTITY, Vector3(door_offset, y, z)), PropPalette.PLANK_DARK)
	parts.matte.chamfer_box(Vector3(width + 0.14, 0.74, 0.06), 0.03, Transform3D(Basis.IDENTITY, Vector3(door_offset, y, z + 0.04)), trim_color.darkened(0.2))
	var label := Label3D.new()
	label.text = sign_text
	label.font_size = 64
	label.pixel_size = 0.0055
	label.outline_size = 10
	label.modulate = Color("fbe9b7")
	label.outline_modulate = Color("3b2414")
	label.position = Vector3(door_offset, y, z - 0.07)
	label.rotation.y = PI
	label.double_sided = false
	PropKit.add_generated(self, label, "Sign")


func _stilt_points() -> Array[Vector2]:
	var out: Array[Vector2] = []
	var nx := maxi(2, int(size.x / 2.2) + 1)
	var nz := maxi(2, int(size.y / 2.2) + 1)
	for i in nx:
		for k in nz:
			if i == 0 or k == 0 or i == nx - 1 or k == nz - 1:
				out.append(Vector2(-size.x * 0.5 - 0.1 + (size.x + 0.2) * i / (nx - 1), -size.y * 0.5 - 0.1 + (size.y + 0.2) * k / (nz - 1)))
	return out
