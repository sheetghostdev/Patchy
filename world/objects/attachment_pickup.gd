@tool
class_name AttachmentPickup
extends Area3D
## A new hand attachment, floating and turning over a little pedestal (spec
## §53). Touching it unlocks and equips it with a celebration and a one-line
## how-to. Gone for good once owned.

@export var attachment_id: StringName = &"lantern"
## Hide the stone pedestal (when it pops out of a chest or a dig spot).
@export var bare := false

var _visual: Node3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = Layers.COLLECTIBLE
	collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.0
	cs.shape = sph
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if not bare:
		var mb := MeshBuilder.new()
		mb.cylinder(0.55, 0.65, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), Palette.STONE, 12)
		mb.cylinder(0.62, 0.62, 0.08, Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0)), Palette.STONE.lightened(0.1), 12)
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	_visual.position = Vector3(0, 1.3, 0)
	_visual.scale = Vector3.ONE * 2.0
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var data := _data()
	if data != null and data.scene != null:
		# Attachments hang down the forearm (-Y); center each for display.
		var model := data.scene.instantiate() as Node3D
		_visual.add_child(model)
		match attachment_id:
			&"cannon":
				model.rotation_degrees = Vector3(0, 0, 90)
				model.position = Vector3(-0.2, 0, 0)
			&"shovel":
				model.position = Vector3(0, 0.45, 0)
			_:
				model.position = Vector3(0, 0.2, 0)
	var light := OmniLight3D.new()
	light.light_color = data.color if data != null else Color.WHITE
	light.light_energy = 1.2
	light.omni_range = 3.5
	_visual.add_child(light)
	if Engine.is_editor_hint():
		return
	if InventoryManager.has_attachment(attachment_id):
		queue_free()
		return
	add_to_group(&"look_at_target")
	body_entered.connect(_on_body)


func _data() -> AttachmentData:
	var path := "res://resources/attachments/%s.tres" % attachment_id
	return load(path) as AttachmentData if ResourceLoader.exists(path) else null


func _process(delta: float) -> void:
	_t += delta
	if _visual != null and not _taken:
		_visual.rotation.y = _t * 1.6
		_visual.position.y = 1.3 + sin(_t * 2.2) * 0.12


func _on_body(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	var p := body as Player
	InventoryManager.unlock_attachment(attachment_id)
	p.attachments.equip(attachment_id)
	var inst := p.attachments.get_instance(attachment_id)
	var data := _data()
	AudioManager.play(&"treasure_big", global_position)
	AudioManager.play_stinger(&"stinger_treasure")
	VFX.sparkle(self, global_position + Vector3.UP * 1.2, data.color if data != null else Palette.GOLD, 30, 6.0)
	var hint := inst.pickup_hint() if inst != null else ""
	var name_text := data.display_name if data != null else String(attachment_id)
	Events.hud_message.emit("New attachment: %s!" % name_text, 2.5)
	if p.state_id == &"ground":
		p.set_locked(true, {"anim": &"cheer"})
	p.play_tool_anim(&"hold_up", 1.4)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.3, false).timeout
	if is_instance_valid(p) and p.state_id == &"locked":
		p.set_locked(false)
	if hint != "":
		Events.hud_message.emit(hint, 4.5)
	queue_free()
