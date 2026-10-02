@tool
class_name Gate
extends StaticBody3D
## A heavy wooden portcullis (spec §87 puzzles). Opens by sinking into the
## ground once every listed trigger (braziers, cannon targets, pound posts:
## anything with is_active() and an `activated` signal) is active, or when
## open() is called. Persistent by gate_id.

signal opened

@export var gate_id: StringName = &""
@export var size := Vector3(4.0, 3.5, 0.4):
	set(v):
		size = v
		_rebuild()
@export var triggers: Array[Node] = []
## Begins sunk in the ground (a scripted barrier raised with close()).
@export var start_open := false

var _mesh: MeshInstance3D
var _col: CollisionShape3D
var _open := false


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"wood")
	_rebuild()
	if Engine.is_editor_hint():
		return
	if (gate_id != &"" and WorldState.is_completed(gate_id)) or start_open:
		_open = true
		visible = false
		_col.disabled = true
		_mesh.position.y = -size.y - 0.1
		return
	for t in triggers:
		if t != null and t.has_signal(&"activated"):
			t.connect(&"activated", _check)
		elif t is PoundPost:
			(t as PoundPost).pounded.connect(func(_p: PoundPost) -> void: _check())


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_col = CollisionShape3D.new()
		add_child(_col, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var bars := maxi(3, int(size.x / 0.55))
	for i in bars:
		var x := -size.x * 0.5 + (i + 0.5) * size.x / bars
		mb.box(Vector3(0.18, size.y, 0.18), Transform3D(Basis.IDENTITY, Vector3(x, size.y * 0.5, 0)), Palette.WOOD_DARK)
	for y: float in [0.25, 0.6, 0.9]:
		mb.box(Vector3(size.x + 0.1, 0.16, 0.24), Transform3D(Basis.IDENTITY, Vector3(0, size.y * y, 0)), Palette.WOOD)
	for x: float in [-0.5, 0.5]:
		mb.box(Vector3(0.12, size.y * 0.9, 0.06), Transform3D(Basis.IDENTITY, Vector3(x * (size.x - 0.4), size.y * 0.5, 0.15)), Palette.METAL)
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	var box := BoxShape3D.new()
	box.size = size
	_col.shape = box
	_col.position = Vector3(0, size.y * 0.5, 0)


func _check() -> void:
	for t in triggers:
		if t == null:
			continue
		var active := false
		if t.has_method(&"is_active"):
			active = t.call(&"is_active")
		elif t is PoundPost:
			active = (t as PoundPost).down
		if not active:
			return
	open()


func open() -> void:
	if _open:
		return
	_open = true
	if gate_id != &"":
		WorldState.mark_completed(gate_id)
	AudioManager.play(&"door_open", global_position)
	Events.camera_impulse.emit(0.25)
	var tw := create_tween()
	tw.tween_property(_mesh, "position:y", -size.y - 0.1, 1.2).set_trans(Tween.TRANS_SINE)
	await tw.finished
	_col.disabled = true
	visible = false
	opened.emit()


## Raises the gate back up out of the ground (arena barriers).
func close() -> void:
	if not _open:
		return
	_open = false
	visible = true
	_col.disabled = false
	AudioManager.play(&"door_open", global_position, 0.0, 0.8)
	var tw := create_tween()
	tw.tween_property(_mesh, "position:y", 0.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
