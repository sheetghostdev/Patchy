class_name TreasureMaps
## Every treasure map in the game (spec §86): the island it belongs to, a
## title, a short riddle, the dig spot it leads to, and the sketch inked on
## the parchment. Sketches are landmark doodles placed in the island's own
## top-down x/z coordinates inside `frame`, with north at the top, so the
## drawing matches the place. There are no coordinates on the paper: the
## player has to recognise the spot (spec §87).
##
## Sketch items: {kind, at | points, ...}
##   shore   points        coastline, sea to the north of the line
##   cliff   points, side  hatched cliff edge (side: 1 = drop to the south)
##   palm / hut / tower / stump / rock / cairn / hill_mast   at
##   coast   points        a whole island's shoreline (closed), sea all round
##   knoll   points        a raised, hatched rise (closed)
##   jetty   at, yaw       a little wooden jetty
##   beak_rock  at         the parrot-headed rock on Driftwood Key
##   x       at            where to dig
##   label   at, text      handwritten note
## "compass" places the compass rose (fractions of the map area).

const MAPS := {
	&"castaway_map_1": {
		"island": &"castaway_cay",
		"title": "The Old Stump",
		"riddle": "Round the back of the Soggy Biscuit, above the harbor, an old stump stands alone. Dig at its feet.",
		"spot": &"castaway_x_spot",
		"frame": Rect2(-102, 14, 54, 48),
		"compass": Vector2(0.9, 0.12),
		"sketch": [
			{"kind": "cliff", "points": [Vector2(-102, 24.6), Vector2(-90, 23.4), Vector2(-79, 20.6), Vector2(-72, 14)], "side": 1},
			{"kind": "cliff", "points": [Vector2(-102, 54.2), Vector2(-88, 54.8), Vector2(-74, 56), Vector2(-60, 56), Vector2(-52, 50), Vector2(-48, 48.6)], "side": 1},
			{"kind": "hut", "at": Vector2(-91, 25.6), "color": Color("2f9e6e")},
			{"kind": "hut", "at": Vector2(-76, 40), "color": Color("2f9e6e")},
			{"kind": "palm", "at": Vector2(-100, 52)},
			{"kind": "stump", "at": Vector2(-68.6, 44.4)},
			{"kind": "x", "at": Vector2(-67, 46.6)},
			{"kind": "label", "at": Vector2(-84, 33.5), "text": "the tavern"},
			{"kind": "label", "at": Vector2(-96, 42), "text": "the plaza"},
			{"kind": "label", "at": Vector2(-76, 60), "text": "the harbor"},
		],
	},
	&"castaway_map_2": {
		"island": &"castaway_cay",
		"title": "Shellby's Old Chart",
		"riddle": "Where the sea meets the north sand, under the cliffs of the woods, three stones stand stacked. Dig beside them.",
		"spot": &"castaway_x_north",
		"frame": Rect2(-34, -152, 58, 46),
		"compass": Vector2(0.1, 0.88),
		"sketch": [
			{"kind": "shore", "points": [Vector2(-34, -141.4), Vector2(-20, -143), Vector2(-4, -144), Vector2(10, -144.6), Vector2(24, -144)]},
			{"kind": "cliff", "points": [Vector2(-34, -115.4), Vector2(-18, -115.6), Vector2(-2, -116.4), Vector2(10, -117), Vector2(24, -115.8)], "side": -1},
			{"kind": "palm", "at": Vector2(-30, -134)},
			{"kind": "rock", "at": Vector2(-14, -120), "size": 1.1},
			{"kind": "cairn", "at": Vector2(9.8, -129.9)},
			{"kind": "x", "at": Vector2(8, -131)},
			{"kind": "label", "at": Vector2(-10, -149), "text": "open sea"},
			{"kind": "label", "at": Vector2(-8, -133), "text": "north sand"},
			{"kind": "label", "at": Vector2(4, -110), "text": "the woods"},
		],
	},
	# Found in the Sunken Sloop's chest: it shows an island the player has
	# already sailed past (spec §194).
	&"driftwood_map_1": {
		"island": &"driftwood_key",
		"title": "Where the Beak Points",
		"riddle": "On a little isle of driftwood, a parrot of stone keeps watch. Dig where its beak points.",
		"spot": &"driftwood_x_beak",
		"frame": Rect2(-284, 198, 68, 64),
		"compass": Vector2(0.9, 0.12),
		"sketch": [
			{"kind": "coast", "points": [Vector2(-272, 222), Vector2(-266, 210), Vector2(-250, 204), Vector2(-232, 208), Vector2(-224, 222),
				Vector2(-228, 240), Vector2(-242, 250), Vector2(-260, 250), Vector2(-272, 238)]},
			{"kind": "knoll", "points": [Vector2(-258, 218), Vector2(-248, 215), Vector2(-238, 220), Vector2(-236, 232), Vector2(-246, 239), Vector2(-257, 236)]},
			{"kind": "tower", "at": Vector2(-268.5, 234), "size": 0.8},
			{"kind": "jetty", "at": Vector2(-237, 208), "yaw": 20.0},
			{"kind": "palm", "at": Vector2(-264, 218), "size": 0.8},
			{"kind": "palm", "at": Vector2(-230, 224), "size": 0.8},
			{"kind": "palm", "at": Vector2(-250, 232), "size": 0.8},
			{"kind": "palm", "at": Vector2(-236, 242), "size": 0.8},
			{"kind": "beak_rock", "at": Vector2(-263.5, 244), "to": Vector2(-255.4, 242), "size": 0.75},
			{"kind": "x", "at": Vector2(-255.4, 242), "size": 0.6},
			{"kind": "label", "at": Vector2(-254, 256.5), "text": "a parrot made of stone?"},
		],
	},
}


static func has_map(id: StringName) -> bool:
	return MAPS.has(id)


static func get_map(id: StringName) -> Dictionary:
	return MAPS.get(id, {})


static func island_of(id: StringName) -> StringName:
	return StringName(get_map(id).get("island", &""))


static func for_island(island: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in MAPS:
		if MAPS[id]["island"] == island:
			out.append(id)
	return out


## True once the map's treasure has been dug up.
static func is_solved(id: StringName) -> bool:
	var spot: StringName = get_map(id).get("spot", &"")
	return spot != &"" and WorldState.is_completed(spot)
