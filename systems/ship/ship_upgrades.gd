class_name ShipUpgrades
## Patchy's boat, made better (docs/ARCHIPELAGO.md, the ship). Three things
## matter at sea, and Gus the shipwright sells what Old Shellby doesn't give
## away (UIShipyard):
##  - The sail (speed): the patched sail Gus rigs, Betty's spare sail from
##    Shellby, then Gus's racing rig, quick enough to beat the currents
##    through Crocodile Crown's reef maze.
##  - The hull (toughness): copper sheathing that the boiling sea round
##    Cinder Isle can't scald, then an iron hull that rides out the storm
##    wall round Stormpeak and shrugs off knocks.
##  - A bow cannon: fire it while sailing ({tool_primary}). Brock's fort
##    guns round Cannonball Cliffs won't let a boat by that can't answer them.
## Plus the looks: sail colors, a flag and a figurehead, free to change at
## the shipyard. Everything lives in WorldState (saved with the game) and
## belongs to Patchy's ship, whichever boat that is.

## The upgrades, in the shipyard's order. "track" is what they improve and
## "level" how far; "needs" is an upgrade to have first; "price" is gold
## (0: not for sale, it comes another way).
const UPGRADES := {
	&"spare_sail": {"name": "Betty's Spare Sail", "track": &"sail", "level": 1, "price": 0,
		"blurb": "Barnacle Betty's old sail, stitched on by Old Shellby. A good deal faster."},
	&"racing_rig": {"name": "Racing Rig", "track": &"sail", "level": 2, "price": 160, "needs": &"spare_sail",
		"blurb": "A taller mast, a topsail and a jib: the fastest sail in Barnacle Bay. Quick enough to beat the currents through a reef."},
	&"copper_hull": {"name": "Copper Bottom", "track": &"hull", "level": 1, "price": 120,
		"blurb": "Copper sheathing below the waterline. Boiling water can't scald it."},
	&"iron_hull": {"name": "Iron Hull", "track": &"hull", "level": 2, "price": 220, "needs": &"copper_hull",
		"blurb": "Iron bands and a plated bow. Rides out a storm and shrugs off knocks."},
	&"bow_cannon": {"name": "Bow Cannon", "track": &"cannon", "level": 1, "price": 100,
		"blurb": "A little bronze cannon on the bow. {tool_primary} fires it while sailing. Fort guns think twice."},
}
## WorldState id of Betty's spare sail (Old Shellby's gift).
const SPARE_SAIL := &"boat_spare_sail"
## Top speed by sail level.
const SAIL_SPEED: Array[float] = [1.0, 1.3, 1.6]

## Sail colors: [name, cloth, stripe, patch, second patch]. -1 in the save
## means the sail's own colors (patchwork on the patched sail, Shellby's
## stripes on Betty's).
const SAIL_COLORS := [
	["Patchwork", Color("f3ead2"), Color("f6ecd6"), Color("e9b44c"), Color("6fb0d9")],
	["Shellby Stripes", Color("d8433a"), Color("f6ecd6"), Color("6fb0d9"), Color("e9b44c")],
	["Sunset", Color("f28c38"), Color("f6c453"), Color("d8433a"), Color("f6ecd6")],
	["Sea Foam", Color("3fb8a8"), Color("eefaf6"), Color("f6c453"), Color("d8433a")],
	["Midnight", Color("2b3a67"), Color("c9d3e6"), Color("f2c14e"), Color("d8433a")],
	["Royal Purple", Color("7a4ab8"), Color("f2c14e"), Color("eefaf6"), Color("5fd3b4")],
]
const FLAGS := ["Patchy's Pennant", "Jolly Roger", "Parrot Tail", "Sea Star", "Checkers"]
const FIGUREHEADS := ["None", "Seagull", "Crab", "Dolphin", "Golden Parrot"]
const LOOKS := {&"colors": SAIL_COLORS, &"flag": FLAGS, &"figurehead": FIGUREHEADS}
const LOOKS_ID := &"ship_looks"


static func _flag_id(id: StringName) -> StringName:
	return SPARE_SAIL if id == &"spare_sail" else StringName("ship_" + String(id))


static func has(id: StringName) -> bool:
	return WorldState.is_completed(_flag_id(id))


## Fits an upgrade for nothing (Shellby's gift, tests, the debug menu).
static func grant(id: StringName) -> void:
	if UPGRADES.has(id):
		WorldState.mark_completed(_flag_id(id))


## Takes an upgrade off again (tests, the debug menu).
static func revoke(id: StringName) -> void:
	if UPGRADES.has(id) and has(id):
		WorldState.set_flag(_flag_id(id), "completed", false)


static func price(id: StringName) -> int:
	return int(UPGRADES.get(id, {}).get("price", 0))


static func display_name(id: StringName) -> String:
	return String(UPGRADES.get(id, {}).get("name", id))


## What stands in the way of buying `id` ("" when nothing does).
static func why_not(id: StringName) -> String:
	if not UPGRADES.has(id):
		return "?"
	if has(id):
		return "Fitted"
	var u: Dictionary = UPGRADES[id]
	if int(u.price) <= 0:
		return "Not for sale"
	var needs := StringName(u.get("needs", &""))
	if needs != &"" and not has(needs):
		return "Needs %s" % display_name(needs)
	if InventoryManager.gold_value < int(u.price):
		return "Not enough gold"
	return ""


## Pays for and fits an upgrade. False (and nothing spent) when it can't.
static func buy(id: StringName) -> bool:
	if why_not(id) != "" or not InventoryManager.spend_gold(price(id)):
		return false
	grant(id)
	return true


static func _level(track: StringName) -> int:
	var best := 0
	for id: StringName in UPGRADES:
		var u: Dictionary = UPGRADES[id]
		if u.track == track and has(id):
			best = maxi(best, int(u.level))
	return best


static func sail_level() -> int:
	return _level(&"sail")


static func hull_level() -> int:
	return _level(&"hull")


static func has_cannon() -> bool:
	return has(&"bow_cannon")


static func speed_multiplier() -> float:
	return SAIL_SPEED[clampi(sail_level(), 0, SAIL_SPEED.size() - 1)]


# --- Looks ---------------------------------------------------------------------------

## The chosen look for `slot` (&"colors", &"flag", &"figurehead"); -1 for
## the sail's own colors.
static func look(slot: StringName) -> int:
	return int(WorldState.get_flag(LOOKS_ID, String(slot), -1 if slot == &"colors" else 0))


static func set_look(slot: StringName, index: int) -> void:
	var n: int = (LOOKS[slot] as Array).size()
	WorldState.set_flag(LOOKS_ID, String(slot), posmod(index, n))


## The sail colors in use: the chosen ones, or the sail's own.
static func sail_colors(level: int, chosen: int) -> int:
	if chosen >= 0:
		return chosen
	return 0 if level == 0 else 1


static func look_name(slot: StringName, index: int) -> String:
	var list: Array = LOOKS[slot]
	var e: Variant = list[posmod(index, list.size())]
	return String(e[0]) if e is Array else String(e)


## Everything a BoatModel needs to draw Patchy's boat as it is now.
static func spec() -> Dictionary:
	var level := sail_level()
	return {
		"sail": level,
		"hull": hull_level(),
		"cannon": has_cannon(),
		"colors": sail_colors(level, look(&"colors")),
		"flag": look(&"flag"),
		"figurehead": look(&"figurehead"),
	}


## Whether a WorldState id is one of these (so a boat knows to redraw).
static func is_ship_state(id: StringName) -> bool:
	return id == LOOKS_ID or id == SPARE_SAIL or String(id).begins_with("ship_")
