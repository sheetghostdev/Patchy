@tool
class_name HeartPiece
extends Area3D
## A Heart Piece (docs/ARCHIPELAGO.md): a quarter of a big red heart in a
## gold frame, turning slowly over a glow. Four make a new heart container.
## Gone for good once found.

@export var piece_id: StringName = &""

const RED := Color("e8433a")

var _visual: Node3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = Layers.COLLECTIBLE
	collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.9
	cs.shape = sph
	cs.position = Vector3(0, 0.9, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	_visual.position = Vector3(0, 1.0, 0)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mi := MeshInstance3D.new()
	mi.mesh = piece_mesh()
	_visual.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = Color("ff8a7a")
	light.light_energy = 1.2
	light.omni_range = 3.0
	light.light_specular = 0.0
	_visual.add_child(light)
	if Engine.is_editor_hint():
		return
	if piece_id != &"" and InventoryManager.has_heart_piece(piece_id):
		queue_free()
		return
	add_to_group(&"look_at_target")
	body_entered.connect(_on_body)


## A heart's outline with one quarter filled in red, the rest ghostly.
static func piece_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var pts := PackedVector2Array()
	var n := 40
	for i in n:
		var t := TAU * i / n
		# The classic heart curve, scaled to ~0.9 m.
		var x := 16.0 * pow(sin(t), 3.0)
		var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y) * 0.03)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		# The upper-right quarter is the piece; the rest is a pale ghost.
		var mid := (a + b) * 0.5
		var col := RED if mid.x > 0.0 and mid.y > 0.0 else Color(1, 0.86, 0.84)
		for z: float in [0.09, -0.09]:
			mb.triangle(Vector3(0, 0, z), Vector3(a.x, a.y, z), Vector3(b.x, b.y, z), col, true)
		mb.triangle(Vector3(a.x, a.y, 0.09), Vector3(b.x, b.y, 0.09), Vector3(b.x, b.y, -0.09), col.darkened(0.15), true)
		mb.triangle(Vector3(a.x, a.y, 0.09), Vector3(b.x, b.y, -0.09), Vector3(a.x, a.y, -0.09), col.darkened(0.15), true)
		mb.box(Vector3((b - a).length() + 0.02, 0.05, 0.22), Transform3D(Basis(Vector3.BACK, atan2(b.y - a.y, b.x - a.x)), Vector3(mid.x, mid.y, 0) * 1.04), Palette.GOLD)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


func _process(delta: float) -> void:
	_t += delta
	if _visual != null and not _taken:
		_visual.rotation.y = _t * 1.6
		_visual.position.y = 1.0 + sin(_t * 2.4) * 0.12


func _on_body(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	set_deferred(&"monitoring", false)
	var p := body as Player
	var whole := InventoryManager.add_heart_piece(piece_id)
	AudioManager.play(&"heart_pickup", global_position, 0.0, 0.8)
	AudioManager.play_stinger(&"stinger_treasure")
	VFX.sparkle(self, global_position + Vector3.UP, RED, 30, 6.0)
	if whole:
		p.health.refill()
		Events.hud_message.emit("Four Heart Pieces make a new heart container!", 3.5)
	else:
		Events.hud_message.emit("A Heart Piece! (%d of %d)" % [InventoryManager.heart_pieces_held(), InventoryManager.PIECES_PER_HEART], 3.0)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
