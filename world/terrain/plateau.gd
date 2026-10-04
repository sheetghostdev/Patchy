@tool
class_name Plateau
extends StaticBody3D
## Chunky island terrain (spec §6, §149): an outline polygon extruded into a
## terrace with a soft beveled lip, rocky noise-displaced cliff sides and a
## flat walkable top, or (shore mode) a sloping beach that runs into the
## water. Collision follows the clean (undisplaced, unbeveled) shape so
## ledge grabs and wall kicks stay reliable on rocky-looking cliffs.

@export var outline: PackedVector2Array = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)]):
	set(v):
		outline = v
		_queue()
## Top surface height (local y).
@export var height := 4.0:
	set(v):
		height = v
		_queue()
## How far the sides extend below the top.
@export var depth := 8.0:
	set(v):
		depth = v
		_queue()
## Catmull-Rom subdivisions per outline segment (organic curves).
@export_range(0, 8) var smoothing := 3:
	set(v):
		smoothing = v
		_queue()
@export_enum("grass", "sand", "cliff", "cliff_warm", "cliff_grey", "rock", "dirt", "stone", "wood") var surface: String = "cliff":
	set(v):
		surface = v
		_queue()
@export_range(0.0, 2.0, 0.01) var bevel := 0.35:
	set(v):
		bevel = v
		_queue()
## Rocky displacement of cliff sides (m).
@export_range(0.0, 1.0, 0.01) var side_noise := 0.3:
	set(v):
		side_noise = v
		_queue()
## Sides become a beach slope instead of a cliff.
@export var shore := false:
	set(v):
		shore = v
		_queue()
@export_range(0.5, 40.0, 0.1) var shore_width := 8.0:
	set(v):
		shore_width = v
		_queue()
@export_range(0.1, 20.0, 0.1) var shore_drop := 3.0:
	set(v):
		shore_drop = v
		_queue()
@export var noise_seed := 1:
	set(v):
		noise_seed = v
		_queue()
@export var slide_surface := false
@export var no_ledge_grab := false

const FOOTSTEP := {"grass": &"grass", "cliff": &"grass", "cliff_warm": &"grass", "cliff_grey": &"grass", "dirt": &"grass", "sand": &"sand", "rock": &"stone", "stone": &"stone", "wood": &"wood"}

var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _pending := false
var _noise := FastNoiseLite.new()


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_notify_transform(true)
	if slide_surface:
		add_to_group(&"slide_surface")
	if no_ledge_grab:
		add_to_group(&"no_ledge_grab")
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _mesh != null:
		_mesh.set_instance_shader_parameter(&"top_y", global_position.y + height)


func _queue() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		_rebuild.call_deferred()


## Outline after orientation fix and smoothing (counter-clockwise in XZ).
func get_ring() -> PackedVector2Array:
	var pts := outline.duplicate()
	if pts.size() < 3:
		return pts
	if Geometry2D.is_polygon_clockwise(pts):
		pts.reverse()
	if smoothing <= 0:
		return pts
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p0 := pts[(i - 1 + n) % n]
		var p1 := pts[i]
		var p2 := pts[(i + 1) % n]
		var p3 := pts[(i + 2) % n]
		for s in smoothing + 1:
			var t := float(s) / (smoothing + 1)
			out.append(_catmull(p0, p1, p2, p3, t))
	return out


static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


