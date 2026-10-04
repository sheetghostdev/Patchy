@tool
class_name ShipwrightNPC
extends NPC
## Gus, Barnacle Bay's shipwright, and the old dinghy (docs/ARCHIPELAGO.md):
## Patchy's first boat. Gus has the hull sound but it wants its sail and its
## tiller, and the village has scattered both: bring them to him and he
## fixes it up on the spot. From then on it's Patchy's, moored at the pier,
## and the whole sea is open to him; talk to Gus again and he opens his
## shipyard (UIShipyard): a faster sail, a tougher hull, a bow cannon, and
## new colors, flags and figureheads.
## Flags: `quest_flag` once asked, `parts` (WorldState ids picked up by
## QuestItemPickups), `fixed_flag` once the dinghy's in the water.

@export var quest_flag: StringName = &"castaway_dinghy_quest"
@export var fixed_flag: StringName = &"castaway_dinghy"
@export var parts: Array[StringName] = [&"dinghy_sail", &"dinghy_tiller"]
## What each part is called in his nudges, in `parts` order.
@export var part_hints: PackedStringArray = PackedStringArray()
@export var waiting_lines: PackedStringArray = PackedStringArray()
@export var fixing_lines: PackedStringArray = PackedStringArray()
## Said once she's fixed, as Patchy gets her.
@export var launch_lines: PackedStringArray = PackedStringArray()
## Said before the shipyard opens, each visit once the dinghy's fixed.
@export var after_lines: PackedStringArray = PackedStringArray()

var _yard_next := false


func get_lines() -> PackedStringArray:
	_yard_next = _flag(fixed_flag)
	if _yard_next:
		return after_lines
	if not _flag(quest_flag):
		return lines
	if missing().is_empty():
		return fixing_lines
	var out := PackedStringArray(waiting_lines)
	for k in parts.size():
		if not _flag(parts[k]) and k < part_hints.size():
			out.append(part_hints[k])
	return out


## The parts still to find.
func missing() -> Array[StringName]:
	var out: Array[StringName] = []
	for p in parts:
		if not _flag(p):
			out.append(p)
	return out


func is_fixed() -> bool:
	return _flag(fixed_flag)


func _after_talk(player: Player) -> void:
	if not _flag(quest_flag):
		WorldState.mark_completed(quest_flag)
		GameManager.quest_log_refresh()
	if _yard_next:
		_yard_next = false
		var ui := UIRoot.instance
		if ui != null:
			await ui.open_shipyard()
		return
	if _flag(fixed_flag) or not missing().is_empty():
		return
	# Everything's here: a few minutes' hammering, and she floats.
	await SceneTransition.fade_out(0.5)
	for k in 4:
		AudioManager.play(&"wood_creak", global_position, -2.0, randf_range(0.8, 1.2))
		await get_tree().create_timer(0.25, true, false, true).timeout
	WorldState.mark_completed(fixed_flag)
	GameManager.quest_log_refresh()
	await SceneTransition.fade_in(0.5)
	AudioManager.play_stinger(&"stinger_treasure")
	if player != null:
		player.play_tool_anim(&"hold_up", 0.9)
	var ui := UIRoot.instance
	if ui != null and not launch_lines.is_empty():
		var arr: Array[String] = []
		arr.assign(Array(launch_lines))
		await ui.show_dialogue(display_name, arr)
	Events.hud_message.emit("The old dinghy's yours! She's waiting at the end of the pier. (Gus can fit her out, too.)", 3.5)


func _flag(id: StringName) -> bool:
	return id != &"" and WorldState.is_completed(id)
