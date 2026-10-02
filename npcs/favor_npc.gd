@tool
class_name FavorNPC
extends NPC
## An islander with a favor to ask (spec §103–104). The first talk (`lines`)
## asks and starts the quest; `waiting_lines` nudge while it's open. Once
## `done_flag` is set in WorldState (a boat flown home, a pelican chased
## off) `thanks_lines` play and the reward is handed over: a treasure map,
## or a unique treasure that pops out for Patchy to catch. `after_lines`
## follow. Every step is persistent.

## Set when the favor has been asked (the quest log shows it from then on).
@export var quest_flag: StringName = &""
## The WorldState id that means the favor is done.
@export var done_flag: StringName = &""
## Set once the reward has been handed over.
@export var reward_flag: StringName = &""
@export var waiting_lines: PackedStringArray = PackedStringArray()
@export var thanks_lines: PackedStringArray = PackedStringArray()
@export var after_lines: PackedStringArray = PackedStringArray()
@export_enum("none", "map", "gem", "pearl", "goblet", "crown", "relic") var reward_kind := "none"
## Treasure map id, or the unique treasure's id.
@export var reward_id: StringName = &""
@export var reward_island: StringName = &""
@export var reward_color := Color.WHITE
## HUD line when the reward is handed over ("" = none).
@export var reward_message := ""


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if _is_treasure():
		add_to_group(&"treasure_source")
		# Handed over but never caught (left the island first): it waits by
		# the giver.
		if _flag(reward_flag) and not InventoryManager.has_treasure(reward_id):
			_spawn_reward.call_deferred(false)


func get_lines() -> PackedStringArray:
	if _flag(reward_flag):
		return after_lines if not after_lines.is_empty() else thanks_lines
	if _flag(done_flag):
		return thanks_lines
	if _flag(quest_flag) and not waiting_lines.is_empty():
		return waiting_lines
	return lines


func is_favor_done() -> bool:
	return _flag(reward_flag)


## For IslandInfo's treasure totals.
func get_treasure_island() -> StringName:
	return reward_island


func _after_talk(player: Player) -> void:
	if quest_flag != &"" and not _flag(quest_flag):
		WorldState.mark_completed(quest_flag)
		GameManager.quest_log_refresh()
	if not _flag(done_flag) or _flag(reward_flag):
		return
	if reward_flag != &"":
		WorldState.mark_completed(reward_flag)
	match reward_kind:
		"none":
			pass
		"map":
			InventoryManager.add_treasure_map(reward_id)
			AudioManager.play_stinger(&"stinger_treasure")
			if player != null:
				player.play_tool_anim(&"hold_up", 0.9)
		_:
			_spawn_reward(true)
	if reward_message != "":
		Events.hud_message.emit(reward_message, 3.0)
	GameManager.quest_log_refresh()


func _is_treasure() -> bool:
	return reward_kind not in ["none", "map"] and reward_id != &""


## The reward hops out of the giver's paws toward Patchy (or just rests at
## their feet when restored after a reload).
func _spawn_reward(toss: bool) -> void:
	if InventoryManager.has_treasure(reward_id):
		return
	var prize := Collectible.new()
	prize.kind = reward_kind
	prize.treasure_id = reward_id
	prize.island_id = reward_island
	prize.gem_color = reward_color
	var fwd := -global_basis.z
	if model != null:
		fwd = -model.global_basis.z
	fwd = Player.flat(fwd).normalized()
	if toss:
		prize.launched = true
		prize.launch_velocity = fwd * 1.6 + Vector3.UP * 5.5
	get_tree().current_scene.add_child(prize)
	prize.global_position = global_position + fwd * 0.9 + Vector3.UP * (1.1 if toss else 0.6)


func _flag(id: StringName) -> bool:
	return id != &"" and WorldState.is_completed(id)
