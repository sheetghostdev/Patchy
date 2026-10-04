@tool
class_name ShellbyNPC
extends FavorNPC
## Old Shellby: the Barnacle Betty favor (FavorNPC), and then the way out
## to sea. Once Brock has rowed off (`sail_after`), Shellby hands over the
## Betty's spare sail, which rigs onto Patchy's little boat and makes it a
## good deal quicker for the islands on the horizon (docs/ARCHIPELAGO.md).
## The gift comes first; the favor talk resumes after.

## WorldState id that makes Shellby offer the sail.
@export var sail_after: StringName = &"brock_cameo_seen"
@export var sail_lines: PackedStringArray = PackedStringArray()


func sail_pending() -> bool:
	return _flag(sail_after) and not TinyBoat.has_spare_sail()


func get_lines() -> PackedStringArray:
	if sail_pending() and not sail_lines.is_empty():
		return sail_lines
	return super.get_lines()


func _after_talk(player: Player) -> void:
	if not sail_pending():
		await super._after_talk(player)
		return
	WorldState.mark_completed(TinyBoat.SPARE_SAIL)
	for b in get_tree().get_nodes_in_group(&"boat"):
		if b.has_method(&"refresh_sail"):
			b.call(&"refresh_sail")
	AudioManager.play_stinger(&"stinger_treasure")
	if player != null:
		player.play_tool_anim(&"hold_up", 0.9)
	Events.hud_message.emit("Betty's spare sail! The little boat flies along now.", 3.5)
	GameManager.quest_log_refresh()
