@tool
class_name NPC
extends Interactable
## A friendly island resident (spec §101–102, §168): idles with small
## loops, turns to look at Patchy when he's near, and says a few short,
## characterful, skippable lines. Dialogue goes through the UI autoload's
## show_dialogue when available (falls back to HUD messages).

signal talked(times: int)

@export var display_name := "Islander"
## Lines for the first conversation.
@export var lines: PackedStringArray = PackedStringArray(["Ahoy!"])
## Lines for later conversations (falls back to the last first-line).
@export var repeat_lines: PackedStringArray = PackedStringArray()
## Optional world-state flag set after the first talk.
@export var talked_flag: StringName = &""
@export var model: Node3D

var _times := 0
var _talking := false
var _base_yaw := 0.0


func _ready() -> void:
	prompt = "{interact} Talk"
	radius = 2.2
	super._ready()
	if model == null:
		for c in get_children():
			if c is Node3D and not c is CollisionShape3D:
				model = c
				break
	if model != null:
		_base_yaw = model.rotation.y
	if not Engine.is_editor_hint() and talked_flag != &"" and WorldState.is_completed(talked_flag):
		_times = 1


func can_interact(_player: Node3D) -> bool:
	return enabled and not _talking


func interact(player: Node3D) -> void:
	super.interact(player)
	_talk(player as Player)


func _talk(player: Player) -> void:
	_talking = true
	var use: PackedStringArray = lines if _times == 0 or repeat_lines.is_empty() else repeat_lines
	if player != null:
		player.set_locked(true, {"anim": &"idle", "face": Player.flat(global_position - player.global_position).normalized()})
		player.interaction.clear()
	AudioManager.play(&"prompt_appear", global_position)
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"show_dialogue"):
		var arr: Array[String] = []
		for l in use:
			arr.append(l)
		await ui.show_dialogue(display_name, arr)
	else:
		Events.dialogue_started.emit(display_name)
		for l in use:
			Events.hud_message.emit("%s: %s" % [display_name, l], 2.6)
			await get_tree().create_timer(2.2, false).timeout
		Events.dialogue_finished.emit()
	_times += 1
	if talked_flag != &"":
		WorldState.mark_completed(talked_flag)
	talked.emit(_times)
	if player != null and player.state_id == &"locked":
		player.set_locked(false)
	_talking = false


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or model == null:
		return
	var p := GameManager.player
	var goal := _base_yaw
	if p != null and p.global_position.distance_to(global_position) < 7.0:
		var to := Player.flat(p.global_position - global_position)
		goal = Player.yaw_of(to.normalized())
	model.rotation.y = lerp_angle(model.rotation.y, goal, 1.0 - exp(-delta * 4.0))
	model.position.y = sin(Time.get_ticks_msec() * 0.002 + get_instance_id()) * 0.02
