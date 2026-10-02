@tool
class_name DarknessZone
extends Area3D
## Pitch-dark places (spec §59, §76). Without the Storm Lantern, Patchy
## refuses to go in: at the threshold he stops, eyes widen, something makes
## an innocuous noise, and he tiptoes back out. No text needed: animation
## teaches "come back later". With the lantern equipped he can explore, and
## the screen darkens toward the zone's depth so it reads as truly dark.
## Once every brazier in `lit_by` burns, the place is lit for good.

@export var size := Vector3(6.0, 4.0, 10.0):
	set(v):
		size = v
		_rebuild()
## Direction (local) that leads deeper into the dark.
@export var inward := Vector3(0, 0, -1)
## How far Patchy gets before he refuses (m).
@export_range(0.0, 5.0, 0.1) var refusal_depth := 1.4
## Max screen darkening deep inside (0..1).
@export_range(0.0, 1.0, 0.01) var max_darkness := 0.88
## Fires (anything with is_active()) that light this place up once all burn.
@export var lit_by: Array[Node] = []

var _shape: CollisionShape3D
var _player: Player
var _refusing := false
var _overlay: ColorRect
var _layer: CanvasLayer


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	_rebuild()
	if Engine.is_editor_hint():
		return
	body_entered.connect(func(b: Node3D) -> void:
		if b is Player:
			_player = b as Player)
	body_exited.connect(func(b: Node3D) -> void:
		if b == _player:
			_player = null)
	_layer = CanvasLayer.new()
	_layer.layer = 50
	add_child(_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0.01, 0.01, 0.03, 0.0)
	_layer.add_child(_overlay)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _shape == null:
		_shape = CollisionShape3D.new()
		add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	var b := BoxShape3D.new()
	b.size = size
	_shape.shape = b


static func has_light() -> bool:
	return InventoryManager.equipped_attachment == &"lantern"


func is_lit_up() -> bool:
	if lit_by.is_empty():
		return false
	for n in lit_by:
		if n == null or not n.has_method(&"is_active") or not n.call(&"is_active"):
			return false
	return true


func _depth_of(p: Node3D) -> float:
	# Distance travelled inward from the zone's entry face.
	var local := global_transform.affine_inverse() * p.global_position
	var dir := inward.normalized()
	var half := absf(dir.dot(size * 0.5))
	return local.dot(dir) + half


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var target_alpha := 0.0
	if _player != null and is_instance_valid(_player) and not is_lit_up():
		var depth := _depth_of(_player)
		var lit := has_light()
		var k := clampf(depth / maxf(refusal_depth * 2.0, 0.1), 0.0, 1.0)
		target_alpha = max_darkness * k * (0.35 if lit else 1.0)
		if not lit and not _refusing and depth > refusal_depth and _player.state_id == &"ground":
			_refuse()
	_overlay.color.a = lerpf(_overlay.color.a, target_alpha, 1.0 - exp(-delta * 6.0))


func _refuse() -> void:
	_refusing = true
	var p := _player
	var back := -(global_basis * inward.normalized())
	back.y = 0.0
	back = back.normalized()
	# 1. Freeze, staring into the dark.
	p.set_locked(true, {"anim": &"scared", "face": -back})
	await get_tree().create_timer(0.8, false).timeout
	# 2. Something innocuous in the dark makes a noise.
	AudioManager.play(&"wood_creak", global_position - back * 3.0, 2.0, 1.6)
	await get_tree().create_timer(0.35, false).timeout
	AudioManager.play(&"parrot_squawk", p.global_position, -8.0, 0.7)
	# 3. Slowly back out, still facing the dark.
	if is_instance_valid(p) and p.state_id == &"locked":
		var st := p.state
		st.set(&"scripted_velocity", back * 1.6)
		st.set(&"anim", &"tiptoe_back")
		await get_tree().create_timer(1.3, false).timeout
	if is_instance_valid(p):
		p.set_locked(false)
		p.facing = back
	await get_tree().create_timer(0.6, false).timeout
	_refusing = false
