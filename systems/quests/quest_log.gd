class_name QuestLog
extends Node
## The captain's log of goals (spec §124): derived from progress, never
## stored. Rebuilt whenever something meaningful happens and handed to the
## pause menu's Quests page (UI.set_quests). Lives under GameManager.

const PARROTS_NEEDED := 6


func _ready() -> void:
	for sig: Signal in [Events.parrot_rescued, Events.ship_part_recovered, Events.boss_defeated, Events.attachment_unlocked,
			Events.world_task_completed, Events.treasure_map_found, Events.island_discovered, Events.treasure_collected]:
		sig.connect(func(_a = null, _b = null, _c = null) -> void: refresh.call_deferred())
	refresh.call_deferred()


func refresh() -> void:
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"set_quests"):
		ui.call(&"set_quests", build())


## [{title, description, done}] in story order; future goals stay hidden
## until their tease has happened.
static func build() -> Array:
	var q: Array = []
	var parrots := ParrotManager.get_total()
	q.append({"title": "Wash Ashore", "description": "Brock's crabs are hauling off your gold. Chase them down!", "done": WorldState.is_completed(&"castaway_intro_seen")})
	q.append({"title": "Free the Parrots (%d / %d)" % [mini(parrots, PARROTS_NEEDED), PARROTS_NEEDED],
		"description": "Brock caged parrots all over Castaway Cay and its neighbor. They never forget a friend.",
		"done": parrots >= PARROTS_NEEDED})
	var dinghy := WorldState.is_completed(&"castaway_dinghy")
	var still: Array[String] = []
	if not WorldState.is_completed(&"dinghy_sail"):
		still.append("the sail (up Tok's lookout tower)")
	if not WorldState.is_completed(&"dinghy_tiller"):
		still.append("the tiller (sunk off the end of the pier)")
	var asked := WorldState.is_completed(&"castaway_dinghy_quest")
	q.append({"title": "A Boat of Your Own",
		"description": "Gus's old dinghy is yours. She's moored at the end of the pier, and Gus will fit her out for gold." if dinghy
			else ("Gus the shipwright will fix up his old dinghy for you. Still to find: %s." % " and ".join(PackedStringArray(still)) if asked and not still.is_empty()
			else ("Take the sail and the tiller to Gus at the shipyard." if asked
			else "Gus the shipwright in Barnacle Bay might have a boat for a castaway.")),
		"done": dinghy})
	q.append({"title": "Recover the Ship's Compass", "description": "A piece of your ship glints on the forest summit, over the rope bridge.", "done": InventoryManager.has_ship_part(&"compass")})
	if dinghy or GameManager.is_island_discovered(&"driftwood_key"):
		q.append({"title": "Sail to Driftwood Key", "description": "South-west of the harbor, a little islet of driftwood. Your dinghy floats... mostly.", "done": GameManager.is_island_discovered(&"driftwood_key")})
	q.append({"title": "A Light in the Dark", "description": "The cave in the forest is too dark to explore. Find a lantern.", "done": InventoryManager.has_attachment(&"lantern")})
	if InventoryManager.has_attachment(&"lantern"):
		q.append({"title": "Light the Old Braziers", "description": "Something waits behind the gate in the dark cave.", "done": WorldState.is_completed(&"castaway_cave_gate")})
	q.append({"title": "Bridge the Gorge", "description": "A big enough flock could lift the fallen log in the forest across the gorge to the headland.", "done": WorldState.is_completed(&"castaway_log_bridge")})
	if InventoryManager.has_treasure_map(&"castaway_map_1"):
		q.append({"title": "X Marks the Spot", "description": "Unroll your treasure map (Pause, Treasure), find the place it sketches, and dig.", "done": WorldState.is_completed(&"castaway_x_spot")})
	if WorldState.is_completed(&"castaway_log_bridge"):
		q.append({"title": "Defeat King Claw", "description": "Brock's crab general waits in the ring of rocks on the headland.", "done": WorldState.is_completed(&"king_claw")})
	if WorldState.is_completed(&"brock_cameo_seen"):
		q.append({"title": "Brock the Croc", "description": "The self-styled Admiral of the Archipelago has scattered the rest of your ship across his islands. The adventure continues...", "done": false})
		var beyond := GameManager.get_discovered_islands().any(func(id: StringName) -> bool: return id not in [&"castaway_cay", &"driftwood_key", &"captains_cabin"])
		q.append({"title": "Beyond the Horizon", "description": "Every island you can see lies out there across the open sea. Point the bow at one and sail!",
			"done": beyond})
		q.append({"title": "A Bigger Sail", "description": "Your little patched sail gets there... eventually. Old Shellby, out on his west jetty, might have a spare.",
			"done": TinyBoat.has_spare_sail()})
	# Side quests, once an islander has asked.
	var lifted := WorldState.is_completed(&"castaway_betty_lift")
	if WorldState.is_completed(&"castaway_betty_quest") or lifted:
		q.append({"title": "The Barnacle Betty",
			"description": "Betty's home! See what Old Shellby has for you." if lifted
				else "Crabs dragged Old Shellby's boat off along the west beach. Follow the drag marks.",
			"done": WorldState.is_completed(&"castaway_betty_reward")})
	if InventoryManager.has_treasure_map(&"castaway_map_2"):
		q.append({"title": "Shellby's Old Chart", "description": "Shellby's chart sketches a spot somewhere on Castaway Cay. Find it and dig.", "done": WorldState.is_completed(&"castaway_x_north")})
	if InventoryManager.has_treasure_map(&"driftwood_map_1"):
		q.append({"title": "Where the Beak Points", "description": "The Sunken Sloop's soggy map sketches an island that isn't Castaway Cay. Haven't you sailed past it somewhere?",
			"done": WorldState.is_completed(&"driftwood_x_beak")})
	if WorldState.is_completed(&"driftwood_met_pip"):
		q.append({"title": "Pip's Lucky Clam", "description": "A pelican swiped Pip's clam on Driftwood Key. Bop it when it swoops low!",
			"done": WorldState.is_completed(&"driftwood_pip_reward")})
	return q
