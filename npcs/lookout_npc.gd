@tool
class_name LookoutNPC
extends NPC
## A lookout with a spyglass (spec §104: parrot locations as a reward for
## talking to people). Every chat ends with a tip about the first cage on
## `cage_hints` that is still locked, so asking again always helps.

## "cage_id|Where to look" entries, in the order Tok points them out.
@export var cage_hints: PackedStringArray = PackedStringArray()
## Said once every cage on the list is open.
@export var all_free_lines: PackedStringArray = PackedStringArray(["Not a cage in sight!"])


func get_lines() -> PackedStringArray:
	var out := PackedStringArray()
	if _times == 0:
		out.append_array(lines)
	elif not repeat_lines.is_empty():
		out.append(repeat_lines[_times % repeat_lines.size()])
	var hint := next_hint()
	if hint != "":
		out.append(hint)
	else:
		out.append_array(all_free_lines)
	return out


## The tip for the first listed cage that is still locked ("" if none).
func next_hint() -> String:
	for entry in cage_hints:
		var parts := entry.split("|", true, 1)
		if parts.size() == 2 and not ParrotManager.is_rescued(StringName(parts[0])):
			return parts[1]
	return ""
