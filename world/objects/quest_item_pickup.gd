@tool
class_name QuestItemPickup
extends Area3D
## Something an islander has asked Patchy to find (the old dinghy's sail,
## its tiller): it bobs and glints where it lies, on land or on the seabed,
## and touching it picks it up with a little fanfare. Picking it up marks
## `item_id` completed in WorldState; the islander takes it from there.
## Gone for good once found (or once `gone_after` is completed).

@export var item_id: StringName = &"dinghy_sail"
## Once this is completed the item has been handed over (don't respawn it).
@export var gone_after: StringName = &""

const ITEMS := {
	&"dinghy_sail": {"name": "the old patched sail", "hint": "Take it to Gus at the shipyard.", "color": Color("f4e8cc")},
	&"dinghy_tiller": {"name": "the dinghy's tiller", "hint": "Take it to Gus at the shipyard.", "color": Color("c98a4b")},
}

var _visual: Node3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = Layers.COLLECTIBLE
	collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.1
	cs.shape = sph
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	_visual.position = Vector3(0, 0.6, 0)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var model := MeshInstance3D.new()
	model.mesh = item_mesh(item_id)
	_visual.add_child(model)
	var light := OmniLight3D.new()
	light.light_specular = 0.0
	light.light_color = ITEMS.get(item_id, {}).get("color", Color.WHITE)
	light.light_energy = 0.9
	light.omni_range = 3.0
	_visual.add_child(light)
	if Engine.is_editor_hint():
		return
	if WorldState.is_completed(item_id) or (gone_after != &"" and WorldState.is_completed(gone_after)):
		queue_free()
		return
	add_to_group(&"look_at_target")
	body_entered.connect(_on_body)


static func item_mesh(id: StringName) -> ArrayMesh:
	var mb := MeshBuilder.new()
	match id:
		&"dinghy_sail":
			# A sail rolled round its boom and tied, patches showing.
			var cloth := Color("f4e8cc")
			var x := Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3.ZERO)
			mb.cylinder(0.035, 0.035, 1.5, x, Palette.WOOD_DARK, 6)
			mb.cylinder(0.16, 0.16, 1.1, x, cloth, 12)
			mb.cylinder(0.165, 0.165, 0.28, x.translated(Vector3(-0.2, 0, 0)), Color("e9b44c"), 12)
			mb.cylinder(0.165, 0.165, 0.2, x.translated(Vector3(0.3, 0, 0)), Color("6fb0d9"), 12)
			for k: float in [-0.42, 0.05, 0.45]:
				mb.cylinder(0.172, 0.172, 0.05, x.translated(Vector3(k, 0, 0)), Palette.ROPE, 12)
			mb.box(Vector3(0.02, 0.24, 0.16), Transform3D(Basis.IDENTITY, Vector3(0.78, 0.0, 0)), Palette.COAT)
		&"dinghy_tiller":
			# A curved tiller arm with its rudder blade.
			var wood := Color("c98a4b")
			mb.tube(PackedVector3Array([Vector3(-0.7, 0.12, 0), Vector3(-0.2, 0.05, 0), Vector3(0.3, 0.0, 0)]), PackedFloat32Array([0.035, 0.045, 0.05]), wood, 7, true)
			mb.rounded_box(Vector3(0.18, 0.7, 0.07), 0.03, Transform3D(Basis.IDENTITY, Vector3(0.42, -0.2, 0)), wood.darkened(0.15))
			mb.box(Vector3(0.06, 0.08, 0.1), Transform3D(Basis.IDENTITY, Vector3(0.32, 0.02, 0)), Palette.METAL)
		_:
			mb.sphere(0.2, Transform3D.IDENTITY, Palette.GOLD, 6, 8)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))


func _process(delta: float) -> void:
	_t += delta
	if _visual != null and not _taken:
		_visual.rotation.y = _t * 1.1
		_visual.position.y = 0.6 + sin(_t * 2.0) * 0.08


func _on_body(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	set_deferred(&"monitoring", false)
	var p := body as Player
	var info: Dictionary = ITEMS.get(item_id, {})
	WorldState.mark_completed(item_id)
	AudioManager.play(&"treasure_big", global_position)
	AudioManager.play_stinger(&"stinger_treasure")
	VFX.sparkle(self, global_position + Vector3.UP * 0.7, info.get("color", Palette.GOLD), 24, 5.0)
	Events.hud_message.emit("You found %s! %s" % [info.get("name", String(item_id)), info.get("hint", "")], 3.0)
	p.play_tool_anim(&"hold_up", 1.2)
	GameManager.quest_log_refresh()
	var tw := create_tween()
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()
