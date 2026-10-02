class_name UIAttachmentInfo
## Presentation data for Patchy's hand attachments: display names, one-line
## descriptions and icon ids (icons are drawn by UIIcons). Gameplay owns the
## behavior; add an entry here when a new attachment is created.

const ORDER: Array[StringName] = [
	&"hook", &"grapple", &"shovel", &"cannon", &"lantern", &"harpoon", &"spring_fist",
]

const DATA := {
	&"hook": {
		"name": "Hook",
		"description": "Patchy's trusty hand. Swipe at foes and swing from golden rings.",
	},
	&"grapple": {
		"name": "Grapple",
		"description": "Throws a rope to far anchors and reels Patchy across gaps.",
	},
	&"shovel": {
		"name": "Shovel",
		"description": "Digs up buried treasure wherever the sand sparkles.",
	},
	&"cannon": {
		"name": "Hand Cannon",
		"description": "Lobs cannonballs that crack walls and ring far-off bells.",
	},
	&"lantern": {
		"name": "Lantern",
		"description": "Lights dark caves and reveals glowing secrets.",
	},
	&"harpoon": {
		"name": "Harpoon",
		"description": "Spears distant targets and drags light objects closer.",
	},
	&"spring_fist": {
		"name": "Spring Fist",
		"description": "A boxing glove on a spring: punches switches and bounces Patchy high.",
	},
}


static func has_info(id: StringName) -> bool:
	return DATA.has(id)


static func display_name(id: StringName) -> String:
	if DATA.has(id):
		return String(DATA[id]["name"])
	return String(id).capitalize()


static func description(id: StringName) -> String:
	if DATA.has(id):
		return String(DATA[id]["description"])
	return ""


## Icon id for UIIcons (attachments use their own id).
static func icon(id: StringName) -> StringName:
	return id if id in UIIcons.ATTACHMENT_IDS else &"question"


## All known attachment ids in display order, including unknown extras.
static func all_ids(extra: Array = []) -> Array[StringName]:
	var out: Array[StringName] = ORDER.duplicate()
	for e: Variant in extra:
		var id := StringName(e)
		if not id in out:
			out.append(id)
	return out