## Outward unit normals per ring vertex (miter-averaged).
static func _normals(ring: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := ring.size()
	for i in n:
		var a := ring[(i - 1 + n) % n]
		var b := ring[i]
		var c := ring[(i + 1) % n]
		var e1 := (b - a).normalized()
		var e2 := (c - b).normalized()
		# CCW ring in XZ: outward is the edge direction rotated -90° (x, y) -> (y, -x).
		var n1 := Vector2(e1.y, -e1.x)
		var n2 := Vector2(e2.y, -e2.x)
		var m := (n1 + n2)
		out.append(m.normalized() if m.length() > 0.001 else n1)
	return out


func _rebuild() -> void:
	_pending = false
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		_mesh.name = "Mesh"
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
	if _col == null:
		_col = CollisionShape3D.new()
		_col.name = "Collision"
		add_child(_col, false, Node.INTERNAL_MODE_FRONT)
	set_meta(&"surface", FOOTSTEP.get(surface, &"grass"))
	var ring := get_ring()
	if ring.size() < 3:
		return
	_noise.seed = noise_seed
	_noise.frequency = 0.35
	_noise.fractal_octaves = 2
	var normals := _normals(ring)
	var visual := SurfaceTool.new()
	var collision := PackedVector3Array()
	visual.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Top cap (inset by the bevel) - flat and walkable.
	var inset := PackedVector2Array()
	for i in ring.size():
		inset.append(ring[i] - normals[i] * bevel)
	var tris := Geometry2D.triangulate_polygon(inset)
	if tris.is_empty():
		tris = Geometry2D.triangulate_polygon(ring)
		inset = ring
	for k in range(0, tris.size(), 3):
		var a := _v3(inset[tris[k]], height)
		var b := _v3(inset[tris[k + 1]], height)
		var c := _v3(inset[tris[k + 2]], height)
		_add_tri(visual, a, c, b, Vector3.UP, true)
		if shore:
			collision.append_array([a, c, b])

	# Rings going down the side: bevel lip, then cliff or shore slope.
	var levels: Array[Dictionary] = []
	levels.append({"y": height, "out": -bevel, "noise": 0.0, "smooth": true})
	levels.append({"y": height - bevel * 0.7, "out": -bevel * 0.15, "noise": 0.0, "smooth": true})
	if shore:
		var steps := 6
		for s in steps:
			var t := float(s + 1) / steps
			levels.append({"y": height - bevel * 0.7 - shore_drop * t, "out": shore_width * pow(t, 0.8), "noise": side_noise * 0.3, "smooth": true})
		levels.append({"y": height - depth, "out": shore_width + 0.5, "noise": 0.0, "smooth": true})
	else:
		var cliff_h := depth - bevel
		var steps := maxi(2, int(ceil(cliff_h / 1.1)))
		for s in steps:
			var t := float(s + 1) / steps
			levels.append({"y": height - bevel * 0.7 - cliff_h * t, "out": 0.0, "noise": side_noise, "smooth": false})
	var rows: Array[PackedVector3Array] = []
	var clean_rows: Array[PackedVector3Array] = []
	for lv in levels:
		var row := PackedVector3Array()
		var clean := PackedVector3Array()
		for i in ring.size():
			var p := ring[i] + normals[i] * float(lv.out)
			var y: float = lv.y
			var amp: float = lv.noise
			var d := 0.0
			if amp > 0.0:
				d = _noise.get_noise_3d(p.x, y * 1.3, p.y) * amp * 2.0
			row.append(_v3(p + normals[i] * d, y))
			clean.append(_v3(p, y))
		rows.append(row)
		clean_rows.append(clean)
	for r in rows.size() - 1:
		for i in ring.size():
			var j := (i + 1) % ring.size()
			var a := rows[r][i]
			var b := rows[r][j]
			var c := rows[r + 1][j]
			var d := rows[r + 1][i]
			var outward := _v3(normals[i] + normals[j], 0.0).normalized()
			var smooth: bool = levels[r + 1].smooth
			_add_tri(visual, a, b, c, outward, smooth)
			_add_tri(visual, a, c, d, outward, smooth)
			if shore:
				var ca := clean_rows[r][i]
				var cb := clean_rows[r][j]
				var cc := clean_rows[r + 1][j]
				var cd := clean_rows[r + 1][i]
				collision.append_array(_oriented(ca, cb, cc, outward))
				collision.append_array(_oriented(ca, cc, cd, outward))
	if not shore:
		_cliff_collision(ring, normals, collision)
	visual.generate_normals()
	var mesh := visual.commit()
	_mesh.mesh = mesh
	_mesh.material_override = MaterialLibrary.terrain(StringName(surface))
	_mesh.set_instance_shader_parameter(&"top_y", global_position.y + height)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(collision)
	shape.backface_collision = true
	_col.shape = shape


## Cliffs collide as a clean prism: a flat top right out to the outline and
## vertical sides. The sharp lip makes ledge grabs, edge landings and wall
## kicks behave exactly like the greybox blocks; the visual bevel only
## rounds the look (feet may hover a hand's width over it at the very edge).
func _cliff_collision(ring: PackedVector2Array, normals: PackedVector2Array, out: PackedVector3Array) -> void:
	var tris := Geometry2D.triangulate_polygon(ring)
	for k in range(0, tris.size(), 3):
		out.append_array([_v3(ring[tris[k]], height), _v3(ring[tris[k + 2]], height), _v3(ring[tris[k + 1]], height)])
	var bottom := height - depth
	for i in ring.size():
		var j := (i + 1) % ring.size()
		var outward := _v3(normals[i] + normals[j], 0.0).normalized()
		var a := _v3(ring[i], height)
		var b := _v3(ring[j], height)
		var c := _v3(ring[j], bottom)
		var d := _v3(ring[i], bottom)
		out.append_array(_oriented(a, b, c, outward))
		out.append_array(_oriented(a, c, d, outward))


static func _v3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


## Adds a triangle facing `outward` (Godot front faces are clockwise).
static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, smooth: bool) -> void:
	var tri := _oriented(a, b, c, outward)
	st.set_smooth_group(0 if smooth else 0xFFFFFFFF)
	for v in tri:
		st.add_vertex(v)


static func _oriented(a: Vector3, b: Vector3, c: Vector3, outward: Vector3) -> PackedVector3Array:
	var cw := (c - a).cross(b - a)
	if cw.dot(outward) >= 0.0:
		return PackedVector3Array([a, b, c])
	return PackedVector3Array([a, c, b])
