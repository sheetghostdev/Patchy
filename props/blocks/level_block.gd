@tool
class_name LevelBlock
extends StaticBody3D
## Stylized greybox building block (boxes, ramps, stairs, pillars) with
## matching collision, footstep surface metadata and an optional dimension
## label for the movement lab (spec §46). Rebuilds live in the editor.
##
## Origin is bottom-center: the block spans y = 0..size.y. Ramps and stairs
## rise toward -Z (the node's forward).

enum Shape { BOX, RAMP, STAIRS, CYLINDER }

const FOOTSTEP := {
	"grass": &"grass", "cliff": &"grass", "dirt": &"grass", "sand": &"sand",
	"wood": &"wood", "rock": &"stone", "stone": &"stone", "metal": &"stone",
	"wood_dark": &"wood", "thatch": &"wood", "roof_red": &"wood", "roof_blue": &"wood",
}

@export var shape := Shape.BOX:
	set(v):
		shape = v
		_queue_rebuild()
@export var size := Vector3(4.0, 1.0, 4.0):
	set(v):
		size = v.max(Vector3.ONE * 0.05)
		_queue_rebuild()
@export_enum("grass", "sand", "rock", "cliff", "wood", "wood_dark", "thatch", "roof_red", "roof_blue", "stone", "dirt", "metal", "lab", "lab_orange", "lab_teal", "lab_purple", "lab_pink", "lab_blue") var surface: String = "lab":
	set(v):
		surface = v
		_queue_rebuild()
@export_range(0.0, 1.0, 0.01) var bevel := 0.1:
	set(v):
		bevel = v
		_queue_rebuild()
@export_range(2, 40) var step_count := 6:
	set(v):
		step_count = v
		_queue_rebuild()
## Stairs collide as a smooth ramp (true) or as real steps (false).
@export var smooth_stair_collision := true:
	set(v):
		smooth_stair_collision = v
		_queue_rebuild()
## Text for a floating label; "auto" prints the dimensions.
@export var label := "":
	set(v):
		label = v
		_queue_rebuild()
@export var label_offset := Vector3(0.0, 0.7, 0.0):
	set(v):
		label_offset = v
		_queue_rebuild()
## Patchy always slides here regardless of angle (dunes, chutes).
@export var slide_surface := false
@export var no_ledge_grab := false
@export var no_wall_kick := false

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _label: Label3D
var _pending := false


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_notify_transform(true)
	if slide_surface:
		add_to_group(&"slide_surface")
	if no_ledge_grab:
		add_to_group(&"no_ledge_grab")
	if no_wall_kick:
		add_to_group(&"no_wall_kick")
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and _mesh_instance != null:
		_mesh_instance.set_instance_shader_parameter(&"top_y", global_position.y + _top_height())


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _top_height() -> float:
	return size.y


func _rebuild() -> void:
	_pending = false
	if _mesh_instance == null:
		_mesh_instance = MeshInstance3D.new()
		_mesh_instance.name = "Mesh"
		add_child(_mesh_instance, false, Node.INTERNAL_MODE_FRONT)
	if _collision == null:
		_collision = CollisionShape3D.new()
		_collision.name = "Collision"
		add_child(_collision, false, Node.INTERNAL_MODE_FRONT)
	set_meta(&"surface", FOOTSTEP.get(surface, &"stone"))

	var mb := MeshBuilder.new()
	var color := Color.WHITE
	match shape:
		Shape.BOX:
			mb.rounded_box(size, bevel, Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0)), color, 2)
			var box := BoxShape3D.new()
			box.size = size
			_collision.shape = box
			_collision.position = Vector3(0, size.y * 0.5, 0)
		Shape.CYLINDER:
			mb.cylinder(size.x * 0.5, size.x * 0.5, size.y, Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0)), color, 24)
			var cyl := CylinderShape3D.new()
			cyl.radius = size.x * 0.5
			cyl.height = size.y
			_collision.shape = cyl
			_collision.position = Vector3(0, size.y * 0.5, 0)
		Shape.RAMP:
			_build_ramp(mb, color)
			_collision.shape = _ramp_shape()
			_collision.position = Vector3.ZERO
		Shape.STAIRS:
			var n := step_count
			var step_d := size.z / n
			var step_h := size.y / n
			for k in n:
				var h := step_h * (k + 1)
				var zc := size.z * 0.5 - step_d * (k + 0.5)
				mb.rounded_box(Vector3(size.x, h, step_d), minf(bevel, step_h * 0.4), Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, zc)), color, 1)
			if smooth_stair_collision:
				_collision.shape = _ramp_shape()
				_collision.position = Vector3.ZERO
			else:
				var faces := PackedVector3Array()
				var tmp := MeshBuilder.new()
				for k in n:
					var h := step_h * (k + 1)
					var zc := size.z * 0.5 - step_d * (k + 0.5)
					tmp.box(Vector3(size.x, h, step_d), Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, zc)))
				faces = tmp.get_faces()
				var conc := ConcavePolygonShape3D.new()
				conc.set_faces(faces)
				_collision.shape = conc
				_collision.position = Vector3.ZERO
	_mesh_instance.mesh = mb.build()
	_mesh_instance.material_override = MaterialLibrary.terrain(StringName(surface))
	_mesh_instance.set_instance_shader_parameter(&"top_y", global_position.y + _top_height() if is_inside_tree() else size.y)
	_update_label()


func _build_ramp(mb: MeshBuilder, color: Color) -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var y := size.y
	# Bottom-front edge at +Z (height 0), top-back edge at -Z (height y).
	var p := [
		Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz),
		Vector3(-hx, y, -hz), Vector3(hx, y, -hz),
	]
	mb.triangle(p[0], p[4], p[5], color)  # slope
	mb.triangle(p[0], p[5], p[1], color)
	mb.triangle(p[3], p[5], p[4], color)  # back wall
	mb.triangle(p[3], p[2], p[5], color)
	mb.triangle(p[0], p[3], p[4], color)  # left side
	mb.triangle(p[1], p[5], p[2], color)  # right side
	mb.triangle(p[0], p[1], p[2], color)  # bottom
	mb.triangle(p[0], p[2], p[3], color)


func _ramp_shape() -> ConvexPolygonShape3D:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var s := ConvexPolygonShape3D.new()
	s.points = PackedVector3Array([
		Vector3(-hx, 0, hz), Vector3(hx, 0, hz), Vector3(hx, 0, -hz), Vector3(-hx, 0, -hz),
		Vector3(-hx, size.y, -hz), Vector3(hx, size.y, -hz),
	])
	return s


func _update_label() -> void:
	if label == "":
		if _label != null:
			_label.queue_free()
			_label = null
		return
	if _label == null:
		_label = Label3D.new()
		_label.name = "Label"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 56
		_label.pixel_size = 0.006
		_label.outline_size = 14
		_label.modulate = Color(1, 1, 1)
		_label.outline_modulate = Color(0.15, 0.1, 0.2)
		_label.no_depth_test = false
		add_child(_label, false, Node.INTERNAL_MODE_FRONT)
	var text := label
	if label == "auto":
		match shape:
			Shape.RAMP, Shape.STAIRS:
				text = "%.1fm rise / %.0f°" % [size.y, rad_to_deg(atan2(size.y, size.z))]
			_:
				text = "%.1f × %.1f × %.1f" % [size.x, size.y, size.z]
	_label.text = text
	_label.position = Vector3(0, size.y, 0) + label_offset
