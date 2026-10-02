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
##   x       at            where to dig
##   label   at, text      handwritten note
## "compass" places the compass rose (fractions of the map area).

const MAPS := {
	&"castaway_map_1": {
		"island": &"castaway_cay",
		"title": "The Old Stump",
		"riddle": "Below the ridge and east of the lookout, an old stump stands alone. Dig at its feet.",
		"spot": &"castaway_x_spot",
		"frame": Rect2(-50, -4, 44, 38),
		"compass": Vector2(0.9, 0.12),
		"sketch": [
			{"kind": "cliff", "points": [Vector2(-38.2, -4), Vector2(-34, 0), Vector2(-23, 2), Vector2(-12, 4), Vector2(-6, 3.6)], "side": 1},
			{"kind": "cliff", "points": [Vector2(-50, 27.8), Vector2(-36, 32), Vector2(-26, 30), Vector2(-16, 28), Vector2(-6, 26.8)], "side": 1},
			{"kind": "tower", "at": Vector2(-40, 4)},
			{"kind": "hut", "at": Vector2(-46, 18), "color": Color("2f8fe8")},
			{"kind": "rock", "at": Vector2(-30, 4.5)},
			{"kind": "rock", "at": Vector2(-8, 22), "size": 0.8},
			{"kind": "palm", "at": Vector2(-22, 21)},
			{"kind": "stump", "at": Vector2(-29.2, 13.2)},
			{"kind": "x", "at": Vector2(-27, 15)},
			{"kind": "label", "at": Vector2(-24, -1.5), "text": "the ridge"},
			{"kind": "label", "at": Vector2(-43, 11), "text": "lookout"},
			{"kind": "label", "at": Vector2(-15, 32.5), "text": "the cove"},
		],
	},
	&"castaway_map_2": {
		"island": &"castaway_cay",
		"title": "Shellby's Old Chart",
		"riddle": "Where the sea meets the north sand, three stones stand stacked. Dig beside them.",
		"spot": &"castaway_x_north",
		"frame": Rect2(-36, -80, 48, 42),
		"compass": Vector2(0.1, 0.88),
		"sketch": [
			{"kind": "shore", "points": [Vector2(-36, -70.5), Vector2(-22, -73.5), Vector2(-8, -77.2), Vector2(2, -75.8), Vector2(12, -74.5)]},
			{"kind": "cliff", "points": [Vector2(-36, -49.3), Vector2(-24, -53.4), Vector2(-10, -58), Vector2(2, -57.2), Vector2(12, -56.4)], "side": -1},
			{"kind": "hill_mast", "at": Vector2(1, -42)},
			{"kind": "palm", "at": Vector2(-24, -60)},
			{"kind": "palm", "at": Vector2(2, -66)},
			{"kind": "cairn", "at": Vector2(-9.2, -63.4)},
			{"kind": "x", "at": Vector2(-11, -64.5)},
			{"kind": "label", "at": Vector2(-26, -76.5), "text": "open sea"},
			{"kind": "label", "at": Vector2(-24, -66.5), "text": "north sand"},
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
