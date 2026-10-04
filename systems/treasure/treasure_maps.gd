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
		"riddle": "Round the back of the Soggy Biscuit, under the lookout, an old stump stands alone. Dig at its feet.",
		"spot": &"castaway_x_spot",
		"frame": Rect2(-42, -9, 42, 40),
		"compass": Vector2(0.9, 0.12),
		"sketch": [
			{"kind": "cliff", "points": [Vector2(-42, 26.5), Vector2(-28, 27.5), Vector2(-18, 26), Vector2(-14, 27.5), Vector2(0, 27)], "side": 1},
			{"kind": "cliff", "points": [Vector2(-25, -6), Vector2(-25, 2), Vector2(-18, 4), Vector2(-6, 4.5), Vector2(0, 3)], "side": 1},
			{"kind": "tower", "at": Vector2(-12, -4)},
			{"kind": "hut", "at": Vector2(-30.5, 14), "color": Color("2f9e6e")},
			{"kind": "palm", "at": Vector2(-22, 9)},
			{"kind": "rock", "at": Vector2(-8, 22), "size": 0.8},
			{"kind": "stump", "at": Vector2(-22.6, 17)},
			{"kind": "x", "at": Vector2(-21, 19)},
			{"kind": "label", "at": Vector2(-30.5, 21.5), "text": "the tavern"},
			{"kind": "label", "at": Vector2(-12, -8), "text": "lookout"},
			{"kind": "label", "at": Vector2(-12, 30.5), "text": "the cove"},
		],
	},
	&"castaway_map_2": {
		"island": &"castaway_cay",
		"title": "Shellby's Old Chart",
		"riddle": "Where the sea meets the north sand, under the forest cliffs, three stones stand stacked. Dig beside them.",
		"spot": &"castaway_x_north",
		"frame": Rect2(-36, -104, 48, 42),
		"compass": Vector2(0.1, 0.88),
		"sketch": [
			{"kind": "shore", "points": [Vector2(-36, -95.5), Vector2(-22, -97.6), Vector2(-8, -98.2), Vector2(2, -97.6), Vector2(12, -96.4)]},
			{"kind": "cliff", "points": [Vector2(-36, -80), Vector2(-24, -80.2), Vector2(-10, -80.6), Vector2(2, -81), Vector2(12, -80.8)], "side": -1},
			{"kind": "palm", "at": Vector2(10, -88)},
			{"kind": "palm", "at": Vector2(-24, -75)},
			{"kind": "cairn", "at": Vector2(-9.2, -87.4)},
			{"kind": "x", "at": Vector2(-11, -88.5)},
			{"kind": "label", "at": Vector2(-24, -101.5), "text": "open sea"},
			{"kind": "label", "at": Vector2(-24, -90), "text": "north sand"},
			{"kind": "label", "at": Vector2(-14, -72), "text": "the forest"},
		],
	},
	# Found in the Sunken Sloop's chest: it shows an island the player has
	# already sailed past (spec §194).
	&"driftwood_map_1": {
		"island": &"driftwood_key",
		"title": "Where the Beak Points",
		"riddle": "On a little isle of driftwood, a parrot of stone keeps watch. Dig where its beak points.",
		"spot": &"driftwood_x_beak",
		"frame": Rect2(-164, 108, 68, 64),
		"compass": Vector2(0.9, 0.12),
		"sketch": [
			{"kind": "coast", "points": [Vector2(-152, 132), Vector2(-146, 120), Vector2(-130, 114), Vector2(-112, 118), Vector2(-104, 132),
				Vector2(-108, 150), Vector2(-122, 160), Vector2(-140, 160), Vector2(-152, 148)]},
			{"kind": "knoll", "points": [Vector2(-138, 128), Vector2(-128, 125), Vector2(-118, 130), Vector2(-116, 142), Vector2(-126, 149), Vector2(-137, 146)]},
			{"kind": "tower", "at": Vector2(-148.5, 144), "size": 0.8},
			{"kind": "jetty", "at": Vector2(-117, 118), "yaw": 20.0},
			{"kind": "palm", "at": Vector2(-144, 128), "size": 0.8},
			{"kind": "palm", "at": Vector2(-110, 134), "size": 0.8},
			{"kind": "palm", "at": Vector2(-130, 142), "size": 0.8},
			{"kind": "palm", "at": Vector2(-116, 152), "size": 0.8},
			{"kind": "beak_rock", "at": Vector2(-143.5, 154.0), "to": Vector2(-135.4, 152.0), "size": 0.75},
			{"kind": "x", "at": Vector2(-135.4, 152.0), "size": 0.6},
			{"kind": "label", "at": Vector2(-134, 166.5), "text": "a parrot made of stone?"},
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
