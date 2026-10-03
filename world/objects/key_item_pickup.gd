@tool
class_name KeyItemPickup
extends Area3D
## A key item (a tool that isn't a hook attachment: the Spyglass...) turning
## slowly over a little pedestal. Touching it adds it to the inventory with
## a celebration and a one-line how-to. Gone for good once owned.

@export var item_id: StringName = &"spyglass"

const ITEMS := {
	&"spyglass": {"name": "the Spyglass", "hint": "Hold {spyglass} to look far out to sea. New islands go on your chart.", "color": Color("e8b84a")},
}

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
	var mb := MeshBuilder.new()
	mb.cylinder(0.45, 0.55, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), Palette.WOOD_DARK, 10)
	mb.cylinder(0.52, 0.52, 0.08, Transform3D(Basis.IDENTITY, Vector3(0, 0.52, 0)), Palette.WOOD, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	_visual.position = Vector3(0, 1.2, 0)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var model := MeshInstance3D.new()
	model.mesh = item_mesh(item_id)
	_visual.add_child(model)
	var light := OmniLight3D.new()
	light.light_specular = 0.0
	light.light_color = ITEMS.get(item_id, {}).get("color", Color.WHITE)
	light.light_energy = 1.0
	light.omni_range = 3.0
	_visual.add_child(light)
	if Engine.is_editor_hint():
		return
	if InventoryManager.has_key_item(item_id):
		queue_free()
		return
	add_to_group(&"look_at_target")
	body_entered.connect(_on_body)


## The item's little model (the Spyglass: a brass telescope, drawn out).
static func item_mesh(id: StringName) -> ArrayMesh:
	var mb := MeshBuilder.new()
	match id:
		&"spyglass":
			var brass := Color("e8b84a")
			var x := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
			mb.cylinder(0.11, 0.11, 0.38, x.translated(Vector3(-0.2, 0, 0)), Color("5b3a22"), 10)
			mb.cylinder(0.09, 0.09, 0.32, x.translated(Vector3(0.12, 0, 0)), brass, 10)
			mb.cylinder(0.07, 0.07, 0.26, x.translated(Vector3(0.38, 0, 0)), brass.lightened(0.15), 10)
			for k: float in [-0.39, 0.0, 0.28, 0.5]:
				mb.cylinder(0.125 - absf(k) * 0.05, 0.125 - absf(k) * 0.05, 0.04, x.translated(Vector3(k, 0, 0)), brass.darkened(0.2), 10)
			mb.cylinder(0.08, 0.08, 0.02, x.translated(Vector3(-0.4, 0, 0)), Color("9fd6ff"), 10)
		_:
			mb.sphere(0.2, Transform3D.IDENTITY, Palette.GOLD, 6, 8)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))


func _process(delta: float) -> void:
	_t += delta
	if _visual != null and not _taken:
		_visual.rotation.y = _t * 1.4
		_visual.position.y = 1.2 + sin(_t * 2.2) * 0.1


func _on_body(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	var p := body as Player
	var info: Dictionary = ITEMS.get(item_id, {})
	InventoryManager.add_key_item(item_id)
	AudioManager.play(&"treasure_big", global_position)
	AudioManager.play_stinger(&"stinger_treasure")
	VFX.sparkle(self, global_position + Vector3.UP * 1.2, info.get("color", Palette.GOLD), 30, 6.0)
	Events.hud_message.emit("You found %s!" % info.get("name", String(item_id)), 2.5)
	if p.state_id == &"ground":
		p.set_locked(true, {"anim": &"cheer"})
	p.play_tool_anim(&"hold_up", 1.4)
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(1.3, false).timeout
	if is_instance_valid(p) and p.state_id == &"locked":
		p.set_locked(false)
	if info.has("hint"):
		Events.hud_message.emit(info["hint"], 4.5)
	queue_free()
