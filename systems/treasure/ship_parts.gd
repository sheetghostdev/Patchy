class_name ShipParts
## The pieces of the Patchy that Patchy wins back (spec §78): the order the
## cabin shelf shows them in, their names, and the island each is found on
## ("" for islands not built yet).

const PARTS := [
	{"id": &"compass", "name": "Ship's Compass", "island": &"castaway_cay"},
	{"id": &"ships_wheel", "name": "Ship's Wheel", "island": &"castaway_cay"},
	{"id": &"figurehead", "name": "Figurehead", "island": &""},
	{"id": &"cannon_deck", "name": "Cannon Deck", "island": &""},
	{"id": &"sails", "name": "Sails", "island": &""},
]


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in PARTS:
		out.append(p["id"])
	return out


static func display_name(id: StringName) -> String:
	for p: Dictionary in PARTS:
		if p["id"] == id:
			return p["name"]
	return String(id).capitalize()


static func island_of(id: StringName) -> StringName:
	for p: Dictionary in PARTS:
		if p["id"] == id:
			return p["island"]
	return &""


static func for_island(island: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in PARTS:
		if p["island"] == island:
			out.append(p["id"])
	return out
