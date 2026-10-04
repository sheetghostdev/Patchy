@tool
class_name TutorialHint
extends Node3D
## A one-time, in-context control hint (spec §123). When Patchy is inside the
## box and in control (not in a cutscene, dialogue or the boat), a short
## toast with input glyphs appears, e.g. "{jump} Jump - hold it to go
## higher". Each hint shows once per save (WorldState). The level teaches;
## the hint only names the button.

@export var hint_id: StringName = &""
@export_multiline var text := ""
@export_range(1.0, 10.0, 0.1) var duration := 4.5
@export var size := Vector3(6, 4, 6)
## Only hint once this attachment is owned (e.g. the ring swing hint).
@export var require_attachment: StringName = &""
## Only hint once this WorldState id is completed (e.g. the boat's there).
@export var require_flag: StringName = &""

var _check_t := 0.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or hint_id == &"":
		return
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = 0.25
	if WorldState.is_completed(hint_id):
		set_physics_process(false)
		return
	var p := GameManager.player as Player
	if p == null or not p.state_id in [&"ground", &"air", &"swim"]:
		return
	if require_attachment != &"" and not InventoryManager.has_attachment(require_attachment):
		return
	if require_flag != &"" and not WorldState.is_completed(require_flag):
		return
	var local := global_transform.affine_inverse() * p.global_position
	if absf(local.x) > size.x * 0.5 or absf(local.z) > size.z * 0.5 or local.y < -0.5 or local.y > size.y:
		return
	WorldState.mark_completed(hint_id)
	Events.hud_message.emit(text, duration)
	set_physics_process(false)
