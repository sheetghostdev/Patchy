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
	q.append({"title": "Recover the Ship's Compass", "description": "A piece of your ship glints atop the hill.", "done": InventoryManager.has_ship_part(&"compass")})
	if GameManager.is_island_discovered(&"driftwood_key") or parrots >= 3:
		q.append({"title": "Sail to Driftwood Key", "description": "Your little boat waits at the dock. It floats... mostly.", "done": GameManager.is_island_discovered(&"driftwood_key")})
	q.append({"title": "A Light in the Dark", "description": "The cave on the ridge is too dark to explore. Find a lantern.", "done": InventoryManager.has_attachment(&"lantern")})
	if InventoryManager.has_attachment(&"lantern"):
		q.append({"title": "Light the Old Braziers", "description": "Something waits behind the gate in the dark cave.", "done": WorldState.is_completed(&"castaway_cave_gate")})
	q.append({"title": "Bridge the Gorge", "description": "A big enough flock could lift the fallen log across to the headland.", "done": WorldState.is_completed(&"castaway_log_bridge")})
	if InventoryManager.has_treasure_map(&"castaway_map_1"):
		q.append({"title": "X Marks the Spot", "description": "Unroll your treasure map (Pause, Treasure), find the place it sketches, and dig.", "done": WorldState.is_completed(&"castaway_x_spot")})
	if WorldState.is_completed(&"castaway_log_bridge"):
		q.append({"title": "Defeat King Claw", "description": "Brock's crab general waits in the ring of rocks on the headland.", "done": WorldState.is_completed(&"king_claw")})
	if WorldState.is_completed(&"brock_cameo_seen"):
		q.append({"title": "Brock the Croc", "description": "The self-styled Admiral of the Archipelago has scattered the rest of your ship across his islands. The adventure continues...", "done": false})
		q.append({"title": "Set Sail", "description": "Your little patched sail can't fight the open-sea current. Old Shellby, out on his west jetty, might have a spare.",
			"done": TinyBoat.has_spare_sail()})
	if TinyBoat.has_spare_sail():
		var beyond := GameManager.get_discovered_islands().any(func(id: StringName) -> bool: return id not in [&"castaway_cay", &"driftwood_key", &"captains_cabin"])
		q.append({"title": "Beyond the Horizon", "description": "Betty's spare sail can carry the little boat to the islands on the horizon. Sail out past the reef with one dead ahead.",
			"done": beyond})
	# Side quests, once an islander has asked.
	var lifted := WorldState.is_completed(&"castaway_betty_lift")
	if WorldState.is_completed(&"castaway_betty_quest") or lifted:
		q.append({"title": "The Barnacle Betty",
			"description": "Betty's home! See what Old Shellby has for you." if lifted
				else "Crabs dragged Old Shellby's boat off up the west beach. Follow the drag marks.",
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
