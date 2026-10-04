extends IslandBuilder
## Generates res://world/islands/castaway_cay/castaway_cay.tscn: the opening
## island (spec §72–77, §146–153; docs/ARCHIPELAGO.md), Patchy's Outset.
## He washes up after the storm on an inhabited pirate fishing island, with
## his ship's stern beached on its south shore and his treasure scattered.
##
## Layout (x east, z south, sea level y = 0):
##  - South: the cove where Patchy wakes, Wreck Beach and his beached stern
##    (the captain's cabin, parrot #1 in its crow's nest, parrot #4 on the
##    sea stack), and the meadow above them.
##  - South-west: Barnacle Bay, the village round its harbor. The quay and
##    the pier, the plaza with its well and stalls, the Soggy Biscuit (walk
##    in: Auntie Ink keeps it), Gus's shipyard with the old dinghy up on
##    trestles, the upper terrace of houses, and the bluff with Tok's
##    lookout tower (parrot #2, and the dinghy's sail).
##  - A sea channel cuts the island in two; a rope bridge crosses it from
##    the bluff to the forest.
##  - North: the forest plateau, its summit (the Ship's Compass, parrot #3)
##    and the dark cave; across the gorge (the six-parrot log bridge) the
##    headland, with the chained chest, Brock's crocs and King Claw's ring.
##    Under the cliffs, the north beach.
##  - West: Gull Rock and Old Shellby's jetty (the Barnacle Betty).
##  - Off the coast: the Sunken Sloop, Gull Bar and Driftwood Key.
##   tools/builders/build.sh castaway_cay world

const ISLAND := &"castaway_cay"
const ISLET := &"driftwood_key"
## Driftwood Key: a small neighbor islet south-west of the harbor (by boat).
const DRIFTWOOD := Vector3(-130, 0, 140)
## Heights of the island's levels.
const SAND := 1.2
const QUAY := 1.6
const LOW := 3.0
const UPPER := 6.6
const BLUFF := 10.4
const FOREST := 13.0
const SUMMIT := 18.4
## The forest's summit and cave were laid out on an older ridge; they keep
## their shape, moved up and north onto the forest (and the headland too).
const NORTH := Vector3(-8, 6, -18)
const HEAD := Vector3(8, 5.5, -19)
## Patchy's boat ties up at the end of the pier (build_world.gd puts it there).
const MOORING := Vector3(-44.6, 0, 58)
## The lookout tower on the bluff.
const TOWER := Vector3(-12, BLUFF, -4)
const DINGHY := &"castaway_dinghy"
const FOREST_OUTLINE := [Vector2(-76, -29), Vector2(-50, -27.5), Vector2(-24, -28), Vector2(0, -27), Vector2(22, -28.5),
	Vector2(25, -40), Vector2(24.5, -56), Vector2(25, -70), Vector2(22, -80), Vector2(0, -81), Vector2(-30, -80), Vector2(-56, -80),
	Vector2(-72, -72), Vector2(-80, -58), Vector2(-80, -42)]


func build() -> void:
	# Deterministic builds: regenerating the island gives an identical scene.
	seed(20261002)
	island_id = ISLAND
	b = SceneBuilder.new("CastawayCay")
	var info := IslandInfo.new()
	info.island_id = ISLAND
	info.display_name = "Castaway Cay"
	info.music = &"castaway_explore"
	info.sub_islands = [ISLET]
	b.add(info, null, "IslandInfo")
	terrain = b.group("Terrain")
	structures = b.group("Structures")
	gameplay = b.group("Gameplay")
	treasure = b.group("Treasure")
	enemies = b.group("Enemies")

	_terrain()
	_sea()
	_cove()
	_shipwreck()
	_village()
	_tavern()
	_harbor()
	_shipyard()
	_bluff()
	_lookout()
	_forest()
	_cave()
	_gorge_and_headland()
	_ring_run()
	_coins()
	_checkpoints()
	_driftwood_key()
	_sea_regions()
	_decorate()
	_hints()
	_barnacle_betty()
	_islanders()
	_crossing()
	_brock_cameo()
	_grotto_mischief()
	_sunken_reef()
	_beak_rock()
	_opening()
	b.save("res://world/islands/castaway_cay/castaway_cay.tscn")


# --- Helpers ------------------------------------------------------------------------

func _n(v: Vector3) -> Vector3:
	return v + NORTH


func _h(v: Vector3) -> Vector3:
	return v + HEAD


func _shift(pts: Array, by: Vector3) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p + Vector2(by.x, by.z))
	return out


## Stairs (or a ramp) from `from` (its foot, on the lower level) up to `to`
## (its head, on the upper level).
func steps(parent: Node, from: Vector3, to: Vector3, width: float, node_name: String, shape: LevelBlock.Shape = LevelBlock.Shape.STAIRS, surface := "wood") -> LevelBlock:
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var mid := Vector3((from.x + to.x) * 0.5, from.y, (from.z + to.z) * 0.5)
	var block := blk(parent, mid, Vector3(width, to.y - from.y, flat.length()), surface, Vector3(0, rad_to_deg(Player.yaw_of(flat)), 0), shape, node_name)
	block.step_count = clampi(roundi((to.y - from.y) / 0.32), 2, 40)
	return block


func _checkpoint(parent: Node, id: String, pos: Vector3, yaw: float, node_name: String) -> Checkpoint:
	var cp := Checkpoint.new()
	cp.checkpoint_id = StringName(id)
	cp.position = pos
	cp.respawn_yaw = yaw
	b.add(cp, parent, node_name)
	return cp


func tree(parent: Node, pos: Vector3, height: float, crown: float, tint: int, tree_seed: int) -> BroadleafTree:
	var t := BroadleafTree.new()
	t.height = height
	t.crown_radius = crown
	t.tint = tint
	t.seed = tree_seed
	t.position = pos
	b.add(t, parent, "Tree")
	return t


func _house(parent: Node, node_name: String, pos: Vector3, yaw: float, opts: Dictionary) -> VillageHouse:
	var h := VillageHouse.new()
	for k: String in opts:
		h.set(k, opts[k])
	h.position = pos
	h.rotation_degrees.y = yaw
	b.add(h, parent, node_name)
	return h


# --- Terrain ------------------------------------------------------------------------

func _terrain() -> void:
	# The south half's sandy coast: the cove, Wreck Beach, the harbor's
	# shores (the bay cut into the south-west) and the west beach. Its north
	# edge runs under the higher ground so the shore slope stays inside it.
	plateau(terrain, "Beach", [Vector2(-80, 4), Vector2(-40, 5), Vector2(0, 5), Vector2(40, 4), Vector2(80, 3), Vector2(92, 5),
		Vector2(95, 16), Vector2(88, 30), Vector2(76, 42), Vector2(64, 54), Vector2(50, 58), Vector2(34, 58), Vector2(22, 50),
		Vector2(12, 48), Vector2(0, 50), Vector2(-10, 51), Vector2(-18, 46), Vector2(-26, 37), Vector2(-30, 31.5), Vector2(-40, 30.5),
		Vector2(-56, 30.5), Vector2(-66, 32), Vector2(-70, 40), Vector2(-72, 54), Vector2(-76, 64), Vector2(-86, 60), Vector2(-94, 46),
		Vector2(-99, 30), Vector2(-100, 16), Vector2(-94, 5)], SAND, 10.0, "sand", {"shore": true, "shore_width": 16.0, "shore_drop": 5.0})
	# The lowlands: the village's lower lanes and plaza, the meadow above the
	# cove and the grassy strip along the channel east to the wreck. Their
	# north edge is the channel's south wall.
	plateau(terrain, "Lowlands", [Vector2(-74, -12), Vector2(-50, -13.5), Vector2(-24, -12.5), Vector2(0, -13), Vector2(24, -12),
		Vector2(50, -13.5), Vector2(76, -12.5), Vector2(88, -9), Vector2(90, -2), Vector2(84, 5), Vector2(70, 7.5), Vector2(50, 8.5),
		Vector2(30, 8.5), Vector2(26, 14), Vector2(25, 23), Vector2(14, 26.5), Vector2(0, 27), Vector2(-14, 27.5), Vector2(-18, 26),
		Vector2(-28, 27.5), Vector2(-40, 26.5), Vector2(-56, 26.5), Vector2(-70, 25), Vector2(-76, 18), Vector2(-78, 6), Vector2(-77, -6)],
		LOW, 16.0, "cliff", {"seed": 3})
	# The upper village terrace, backing onto the channel.
	plateau(terrain, "UpperVillage", [Vector2(-73, -11), Vector2(-50, -12.5), Vector2(-26, -11.5), Vector2(-24.5, -4), Vector2(-25, 5),
		Vector2(-36, 7), Vector2(-50, 6.6), Vector2(-64, 7), Vector2(-72, 4), Vector2(-75, -4)], UPPER, 20.0, "cliff", {"seed": 5})
	# The bluff: the lookout tower's rock and the rope bridge's south end.
	plateau(terrain, "Bluff", [Vector2(-25, -11.5), Vector2(-12, -12.5), Vector2(2, -12), Vector2(5, -6), Vector2(4, 2), Vector2(-6, 4.5),
		Vector2(-18, 4), Vector2(-25, 2)], BLUFF, 24.0, "cliff", {"seed": 7})
	# North of the channel: the forest plateau (sheer all round) and, across
	# the gorge, the headland (no wall kicks: the log bridge only).
	plateau(terrain, "Forest", FOREST_OUTLINE, FOREST, 26.0, "cliff", {"seed": 9})
	plateau(terrain, "Headland", [Vector2(43, -28.5), Vector2(60, -27.5), Vector2(80, -29), Vector2(90, -36), Vector2(92, -52),
		Vector2(88, -66), Vector2(76, -75), Vector2(58, -77), Vector2(45, -72), Vector2(42, -58), Vector2(42.5, -42)], FOREST, 26.0, "cliff",
		{"seed": 13, "no_wall_kick": true})
	# The north beach under the forest's cliffs.
	plateau(terrain, "NorthBeach", [Vector2(-66, -68), Vector2(-20, -66), Vector2(22, -66), Vector2(30, -80), Vector2(28, -92),
		Vector2(10, -97), Vector2(-20, -98), Vector2(-50, -95), Vector2(-68, -88), Vector2(-74, -76)], SAND, 10.0, "sand",
		{"shore": true, "shore_width": 14.0, "shore_drop": 5.0, "seed": 15})
	# The summit and its stepping terraces (1.8 m steps).
	plateau(terrain, "Hill", _shift([Vector2(-26, -30), Vector2(-20, -42), Vector2(-6, -46), Vector2(6, -42), Vector2(8, -30),
		Vector2(-4, -24), Vector2(-18, -22)], NORTH), SUMMIT, 5.6, "cliff", {"seed": 5})
	plateau(terrain, "Terrace1", _shift([Vector2(-36, -26), Vector2(-29, -31), Vector2(-23, -27), Vector2(-25, -18), Vector2(-33, -18)], NORTH),
		FOREST + 1.8, 2.0, "cliff", {"seed": 7})
	plateau(terrain, "Terrace2", _shift([Vector2(-24, -21), Vector2(-15, -23), Vector2(-10, -19), Vector2(-13, -12), Vector2(-21, -13)], NORTH),
		FOREST + 3.6, 3.8, "cliff", {"seed": 9})
	# Summit slide: a sandy chute from the summit back down to the forest.
	var chute := steps(terrain, Vector3(-47, FOREST - 0.05, -57), Vector3(-32.5, SUMMIT, -55), 5.0, "SummitSlide", LevelBlock.Shape.RAMP, "sand")
	chute.slide_surface = true
	# The cove's horn of rock and the gem pillar off it (the ring run).
	plateau(terrain, "Horn", [Vector2(-12, 46), Vector2(-6, 44), Vector2(-2, 49), Vector2(-6, 54), Vector2(-12, 52)], 4.5, 8.0, "rock", {"seed": 21})
	plateau(terrain, "GemPillar", [Vector2(14, 62), Vector2(19, 61), Vector2(21, 65), Vector2(17, 68), Vector2(13, 66)], 4.0, 12.0, "rock", {"seed": 23})


func _sea() -> void:
	# Sandy seabed so the water shades consistently (the ocean is the world's).
	blk(terrain, Vector3(0, -11, 0), Vector3(560, 1, 560), "sand", Vector3.ZERO, LevelBlock.Shape.BOX, "Seabed")


func _sea_regions() -> void:
	var home := SeaRegion.new()
	home.region_name = "Castaway Cay"
	home.island_id = ISLAND
	home.radius = 122.0
	home.position = Vector3(-4, 0, -14)
	home.boat_dock = structures.get_node("Harbor/BoatMooring")
	home.arrival = gameplay.get_node("PierArrival")
	b.add(home, gameplay, "SeaRegionCastaway")
	var islet := SeaRegion.new()
	islet.region_name = "Driftwood Key"
	islet.island_id = ISLET
	islet.radius = 36.0
	islet.position = DRIFTWOOD
	islet.boat_dock = gameplay.get_node("DriftwoodKey/BoatLanding")
	var islet_arrival := Marker3D.new()
	islet_arrival.position = DRIFTWOOD + Vector3(12.0, 1.3, -24.0)
	islet_arrival.rotation_degrees.y = 200.0
	b.add(islet_arrival, gameplay, "DriftwoodArrival")
	islet.arrival = islet_arrival
	b.add(islet, gameplay, "SeaRegionDriftwood")
	var zone := IslandZone.new()
	zone.island_id = ISLAND
	zone.display_name = "Castaway Cay"
	zone.announce = false
	zone.size = Vector3(220, 60, 190)
	zone.position = Vector3(-5, 10, -16)
	b.add(zone, gameplay, "IslandZoneCastaway")


# --- The south shore ----------------------------------------------------------------

func _cove() -> void:
	var burrow := CrabBurrow.new()
	burrow.position = Vector3(34, SAND, 28)
	b.add(burrow, gameplay, "CoveBurrow")
	# The coin arc that teaches the first jump up off the beach.
	coin_trail(Vector3(-2.5, SAND, 30.0), Vector3(-2.5, LOW, 24), 6, 2.2)
	heart(Vector3(-8, LOW + 0.6, 18))
	# A grassy ramp up to the meadow for the cautious.
	steps(terrain, Vector3(18, SAND - 0.05, 32.5), Vector3(18, LOW, 26.0), 6.0, "MeadowRamp", LevelBlock.Shape.RAMP, "grass")
	var sign := Signpost.new()
	sign.texts = PackedStringArray(["Barnacle Bay", "Wreck Beach", "Lookout"])
	sign.directions = PackedFloat32Array([90.0, -90.0, 30.0])
	sign.post_height = 2.6
	sign.position = Vector3(-4, SAND, 36)
	b.add(sign, structures, "CoveSign")


func _shipwreck() -> void:
	var g := b.group("Shipwreck", structures)
	# Patchy's ship's stern half, beached and tilted: run up the deck, hop
	# onto the cabin roof, then up into the crow's nest (parrot #1).
	blk(g, Vector3(44, SAND, 38), Vector3(5.0, 3.0, 10.0), "wood", Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "SternDeck")
	for side: float in [-1.0, 1.0]:
		blk(g, Vector3(44, SAND, 38 + side * 2.68), Vector3(0.35, 3.7, 10.0), "wood_dark", Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "HullSide")
	blk(g, Vector3(51.25, SAND, 38), Vector3(4.5, 4.8, 5.7), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "Cabin")
	blk(g, Vector3(51.25, 6.0, 38), Vector3(4.9, 0.25, 6.1), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "CabinRoof")
	# The captain's cabin door: the hub where treasure, parrots and ship parts
	# are on display.
	var cabin_door := SceneDoor.new()
	cabin_door.target_scene = GameManager.get_island_scene(&"captains_cabin")
	cabin_door.spawn_id = &"door"
	cabin_door.label = "Captain's cabin"
	cabin_door.position = Vector3(51.25, SAND, 40.95)
	b.add(cabin_door, g, "CabinDoor")
	var door_spawn := Marker3D.new()
	door_spawn.position = Vector3(51.25, 1.3, 42.6)
	door_spawn.rotation_degrees.y = 180.0
	door_spawn.set_meta(&"spawn_id", &"cabin_door")
	b.add(door_spawn, gameplay, "SpawnCabinDoor")
	door_spawn.add_to_group(&"spawn_point", true)
	# Recovered ship parts go back on deck (spec §79): the wheel at the helm
	# on the quarterdeck (off the climbing line), the compass in front of it.
	var resto := ShipRestoration.new()
	b.add(resto, g, "Restoration")
	var helm := Marker3D.new()
	helm.position = Vector3(51.6, 6.25, 35.8)
	helm.rotation_degrees.y = -90.0
	b.add(helm, resto, "Helm")
	var binnacle := Marker3D.new()
	binnacle.position = Vector3(52.8, 6.25, 35.8)
	b.add(binnacle, resto, "Binnacle")
	resto.helm = helm
	resto.binnacle = binnacle
	blk(g, Vector3(55.5, SAND, 38), Vector3(0.9, 8.6, 0.9), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Mast")
	blk(g, Vector3(55.5, 7.6, 38), Vector3(3.4, 0.45, 3.4), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "CrowsNest")
	cage(Vector3(55.5, 8.05, 39.2), "castaway_parrot_wreck", ParrotModel.Plumage.SCARLET)
	gem(Vector3(55.5, 10.6, 38), "castaway_gem_masthead", Palette.GEM_BLUE)
	# The bow half lies further down the beach.
	var bow := BowPiece.new()
	bow.length = 5.0
	bow.height = 2.6
	bow.damage_seed = 4
	bow.position = Vector3(60.5, SAND, 36.5)
	bow.rotation_degrees.y = -100.0
	b.add(bow, g, "Bow")
	var hull := HullSection.new()
	hull.length = 9.5
	hull.height = 3.4
	hull.lean_degrees = 18.0
	hull.damage_seed = 7
	hull.position = Vector3(44.0, SAND, 34.4)
	hull.rotation_degrees.y = 180.0
	b.add(hull, g, "HullSection")
	for p: Vector3 in [Vector3(40.5, SAND, 32.5), Vector3(42, SAND, 31.6), Vector3(58.5, SAND, 41.5)]:
		blk(g, p, Vector3(1.2, 1.2, 1.2), "wood", Vector3(0, 25, 0), LevelBlock.Shape.BOX, "Crate")
	# Broken mast lying on the sand: a balance beam.
	blk(g, Vector3(36, SAND, 44.5), Vector3(0.9, 0.9, 12), "wood", Vector3(0, -60, 0), LevelBlock.Shape.CYLINDER, "FallenMast")
	crab(Vector3(46, 1.25, 31), CrabModel.Variant.HERMIT, "castaway_crab_wreck_1")
	crab(Vector3(58, 1.25, 33), CrabModel.Variant.NORMAL, "castaway_crab_wreck_2")
	crab(Vector3(38, 1.25, 26), CrabModel.Variant.CANNON, "castaway_crab_wreck_gunner")
	# A tall rock at the waterline, only reachable by a long jump from the
	# crow's nest (parrot #4).
	plateau(terrain, "WreckStack", [Vector2(59, 46), Vector2(62.5, 45.6), Vector2(64, 48.5), Vector2(62, 51.2), Vector2(58.8, 50.4)], 6.2, 14.0, "rock", {"seed": 25, "no_wall_kick": true})
	cage(Vector3(61.4, 6.2, 48.6), "castaway_parrot_stack", ParrotModel.Plumage.SUNNY)
	coin_trail(Vector3(56.4, 8.6, 40.0), Vector3(60.2, 7.0, 46.2), 5, 1.6)


# --- Barnacle Bay -------------------------------------------------------------------

## The village: lanes and a plaza on the lower terrace, houses up the
## upper terrace, stairs between, dressed with laundry, bunting and lanterns.
func _village() -> void:
	var g := b.group("Village", structures)
	var low := LOW
	# Lower terrace: round the plaza.
	_house(g, "HouseBlue", Vector3(-64, low, 17), -90.0, {"size": Vector2(6, 5), "wall_color": Color("5fa8d3"), "roof_color": Color("d9483b"), "chimney": true, "seed": 11})
	_house(g, "HouseYellow", Vector3(-60, low, 9.6), 180.0, {"size": Vector2(6, 5), "wall_color": Color("f2c14e"), "roof_color": Color("3f8fd8"), "accent_color": Color("d9483b"), "seed": 12})
	_house(g, "HouseWhite", Vector3(-46, low, 10), 180.0, {"size": Vector2(5, 6), "walls": VillageHouse.Walls.PLASTER, "wall_color": Color("f3ead8"),
		"trim_color": Color("8a5a36"), "roof_color": Color("2f9e6e"), "gable_front": true, "chimney": true, "seed": 13})
	# Upper terrace.
	_house(g, "HouseLoft", Vector3(-64, UPPER, -4.5), 180.0, {"size": Vector2(7, 5), "wall_color": Color("e8833a"), "roof_color": Color("8a5a36"),
		"accent_color": Color("2f7d5b"), "chimney": true, "seed": 14})
	_house(g, "HouseStone", Vector3(-50, UPPER, -5.5), 180.0, {"size": Vector2(7, 5.5), "walls": VillageHouse.Walls.STONE, "wall_color": Color("f6e7c8"),
		"roof_color": Color("d9483b"), "trim_color": Color("6e4128"), "seed": 15})
	_house(g, "HouseGreen", Vector3(-36.5, UPPER, -4.5), 180.0, {"size": Vector2(6, 5), "wall_color": Color("7fc28a"), "roof_color": Color("f2b134"),
		"accent_color": Color("3f8fd8"), "seed": 16})
	# Stairs: plaza up to the upper terrace, plaza down to the quay.
	steps(g, Vector3(-53, low, 13.2), Vector3(-53, UPPER, 6.8), 3.0, "StairsUpper", LevelBlock.Shape.STAIRS, "stone")
	steps(g, Vector3(-46, QUAY, 30.0), Vector3(-46, low, 26.6), 5.0, "StairsQuay", LevelBlock.Shape.STAIRS, "stone")
	steps(g, Vector3(-66, QUAY, 30.0), Vector3(-66, low, 25.2), 3.0, "StairsQuayWest", LevelBlock.Shape.STAIRS, "stone")
	# The plaza: the well, the market stalls, a signpost.
	var well := VillageWell.new()
	well.position = Vector3(-52, low, 18.5)
	b.add(well, g, "Well")
	var k := 0
	for d: Array in [[Vector3(-59.5, low, 23.0), MarketStall.Goods.FISH, Color("3fa7ef")], [Vector3(-55.5, low, 23.5), MarketStall.Goods.FRUIT, Color("e8483c")],
			[Vector3(-41.5, low, 23.0), MarketStall.Goods.POTS, Color("5fcf5f")]]:
		k += 1
		var st := MarketStall.new()
		st.goods = d[1]
		st.canvas = d[2]
		st.seed = k
		st.position = d[0]
		b.add(st, g, "Stall")
	var sign := Signpost.new()
	sign.texts = PackedStringArray(["Barnacle Bay", "Lookout", "Shipyard", "Pier", "Wreck Beach"])
	sign.directions = PackedFloat32Array([0.0, 60.0, 120.0, 180.0, 90.0])
	sign.post_height = 2.8
	sign.position = Vector3(-47.5, low, 17.5)
	b.add(sign, g, "PlazaSign")
	# Lines across the lanes: bunting over the plaza, laundry up top,
	# lanterns along the quay.
	for d: Array in [[StringLine.Kind.BUNTING, Vector3(-61.2, low + 4.6, 17), Vector3(-37.5, low + 4.6, 16), 0.0, 1.0],
			[StringLine.Kind.BUNTING, Vector3(-57.5, low + 4.4, 12.6), Vector3(-48, low + 4.4, 12.8), 0.0, 0.8],
			[StringLine.Kind.LAUNDRY, Vector3(-60.4, UPPER + 2.6, -4.5), Vector3(-53.6, UPPER + 2.6, -5.5), 0.0, 0.5],
			[StringLine.Kind.LAUNDRY, Vector3(-46.4, UPPER + 2.6, -5.5), Vector3(-39.6, UPPER + 2.6, -4.5), 0.0, 0.5],
			[StringLine.Kind.LANTERNS, Vector3(-68, QUAY + 3.6, 33.2), Vector3(-30, QUAY + 3.6, 33.2), 3.6, 0.9]]:
		k += 1
		var line := StringLine.new()
		line.kind = d[0]
		line.start_point = d[1]
		line.end_point = d[2]
		line.posts = d[3]
		line.sag = d[4]
		line.seed = k
		b.add(line, g, "Line")
	# Railings along the terrace edges, barrels and crates in the lanes.
	for d: Array in [[Vector3(-70, UPPER, 5.5), 0.0], [Vector3(-44, UPPER, 6.0), 0.0], [Vector3(-30, UPPER, 6.4), 0.0],
			[Vector3(-34, low, 25.6), 0.0], [Vector3(-60, low, 25.4), 0.0]]:
		var fence := FenceSegment.new()
		fence.style = FenceSegment.Style.RAIL
		fence.position = d[0]
		fence.rotation_degrees.y = d[1]
		b.add(fence, g, "Fence")
	crate_prop(g, Vector3(-57.6, low, 12.6), "castaway_crate_village_1", 3, 12.0)
	barrel_prop(g, Vector3(-43.2, low, 13.6), "castaway_barrel_village_1", 2)
	barrel_prop(g, Vector3(-68.5, UPPER, -1.0), "castaway_barrel_village_2", 3)
	crate_prop(g, Vector3(-41.5, UPPER, -1.2), "castaway_crate_village_2", 2, -20.0)
	heart(Vector3(-56, low + 0.6, 15))
	# A gem on the blue house's ridge (up the stall canvases and the roofs).
	gem(Vector3(-64, low + 5.3, 17), "castaway_gem_roof", Palette.GEM_RED)
	coin_trail(Vector3(-59.5, low + 3.1, 22.4), Vector3(-55.5, low + 3.1, 22.9), 3, 0.6)


## The Soggy Biscuit: a walk-in tavern off the plaza. Auntie Ink keeps the
## bar; there are stools, barrels and a lantern or two.
func _tavern() -> void:
	var g := b.group("Tavern", structures)
	var at := Vector3(-30.5, LOW, 14)
	_house(g, "SoggyBiscuit", at, 90.0, {"size": Vector2(10, 7), "walls": VillageHouse.Walls.STONE, "wall_color": Color("f6e7c8"),
		"roof_color": Color("2f9e6e"), "trim_color": Color("6e4128"), "accent_color": Color("d9483b"), "porch": 2.6, "interior": true,
		"door_offset": -1.5, "sign_text": "The Soggy Biscuit", "wall_height": 3.6, "roof_pitch": 2.2, "chimney": true, "seed": 21})
	# Inside (the room spans x -33.8..-27.2, z 9.2..18.8): the bar along the
	# back, stools, tables, barrels.
	blk(g, Vector3(-29.3, LOW, 13.0), Vector3(0.7, 0.95, 5.6), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "Bar")
	blk(g, Vector3(-29.3, LOW + 0.95, 13.0), Vector3(0.9, 0.1, 5.8), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "BarTop")
	blk(g, Vector3(-27.5, LOW + 1.6, 13.0), Vector3(0.4, 0.08, 5.0), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "BackShelf")
	for z: float in [11.0, 13.0, 15.0]:
		blk(g, Vector3(-30.4, LOW, z), Vector3(0.5, 0.7, 0.5), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Stool")
	for p: Vector3 in [Vector3(-32.4, LOW, 10.8), Vector3(-31.4, LOW, 18.0)]:
		blk(g, p, Vector3(1.3, 0.85, 1.3), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Table")
	barrel_prop(g, Vector3(-28.2, LOW, 17.6), "castaway_barrel_tavern_1", 2)
	barrel_prop(g, Vector3(-28.2, LOW, 18.4), "castaway_barrel_tavern_2", 3, true)
	var lamp := Torch.new()
	lamp.position = Vector3(-33.0, LOW, 18.3)
	b.add(lamp, g, "TavernTorch")
	var zone := CameraZone.new()
	zone.distance_scale = 0.62
	zone.pitch_offset = -8.0
	zone.position = at + Vector3(0, 1.8, 0)
	b.add(zone, gameplay, "TavernCameraZone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6.4, 3.4, 9.6)
	cs.shape = box
	b.add(cs, zone, "Shape")
	var ink := NPC.new()
	ink.display_name = "Auntie Ink"
	ink.lines = PackedStringArray([
		"Well, look what the tide dragged in! Sit down, sit down, before you drip on my floor.",
		"A pirate with no ship? Gus down at the shipyard has an old dinghy gathering barnacles. Ask him nicely.",
		"And mind the open sea, dear. Swim too far out and you'll be fish food. Boats are for that.",
	])
	ink.repeat_lines = PackedStringArray(["One sea-biscuit, extra soggy? On the house, for a fellow seafarer.",
		"Tok up the lookout sees everything. Mostly clouds. Sometimes bananas.",
		"Everyone in Barnacle Bay's lost something to Brock's crabs. Spoons, mostly. And boats."])
	ink.talked_flag = &"castaway_met_ink"
	ink.position = Vector3(-28.2, LOW, 13.0)
	b.add(ink, gameplay, "AuntieInk")
	var model := OctopusModel.new()
	model.rotation.y = Player.yaw_of(Vector3.LEFT)
	# Tall enough to see over her own bar.
	model.scale = Vector3.ONE * 1.35
	b.add(model, ink, "OctopusModel")
	ink.model = model


## The harbor: the quay along its north shore, the pier out into the bay,
## the boat's mooring at its end, and lanterns.
func _harbor() -> void:
	var g := b.group("Harbor", structures)
	var quay := Dock.new()
	quay.length = 40.0
	quay.width = 4.0
	quay.post_depth = 6.0
	quay.water_line = -1.4
	quay.rope_rails = false
	quay.bollards = false
	quay.position = Vector3(-28.5, QUAY, 31.4)
	quay.rotation_degrees.y = 90.0
	b.add(quay, g, "Quay")
	var pier := Dock.new()
	pier.length = 27.0
	pier.width = 3.2
	pier.post_depth = 9.0
	pier.water_line = -1.4
	pier.position = Vector3(-48, QUAY, 33.2)
	pier.rotation_degrees.y = 180.0
	b.add(pier, g, "Pier")
	for z: float in [40.0, 50.0]:
		var lamp := LanternPost.new()
		lamp.position = Vector3(-49.9, QUAY, z)
		lamp.rotation_degrees.y = 90.0
		b.add(lamp, g, "PierLamp")
	var mooring := Marker3D.new()
	mooring.position = MOORING
	mooring.rotation.y = PI
	b.add(mooring, g, "BoatMooring")
	var arrival := Marker3D.new()
	arrival.position = Vector3(-48, QUAY + 0.1, 56)
	b.add(arrival, gameplay, "PierArrival")
	coin_trail(Vector3(-48, QUAY + 0.6, 38), Vector3(-48, QUAY + 0.6, 50), 6, 0.0, CoinTrail.TrailShape.LINE)
	var goblet := gem(Vector3(-48, QUAY + 0.9, 59.4), "castaway_goblet_dock", Palette.GOLD, "goblet")
	goblet.gem_color = Palette.GEM_RED
	for x: float in [-62.0, -36.0]:
		var nets := NetRack.new()
		nets.position = Vector3(x, QUAY, 31.6)
		nets.seed = int(x)
		b.add(nets, g, "NetRack")
	barrel_prop(g, Vector3(-53.0, QUAY, 31.2), "castaway_barrel_dock", 2, true)
	crate_prop(g, Vector3(-40.5, QUAY, 31.0), "castaway_crate_dock", 3, 8.0)


## Gus's shipyard on the bay's east shore: his workshop, the old dinghy up on
## trestles, a slipway down into the water, timber. The dinghy's tiller lies
## in the harbor off the end of the pier.
func _shipyard() -> void:
	var g := b.group("Shipyard", structures)
	_house(g, "Workshop", Vector3(-20, SAND, 31.6), 180.0, {"size": Vector2(6, 4), "wall_color": Color("b58456"), "roof_color": Color("6e7f8f"),
		"trim_color": Color("6e4128"), "accent_color": Color("d9483b"), "sign_text": "Shipwright", "wall_height": 3.0, "seed": 31})
	steps(g, Vector3(-25.4, SAND, 31.0), Vector3(-25.4, LOW, 27.6), 2.6, "StairsYard", LevelBlock.Shape.STAIRS, "wood")
	var dinghy := DinghyRepair.new()
	dinghy.fixed_flag = DINGHY
	dinghy.position = Vector3(-22.0, SAND, 36.5)
	dinghy.rotation_degrees.y = 90.0
	b.add(dinghy, gameplay, "DinghyRepair")
	steps(g, Vector3(-37, -1.6, 36.5), Vector3(-27.0, SAND, 36.5), 3.4, "Slipway", LevelBlock.Shape.RAMP, "wood")
	for d: Array in [[Vector3(-14.6, SAND, 33.0), Vector3(3.4, 0.5, 1.2), 10.0], [Vector3(-14.4, SAND + 0.5, 33.2), Vector3(3.2, 0.5, 1.0), 4.0],
			[Vector3(-12.5, SAND, 36.5), Vector3(1.2, 0.6, 3.0), -15.0]]:
		blk(g, d[0], d[1], "wood", Vector3(0, d[2], 0), LevelBlock.Shape.BOX, "Timber")
	barrel_prop(g, Vector3(-24.8, SAND, 44.0), "castaway_barrel_yard", 2)
	var gus := ShipwrightNPC.new()
	gus.display_name = "Gus"
	gus.fixed_flag = DINGHY
	gus.lines = PackedStringArray([
		"Hrrmph! Another castaway. The storm's been generous this week.",
		"No ship, eh? Well. That old dinghy on my trestles has a sound hull. Built her myself, forty years back.",
		"But she's no use without her sail and her tiller, and both have gone wandering.",
		"Tok borrowed the sail for a sunshade up his lookout tower. And the tiller went off the end of the pier in last night's storm.",
		"Fetch me those two and I'll have her floating by teatime.",
	])
	gus.waiting_lines = PackedStringArray(["Still waiting on my bits and pieces, matey."])
	gus.part_hints = PackedStringArray([
		"The sail's up Tok's lookout tower on the bluff. Climb round the outside.",
		"The tiller sank off the end of the pier. Dive down and have a look.",
	])
	gus.fixing_lines = PackedStringArray([
		"The sail AND the tiller! You're handier than you look.",
		"Stand back. This'll take a minute of hammering...",
	])
	gus.after_lines = PackedStringArray([
		"She's yours now. Treat her kindly and she'll take you to any island you can see.",
		"Mind, it's a long swim if you sink her. The open sea's no place for paddling.",
	])
	gus.position = Vector3(-25.4, SAND, 34.0)
	b.add(gus, gameplay, "Gus")
	var walrus := WalrusModel.new()
	walrus.rotation.y = Player.yaw_of(Vector3(0.3, 0, 1))
	b.add(walrus, gus, "WalrusModel")
	gus.model = walrus
	# The tiller, sunk in the harbor off the pier's end.
	var tiller := QuestItemPickup.new()
	tiller.item_id = &"dinghy_tiller"
	tiller.gone_after = DINGHY
	tiller.position = Vector3(-44.0, -3.85, 46.0)
	b.add(tiller, gameplay, "TillerPickup")


## The bluff: stairs up from the upper terrace (or a ledge grab), the rope
## bridge across the channel to the forest.
func _bluff() -> void:
	var g := b.group("Bluff", structures)
	steps(g, Vector3(-31.0, UPPER, 0.0), Vector3(-25.2, BLUFF, 0.0), 3.0, "StairsBluff", LevelBlock.Shape.STAIRS, "stone")
	var bridge := RopeBridge.new()
	bridge.start_point = Vector3.ZERO
	bridge.end_point = Vector3(0, FOREST - BLUFF, -16.2)
	bridge.width = 1.8
	bridge.sag = 0.7
	bridge.rail_collision = true
	bridge.position = Vector3(-2, BLUFF, -11.8)
	b.add(bridge, g, "RopeBridge")
	crab(Vector3(-4, BLUFF + 0.05, 0), CrabModel.Variant.NORMAL, "castaway_crab_bluff")
	coin_trail(Vector3(-2, BLUFF + 1.1, -14), Vector3(-2, FOREST + 0.4, -26), 6, 0.0, CoinTrail.TrailShape.LINE)


## Tok's lookout tower: a stone column on the bluff with plank landings
## spiralling round it up to a deck under a little roof. Parrot #2 is caged
## up there (the crabs got to it) and Tok keeps watch beside the dinghy's
## sail, borrowed for a sunshade.
func _lookout() -> void:
	var g := b.group("Lookout", structures)
	var c := TOWER
	var deck := c.y + 14.1
	blk(g, c, Vector3(4.2, 13.6, 4.2), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "TowerCore")
	blk(g, c + Vector3(0, 13.6, 0), Vector3(7.4, 0.5, 7.4), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TowerDeck")
	# Posts round the deck's rim (open on the south-west, where the landings
	# arrive), a round roof on four posts, a flagpole.
	for k in 12:
		var a := TAU * k / 12.0
		if k == 4 or k == 5:
			continue
		blk(g, Vector3(c.x + cos(a) * 3.5, deck, c.z + sin(a) * 3.5), Vector3(0.22, 1.0, 0.22), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "RailPost")
	for d: Vector3 in [Vector3(3.3, 0, 0), Vector3(-3.3, 0, 0), Vector3(0, 0, 3.3), Vector3(0, 0, -3.3)]:
		blk(g, Vector3(c.x, deck, c.z) + d, Vector3(0.3, 3.0, 0.3), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "RoofPost")
	blk(g, Vector3(c.x, deck + 3.0, c.z), Vector3(8.8, 0.35, 8.8), "roof_red", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TowerRoof")
	blk(g, Vector3(c.x, deck + 3.35, c.z), Vector3(0.18, 3.0, 0.18), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "FlagPole")
	# The landings: ten planks spiralling up, 1.35 m apart, clear of the
	# deck, each on a joist from the core; the last by the deck's open side.
	for k in 10:
		var a := deg_to_rad(99.0 - 36.0 * k)
		var out := Vector3(cos(a), 0, sin(a))
		var tangent := Vector3(-sin(a), 0, cos(a))
		var y := c.y + 1.35 * (k + 1)
		var p := Vector3(c.x, y - 0.35, c.z) + out * 5.0
		blk(g, p, Vector3(1.9, 0.35, 2.3), "wood", Vector3(0, rad_to_deg(Player.yaw_of(tangent)), 0), LevelBlock.Shape.BOX, "Landing%d" % (k + 1))
		blk(g, Vector3(c.x, y - 0.65, c.z) + out * 3.05, Vector3(0.24, 0.24, 1.9), "wood_dark", Vector3(0, rad_to_deg(Player.yaw_of(out)), 0), LevelBlock.Shape.BOX, "Joist%d" % (k + 1))
		if k < 6:
			coin_trail(p + Vector3.UP * 1.0, p + Vector3.UP * 1.0, 1, 0.0, CoinTrail.TrailShape.LINE)
	crab(Vector3(c.x, c.y + 1.35 * 5 + 0.05, c.z) + Vector3(cos(deg_to_rad(-45.0)), 0, sin(deg_to_rad(-45.0))) * 5.0, CrabModel.Variant.NORMAL, "castaway_crab_tower")
	cage(Vector3(c.x + 2.0, deck, c.z - 2.0), "castaway_parrot_outpost", ParrotModel.Plumage.AZURE)
	var sail := QuestItemPickup.new()
	sail.item_id = &"dinghy_sail"
	sail.gone_after = DINGHY
	sail.position = Vector3(c.x + 1.8, deck, c.z + 1.6)
	b.add(sail, gameplay, "SailPickup")
	gem(Vector3(c.x - 3.0, deck + 3.9, c.z + 3.0), "castaway_gem_lookout_roof", Color("ffb347"))


# --- The north half -----------------------------------------------------------------

## The forest plateau: the summit (ship part, parrot #3, a lookout mast),
## its terraces and wall-kick chimney, the stairs down to the north beach.
func _forest() -> void:
	var g := b.group("Forest", gameplay)
	# Wall-kick chimney up the summit's south face (a shortcut).
	blk(structures, _n(Vector3(-1.2, 7.0, -23.0)), Vector3(1.4, 6.2, 3.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChimneyA")
	blk(structures, _n(Vector3(3.6, 7.0, -23.0)), Vector3(1.4, 6.2, 3.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChimneyB")
	coin_trail(_n(Vector3(1.2, 8.0, -21.6)), _n(Vector3(1.2, 12.6, -22.6)), 5, 0.0, CoinTrail.TrailShape.LINE)
	# Terrace route coins.
	coin_trail(_n(Vector3(-30, 7.2, -14)), _n(Vector3(-29, 9.0, -22)), 4, 1.6)
	coin_trail(_n(Vector3(-24, 9.0, -22)), _n(Vector3(-17, 10.8, -18)), 4, 1.6)
	coin_trail(_n(Vector3(-15, 10.8, -19)), _n(Vector3(-12, 12.6, -27)), 4, 1.6)
	# Summit: ship part, parrot #3 in the old crow's nest, a gem, a lookout.
	var part := ShipPartPickup.new()
	part.part_id = &"compass"
	part.display_name = "Ship's Compass"
	part.position = _n(Vector3(-6, 12.4, -36))
	b.add(part, g, "ShipCompass")
	blk(structures, _n(Vector3(2, 12.4, -38)), Vector3(0.9, 6.0, 0.9), "wood", Vector3(0, 0, -6), LevelBlock.Shape.CYLINDER, "BrokenMast")
	blk(structures, _n(Vector3(2.6, 18.0, -38)), Vector3(3.0, 0.4, 3.0), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "LookoutNest")
	cage(_n(Vector3(-14, 12.4, -38)), "castaway_parrot_summit", ParrotModel.Plumage.LIME)
	gem(_n(Vector3(2.6, 19.0, -38)), "castaway_gem_lookout", Palette.GEM_BLUE)
	crab(Vector3(-50, FOREST + 0.05, -36), CrabModel.Variant.NORMAL, "castaway_crab_ridge")
	crab(Vector3(-52, FOREST + 0.05, -50), CrabModel.Variant.HERMIT, "castaway_crab_forest")
	# Down to the north beach: a long wooden stair along the cliff.
	var s := steps(structures, Vector3(-30, SAND, -83.2), Vector3(-48.5, FOREST, -83.2), 3.0, "BeachStairs", LevelBlock.Shape.STAIRS, "wood")
	s.add_to_group(&"no_ledge_grab", true)
	blk(structures, Vector3(-50.5, FOREST - 0.6, -82.0), Vector3(4.4, 0.6, 6.4), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "BeachStairsLanding")
	coin_trail(Vector3(-32, SAND + 1.4, -83.2), Vector3(-44, FOREST - 2.2, -83.2), 5, 0.0, CoinTrail.TrailShape.LINE)


func _cave() -> void:
	var g := b.group("DarkCave", structures)
	# A rocky tunnel mouth on the forest beside the summit, opening north
	# into a chamber. Too dark for Patchy until he has the lantern.
	blk(g, _n(Vector3(14.5, 7.0, -37.4)), Vector3(6, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelWallN")
	blk(g, _n(Vector3(13, 7.0, -31.6)), Vector3(9, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelWallS")
	blk(g, _n(Vector3(13, 11.0, -34.5)), Vector3(10, 1.4, 7.4), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelRoof")
	# The chamber: floor slab, tall outer walls.
	blk(g, _n(Vector3(13.5, 6.4, -42.6)), Vector3(10.4, 0.6, 10.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberFloor")
	blk(g, _n(Vector3(19.1, 3.0, -43.05)), Vector3(1.2, 8.0, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallE")
	blk(g, _n(Vector3(14.1, 3.0, -48.1)), Vector3(11.2, 8.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallN")
	blk(g, _n(Vector3(7.9, 7.0, -43.05)), Vector3(1.2, 4.0, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallW")
	blk(g, _n(Vector3(18.6, 3.0, -37.4)), Vector3(2.2, 8.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallSE")
	blk(g, _n(Vector3(13.5, 11.0, -43.05)), Vector3(12.4, 1.4, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberRoof")
	var dz := DarknessZone.new()
	dz.size = Vector3(8.0, 4.0, 4.6)
	dz.inward = Vector3(-1, 0, 0)
	dz.refusal_depth = 2.2
	dz.position = _n(Vector3(12.4, 9.0, -34.5))
	b.add(dz, gameplay, "CaveDarkness")
	var dz2 := DarknessZone.new()
	dz2.size = Vector3(10.0, 4.0, 9.6)
	dz2.inward = Vector3(0, 0, -1)
	dz2.refusal_depth = 0.6
	dz2.position = _n(Vector3(13.5, 9.0, -42.8))
	b.add(dz2, gameplay, "ChamberDarkness")
	for z in [[-34.5, Vector3(9, 4, 4.6)], [-42.8, Vector3(10, 4, 9.6)]]:
		var zone := CameraZone.new()
		zone.distance_scale = 0.6
		zone.position = _n(Vector3(12.8, 9.0, z[0]))
		b.add(zone, gameplay, "CaveCameraZone")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = z[1]
		cs.shape = box
		b.add(cs, zone, "Shape")
	# Lantern puzzle: light both braziers to raise the gate.
	var fire_a := Brazier.new()
	fire_a.brazier_id = &"castaway_cave_brazier_a"
	fire_a.position = _n(Vector3(10.0, 7.0, -40.6))
	b.add(fire_a, gameplay, "CaveBrazierA")
	var fire_b := Brazier.new()
	fire_b.brazier_id = &"castaway_cave_brazier_b"
	fire_b.position = _n(Vector3(17.0, 7.0, -40.6))
	b.add(fire_b, gameplay, "CaveBrazierB")
	dz.lit_by = [fire_a, fire_b]
	dz2.lit_by = [fire_a, fire_b]
	var gate := Gate.new()
	gate.gate_id = &"castaway_cave_gate"
	gate.size = Vector3(10.4, 4.0, 0.4)
	gate.position = _n(Vector3(13.5, 7.0, -42.6))
	gate.triggers = [fire_a, fire_b]
	b.add(gate, structures, "CaveGate")
	# Behind it: the shovel, a mound to try it on (a treasure map!) and a gem.
	var shovel := AttachmentPickup.new()
	shovel.attachment_id = &"shovel"
	shovel.position = _n(Vector3(11.0, 7.0, -45.6))
	b.add(shovel, gameplay, "ShovelPickup")
	var mound := DigSpot.new()
	mound.spot_id = &"castaway_cave_mound"
	mound.island_id = ISLAND
	mound.contents = "map"
	mound.map_id = &"castaway_map_1"
	mound.position = _n(Vector3(16.0, 7.0, -45.6))
	b.add(mound, gameplay, "CaveMapMound")
	gem(_n(Vector3(13.5, 7.6, -46.6)), "castaway_gem_cave", Color("ffb347"))
	# The map's X: under the old stump behind the Soggy Biscuit.
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"castaway_x_spot"
	x_spot.island_id = ISLAND
	x_spot.contents = "relic"
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"castaway_map_1"
	x_spot.position = Vector3(-21.0, LOW, 19.0)
	b.add(x_spot, gameplay, "TreasureMapX")
	blk(structures, Vector3(-22.6, LOW, 17.0), Vector3(1.3, 0.9, 1.3), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "OldStump")
	# Torches flank the dark cave's mouth (outside the darkness).
	for z: float in [-30.6, -38.4]:
		var torch := Torch.new()
		torch.position = _n(Vector3(18.8, 7.0, z))
		b.add(torch, structures, "CaveTorch")


func _gorge_and_headland() -> void:
	var g := b.group("Headland", gameplay)
	# The log lies along the forest's edge; six parrots can lay it across the
	# gorge, bedded into both rims so its top is a single step up (0.3 m).
	var log_body := FallenLog.new()
	log_body.length = 24.0
	log_body.position = Vector3(16, FOREST + 0.75, -46)
	log_body.rotation_degrees.y = 90.0
	b.add(log_body, g, "FallenLog")
	var dest := Marker3D.new()
	dest.position = Vector3(33.8, FOREST - 0.45, -42)
	b.add(dest, g, "LogBridgeSpot")
	var task := ParrotTask.new()
	task.task_id = &"castaway_log_bridge"
	task.required_parrots = 6
	task.carried = log_body
	task.destination = dest
	task.position = Vector3(13.5, FOREST, -36)
	b.add(task, g, "LogBridgeTask")
	# Chained-chest puzzle: pound all three mooring posts.
	var posts: Array[PoundPost] = []
	var center := _h(Vector3(62, 7.5, -16))
	for k in 3:
		var a := TAU * k / 3.0 + 0.4
		var post := PoundPost.new()
		post.post_id = StringName("castaway_chest_post_%d" % k)
		post.position = center + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0)
		b.add(post, g, "PoundPost%d" % k)
		posts.append(post)
	var chest := TreasureChest.new()
	chest.chest_id = &"castaway_headland_chest"
	chest.island_id = ISLAND
	chest.contents = "crown"
	chest.attachment_reward = &"grapple"
	chest.lock_posts = posts
	chest.position = center
	chest.rotation_degrees.y = 180.0
	b.add(chest, g, "HeadlandChest")
	gem(_h(Vector3(72, 8.2, -30)), "castaway_gem_headland", Color("9b5cff"))
	# Brock's croc soldiers hold the headland: flank them or pound the ground.
	for d: Array in [[Vector3(56, FOREST + 0.05, -37), "castaway_croc_1", 200.0], [_h(Vector3(70, 7.55, -20)), "castaway_croc_2", 120.0]]:
		var croc := CrocGrunt.new()
		croc.persistent_id = StringName(d[1])
		croc.position = d[0]
		croc.rotation_degrees.y = d[2]
		b.add(croc, enemies, "CrocGrunt")
	_boss_arena()
	# Grapple tease: a big iron ring on a sea pillar, far out of hook range.
	plateau(terrain, "GrapplePillar", _shift([Vector2(86, -40), Vector2(91, -42), Vector2(94, -37), Vector2(90, -33), Vector2(85, -35)], HEAD),
		FOREST + 8.5, 30.0, "rock", {"seed": 31})
	# An old lookout pole on the pillar with a big iron ring: visible from
	# the headland, too far and too high for the hook.
	blk(structures, _h(Vector3(88.3, 16.0, -37.3)), Vector3(0.5, 5.8, 0.5), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "PillarPole")
	var tease := HookPoint.new()
	tease.grapple_only = true
	tease.grapple_arrival = "hop"
	tease.hang_length = 0.0
	tease.position = _h(Vector3(87.6, 21.0, -36.6))
	tease.scale = Vector3.ONE * 2.0
	b.add(tease, g, "GrappleTease")
	# Up top: the hand cannon.
	var cannon := AttachmentPickup.new()
	cannon.attachment_id = &"cannon"
	cannon.position = _h(Vector3(90.2, 16.0, -38.4))
	b.add(cannon, g, "CannonPickup")
	_cannon_secrets()


## King Claw's ring on the headland's north: tall rock spires with gaps.
## Stepping in wakes him; leaving resets the fight.
func _boss_arena() -> void:
	var g := b.group("ClawArena", structures)
	var center := _h(Vector3(54, 7.5, -38))
	var arena_r := 11.0
	for k in 10:
		var a := TAU * k / 10.0 + 0.2
		# Leave a wide way in facing the log bridge (south-west).
		if k == 6 or k == 7:
			continue
		var h := 3.6 + 1.2 * sin(k * 2.3)
		var spire := blk(g, center + Vector3(cos(a), 0, sin(a)) * (arena_r + 1.4), Vector3(1.8, h, 1.8), "rock", Vector3(0, k * 37.0, 0), LevelBlock.Shape.CYLINDER, "Spire")
		spire.add_to_group(&"no_ledge_grab", true)
	var boss := KingClaw.new()
	boss.position = center
	boss.arena_center = center
	boss.arena_radius = arena_r
	boss.rotation_degrees.y = 225.0
	b.add(boss, enemies, "KingClaw")
	var arena := BossArena.new()
	arena.boss = boss
	arena.radius = arena_r
	arena.position = center
	b.add(arena, gameplay, "ClawArena")
	var cam := FocusCameraZone.new()
	cam.focus = boss
	cam.zone_priority = 2
	cam.distance_scale = 1.35
	cam.pitch_offset = -6.0
	cam.fov_offset = 4.0
	cam.position = center
	b.add(cam, gameplay, "ClawCameraZone")
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = arena_r + 2.0
	cyl.height = 12.0
	cs.shape = cyl
	cs.position = Vector3(0, 4.0, 0)
	b.add(cs, cam, "Shape")
	_checkpoint(gameplay, "cp_claw_arena", center + Vector3(-12.5, 0, 9.5), 50.0, "CpClawArena")


## Hand-cannon secrets: a cracked-rock grotto by the cove's horn and an old
## stone storehouse on the meadow that opens when two far-flung targets are
## hit (one on the west beach, one on the horn).
func _cannon_secrets() -> void:
	var g := b.group("CannonSecrets", structures)
	var grotto := Vector3(-16, SAND, 42)
	blk(g, grotto + Vector3(-2.4, 0, 0), Vector3(1.0, 3.2, 4.4), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoBack")
	blk(g, grotto + Vector3(0, 0, -2.0), Vector3(4.8, 3.2, 0.8), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoSideN")
	blk(g, grotto + Vector3(0, 0, 2.0), Vector3(4.8, 3.2, 0.8), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoSideS")
	blk(g, grotto + Vector3(-0.1, 3.2, 0), Vector3(5.2, 0.9, 4.8), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoRoof")
	var crack := CrackedRock.new()
	crack.rock_id = &"castaway_grotto_rock"
	crack.size = Vector3(3.2, 3.2, 0.9)
	crack.position = grotto + Vector3(2.1, 0, 0)
	crack.rotation_degrees.y = 90.0
	b.add(crack, g, "GrottoCrackedRock")
	gem(grotto + Vector3(-0.8, 0.6, 0), "castaway_gem_grotto", Color("3ddc97"))
	coin_trail(grotto + Vector3(-1.6, 0.6, -1.0), grotto + Vector3(-1.6, 0.6, 1.0), 3, 0.0, CoinTrail.TrailShape.LINE)
	# The storehouse: walls of fitted stone and a gate tied to two targets.
	var v := Vector3(16, LOW, -4)
	blk(g, v + Vector3(0, 0, -2.2), Vector3(5.0, 3.6, 0.8), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultBack")
	blk(g, v + Vector3(-2.2, 0, 0), Vector3(0.8, 3.6, 5.0), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultW")
	blk(g, v + Vector3(2.2, 0, 0), Vector3(0.8, 3.6, 5.0), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultE")
	blk(g, v + Vector3(0, 3.6, 0), Vector3(5.6, 0.8, 5.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultRoof")
	var t1 := CannonTarget.new()
	t1.target_id = &"castaway_target_beach"
	t1.position = Vector3(-91, SAND, 36)
	t1.rotation_degrees.y = -110.0
	b.add(t1, g, "TargetBeach")
	var t2 := CannonTarget.new()
	t2.target_id = &"castaway_target_horn"
	t2.position = Vector3(-4.6, 4.5, 46.6)
	t2.rotation_degrees.y = -48.0
	b.add(t2, g, "TargetHorn")
	var vault := Gate.new()
	vault.gate_id = &"castaway_vault_gate"
	vault.size = Vector3(3.6, 3.6, 0.4)
	vault.position = v + Vector3(0, 0, 2.2)
	vault.triggers = [t1, t2]
	b.add(vault, g, "VaultGate")
	gem(v + Vector3(0, 0.8, -0.6), "castaway_relic_vault", Palette.GOLD, "relic")
	coin_trail(v + Vector3(-1.2, 0.5, 0.6), v + Vector3(1.2, 0.5, 0.6), 4, 0.0, CoinTrail.TrailShape.LINE)


func _ring_run() -> void:
	var g := b.group("RingRun", gameplay)
	for p: Vector3 in [Vector3(1.5, 8.4, 53.5), Vector3(9.5, 8.6, 58.5)]:
		var hp := HookPoint.new()
		hp.position = p
		hp.hang_length = 1.6
		b.add(hp, g, "HookRing")
	gem(Vector3(17, 5.2, 64.5), "castaway_gem_pillar", Palette.GEM_RED)
	coin_trail(Vector3(-3, 5.5, 51), Vector3(0.5, 6.5, 53.2), 3, 0.8)


func _coins() -> void:
	# Breadcrumbs from the cove toward the shipwreck (parrot #1 early on).
	coin_trail(Vector3(10, 1.8, 34), Vector3(28, 1.8, 36), 7, 0.0, CoinTrail.TrailShape.LINE)
	# Up the tilted deck, onto the cabin and the nest.
	coin_trail(Vector3(40.5, 1.9, 38), Vector3(47.5, 4.3, 38), 5, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(48.4, 4.6, 38), Vector3(50.2, 6.6, 38), 3, 1.0)
	# Along the fallen mast.
	coin_trail(Vector3(31.5, 2.6, 47.1), Vector3(40.5, 2.6, 41.9), 5, 0.0, CoinTrail.TrailShape.LINE)
	# West from the cove along the beach to the village.
	coin_trail(Vector3(-8, 1.8, 35.5), Vector3(-16, 1.8, 35.5), 4, 0.0, CoinTrail.TrailShape.LINE)
	# A ring around the meadow's armored crab encourages a ground pound.
	coin_trail(Vector3(-4, LOW + 0.6, 14), Vector3.ZERO, 8, 0.0, CoinTrail.TrailShape.RING)
	crab(Vector3(-4, LOW + 0.05, 14), CrabModel.Variant.ARMORED, "castaway_crab_meadow_armored")
	crab(Vector3(8, LOW + 0.05, 12), CrabModel.Variant.NORMAL, "castaway_crab_meadow")
	crab(Vector3(-36, LOW + 0.05, 22), CrabModel.Variant.NORMAL, "castaway_crab_outpost_1")
	crab(Vector3(-44, UPPER + 0.05, 0), CrabModel.Variant.ARMORED, "castaway_crab_outpost_2")
	# A greedy pelican patrols the wreck beach; TNT snails wander near cracked
	# rock (kick a barrel at the grotto before the cannon turns up).
	var bird := Pelican.new()
	bird.persistent_id = &"castaway_pelican_wreck"
	bird.position = Vector3(46, SAND, 34)
	b.add(bird, enemies, "PelicanWreck")
	var snail := TNTSnail.new()
	snail.position = Vector3(-10.5, 1.25, 39.0)
	snail.rotation_degrees.y = 60.0
	b.add(snail, enemies, "SnailGrotto")
	var snail2 := TNTSnail.new()
	snail2.position = Vector3(10, LOW + 0.05, 2)
	b.add(snail2, enemies, "SnailVault")
	# The east strip along the channel.
	coin_trail(Vector3(40, LOW + 0.6, -4), Vector3(70, LOW + 0.6, -4), 8, 0.0, CoinTrail.TrailShape.LINE)


func _checkpoints() -> void:
	for d: Array in [["cp_cove", Vector3(-6, SAND, 30), 0.0], ["cp_village", Vector3(-48, LOW, 15), 0.0],
			["cp_bluff", Vector3(-20, BLUFF, 1.5), 0.0], ["cp_forest", Vector3(-6, FOREST, -31), 0.0], ["cp_summit", _n(Vector3(-10, 12.4, -32)), 0.0]]:
		_checkpoint(gameplay, d[0], d[1], d[2], String(d[0]).capitalize().replace(" ", ""))
	for spot: Array in [["Cove", Vector3(0, 1.3, 33)], ["Wreck", Vector3(40, 1.3, 30)], ["Village", Vector3(-48, LOW + 0.1, 15)], ["Shipyard", Vector3(-22, 1.3, 34)],
			["Bluff", Vector3(-20, BLUFF + 0.1, 1.5)], ["Forest", Vector3(-6, FOREST + 0.1, -31)], ["Summit", _n(Vector3(-10, 12.5, -32))],
			["Headland", _h(Vector3(55, 7.6, -14))], ["Pier", Vector3(-48, QUAY + 0.1, 50)], ["GullRock", Vector3(-89.5, 5.5, 15)], ["NorthBeach", Vector3(-20, 1.3, -88)]]:
		var m := Marker3D.new()
		m.position = spot[1]
		b.add(m, gameplay, "Teleport" + String(spot[0]))
		m.add_to_group(&"debug_teleport", true)


func _driftwood_key() -> void:
	var g := b.group("DriftwoodKey", gameplay)
	var t := b.group("DriftwoodTerrain", terrain)
	var c := DRIFTWOOD
	var o := Vector2(c.x, c.z)
	var ring: Array = []
	for v: Vector2 in [Vector2(-22, -8), Vector2(-16, -20), Vector2(0, -26), Vector2(18, -22), Vector2(26, -8),
			Vector2(22, 10), Vector2(8, 20), Vector2(-10, 20), Vector2(-22, 8)]:
		ring.append(o + v)
	plateau(t, "IsletBeach", ring, 1.0, 9.0, "sand", {"shore": true, "shore_width": 12.0, "shore_drop": 4.5, "seed": 41})
	var knoll: Array = []
	for v: Vector2 in [Vector2(-8, -12), Vector2(2, -15), Vector2(12, -10), Vector2(14, 2), Vector2(4, 9), Vector2(-7, 6)]:
		knoll.append(o + v)
	plateau(t, "IsletKnoll", knoll, 2.8, 2.6, "cliff", {"seed": 43})
	var isl := IslandZone.new()
	isl.island_id = ISLET
	isl.display_name = "Driftwood Key"
	isl.size = Vector3(64, 40, 56)
	isl.position = c + Vector3(2, 10, -3)
	b.add(isl, g, "IslandZoneDriftwood")
	# Landing beach facing Castaway Cay (north-east) with a checkpoint.
	var landing := Marker3D.new()
	landing.position = c + Vector3(14, 0.0, -30)
	landing.rotation_degrees.y = 200.0
	b.add(landing, g, "BoatLanding")
	_checkpoint(g, "cp_driftwood", c + Vector3(10, 1.0, -17), 200.0, "CpDriftwood")
	# Parrot #5: atop a tower of lashed driftwood platforms.
	blk(g, c + Vector3(-12, 1.0, 4), Vector3(3.2, 1.7, 3.2), "wood", Vector3(0, 12, 0), LevelBlock.Shape.BOX, "Raft1")
	blk(g, c + Vector3(-15.5, 1.0, 7.5), Vector3(2.6, 3.4, 2.6), "wood_dark", Vector3(0, -8, 0), LevelBlock.Shape.BOX, "Raft2")
	blk(g, c + Vector3(-18.5, 1.0, 4.0), Vector3(2.4, 5.1, 2.4), "wood", Vector3(0, 20, 0), LevelBlock.Shape.BOX, "Raft3")
	cage(c + Vector3(-18.5, 6.1, 4.0), "driftwood_parrot_tower", ParrotModel.Plumage.AZURE).island_id = ISLET
	coin_trail(c + Vector3(-9.4, 1.5, 3.2), c + Vector3(-11.6, 3.2, 4.2), 3, 0.8)
	coin_trail(c + Vector3(-13.2, 3.4, 5.6), c + Vector3(-15.2, 4.9, 7.2), 3, 1.0)
	# Parrot #6: in the crab pen on the knoll, guarded.
	var pen := c + Vector3(4, 2.8, -3)
	for k in 10:
		var a := TAU * k / 10.0
		if k == 7:
			continue
		blk(g, pen + Vector3(cos(a) * 4.2, 0, sin(a) * 4.2), Vector3(0.3, 1.0, 0.3), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "PenPost")
	cage(pen, "driftwood_parrot_pen", ParrotModel.Plumage.LIME).island_id = ISLET
	# The storm lantern, left on the knoll by some long-gone castaway.
	var lantern := AttachmentPickup.new()
	lantern.attachment_id = &"lantern"
	lantern.position = c + Vector3(-3.0, 2.8, -8.0)
	b.add(lantern, g, "LanternPickup")
	crab(pen + Vector3(2.0, 0.05, 1.0), CrabModel.Variant.ARMORED, "driftwood_crab_pen_1")
	crab(pen + Vector3(-2.0, 0.05, -1.2), CrabModel.Variant.HERMIT, "driftwood_crab_pen_2")
	crab(c + Vector3(16, 1.05, 4), CrabModel.Variant.NORMAL, "driftwood_crab_beach")
	crab(c + Vector3(-14, 1.05, -14), CrabModel.Variant.CANNON, "driftwood_crab_gunner")
	var gull := Pelican.new()
	gull.persistent_id = &"driftwood_pelican"
	gull.position = c + Vector3(6, 1.0, -12)
	gull.circle_radius = 7.0
	b.add(gull, enemies, "PelicanDriftwood")
	# Treasure: a gem on an offshore rock (a swim and a climb), a heart, coins.
	plateau(t, "IsletRock", [o + Vector2(28, 14), o + Vector2(32, 13), o + Vector2(33, 17), o + Vector2(29, 19)], 2.2, 10.0, "rock", {"seed": 47})
	var g1 := gem(c + Vector3(30.5, 3.2, 16), "driftwood_gem_rock", Palette.GEM_BLUE)
	g1.island_id = ISLET
	heart(c + Vector3(8, 3.4, 4))
	coin_trail(c + Vector3(12, 1.5, -20), c + Vector3(6, 1.5, -10), 5, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(c + Vector3(-4, 1.5, 14), c + Vector3(10, 1.5, 14), 5, 0.0, CoinTrail.TrailShape.LINE)
	var m := Marker3D.new()
	m.position = c + Vector3(10, 1.1, -16)
	b.add(m, gameplay, "TeleportDriftwood")
	m.add_to_group(&"debug_teleport", true)
	# Dressing: palms, a jetty at the landing, bushes and rocks.
	var n := b.group("DriftwoodNature")
	var k := 100
	for d: Array in [[Vector3(-14, 1.0, -12), 7.0, 16.0, 220.0], [Vector3(20, 1.0, -6), 6.5, 22.0, -60.0], [Vector3(0, 2.8, 2), 8.0, 6.0, 0.0],
			[Vector3(-6, 1.0, 15), 6.0, 20.0, 170.0], [Vector3(14, 1.0, 12), 7.5, 18.0, -140.0]]:
		k += 3
		palm(n, c + d[0], d[1], d[2], d[3], k)
	var jetty := Dock.new()
	jetty.length = 7.0
	jetty.width = 2.4
	jetty.post_depth = 6.0
	jetty.water_line = -1.0
	jetty.position = c + Vector3(13.0, 1.1, -22.0)
	jetty.rotation_degrees.y = 20.0
	b.add(jetty, n, "Jetty")
	rock(n, c + Vector3(-20, 1.0, 2), Vector3(2.0, 1.4, 1.8), StylizedRock.Preset.SAND_ROCK, 61)
	rock(n, c + Vector3(22, 1.0, 6), Vector3(1.6, 1.1, 1.4), StylizedRock.Preset.MOSSY, 67)
	var grass_only: Array[StringName] = [&"grass"]
	scatter(n, c + Vector3(3, 20, -3), Vector2(30, 30), PropScatter.Kind.GRASS, 0.5, grass_only, 13, 900)
	scatter(n, c + Vector3(3, 20, -3), Vector2(30, 30), PropScatter.Kind.FLOWERS, 0.05, grass_only, 17, 100)
	crate_prop(n, c + Vector3(16, 1.0, -14), "driftwood_crate_1", 3, 15.0)


# --- Side quest and islanders -------------------------------------------------------

## The side quest (spec §103): Brock's crabs stole Old Shellby's fishing boat,
## the Barnacle Betty, and hauled her up Gull Rock at the west beach's end.
## Follow the drag marks along the beach and up the crabs' plank ramp, grab
## the ledge to the top, and call three parrots to fly her home to Shellby's
## jetty in the harbor. Shellby pays with his old chart, whose X is on the
## north beach.
func _barnacle_betty() -> void:
	var g := b.group("BarnacleBetty", gameplay)
	# Gull Rock and its fittings were laid out further north; they keep
	# their shape here, by the channel's west mouth.
	var gull := Vector3(-26, 0, 55)
	var jetty := Dock.new()
	jetty.length = 11.0
	jetty.width = 2.6
	jetty.post_depth = 7.0
	jetty.water_line = -1.2
	jetty.position = Vector3(-69.5, 1.35, 46.0)
	jetty.rotation_degrees.y = -90.0
	b.add(jetty, structures, "ShellbyJetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(-61.0, 0.0, 49.0)
	mooring.rotation_degrees.y = -90.0
	b.add(mooring, g, "BettyMooring")
	var npc := ShellbyNPC.new()
	npc.display_name = "Old Shellby"
	npc.lines = PackedStringArray([
		"Well, shiver my shell! You washed up with half the sea's driftwood.",
		"Brock's crabs nicked my boat right off her mooring last night. The Barnacle Betty! Dragged her off up the beach, see?",
		"Follow those marks and bring my Betty home, and there's something in it for you.",
	])
	npc.waiting_lines = PackedStringArray([
		"Those drag marks lead off up the west beach. Crabs can't have hauled her far... can they?",
		"If she's stuck somewhere high, a few parrot friends could lift her. Three should do it.",
	])
	npc.thanks_lines = PackedStringArray([
		"My Betty! Not a scratch on her! ...Well. New scratches.",
		"Here, my old fishing chart. Some pirate inked an X on the back, years ago. Never did own a shovel.",
	])
	npc.after_lines = PackedStringArray([
		"Betty and me, back on the water. Best fishing's at dawn, while the crabs are still snoring.",
		"Gus's old dinghy floats too... mostly.",
	])
	npc.talked_flag = &"castaway_met_shellby"
	npc.quest_flag = &"castaway_betty_quest"
	npc.done_flag = &"castaway_betty_lift"
	npc.reward_flag = &"castaway_betty_reward"
	npc.reward_kind = "map"
	npc.reward_id = &"castaway_map_2"
	npc.reward_message = "Got Shellby's fishing chart!"
	npc.sail_lines = PackedStringArray([
		"Saw that croc rowing off with his snout in the air. 'Admiral of the Archipelago', my barnacles!",
		"Going after him, are you? That scrap of a sail will get you there... about a week behind him.",
		"Here: Betty's spare sail. Stitched it myself... mostly. She'll fly you to any island you can see from here.",
	])
	npc.position = Vector3(-71.5, 1.35, 44.6)
	b.add(npc, gameplay, "OldShellby")
	var model := TurtleModel.new()
	model.rotation.y = Player.yaw_of(mooring.position - npc.position)
	b.add(model, npc, "TurtleModel")
	npc.model = model
	# Gull Rock: a sea cliff with a lower ledge on its landward side.
	plateau(terrain, "GullRock", _shift([Vector2(-80, -34), Vector2(-81, -41), Vector2(-77, -46.5), Vector2(-70.5, -47),
		Vector2(-66.5, -43), Vector2(-66, -36.5), Vector2(-69.5, -32), Vector2(-75.5, -31)], gull), 9.4, 11.0, "cliff", {"seed": 31})
	# Its east face is square where the ramp's top edge meets it (no lip).
	plateau(terrain, "GullLedge", _shift([Vector2(-67.5, -44.5), Vector2(-61.2, -44), Vector2(-61, -41.6), Vector2(-61, -38.4),
		Vector2(-62, -35.5), Vector2(-67.5, -35)], gull), 5.4, 6.0, "cliff", {"seed": 33})
	# The crabs' plank ramp up to the ledge, a crate they used as a step and
	# the planks that gave way under the boat on the last stretch.
	blk(structures, Vector3(-57.0, 1.2, -40.0) + gull, Vector3(2.6, 4.2, 8.0), "wood", Vector3(0, 90, 0), LevelBlock.Shape.RAMP, "CrabRamp")
	blk(structures, Vector3(-65.4, 5.4, -42.6) + gull, Vector3(1.4, 1.4, 1.4), "wood", Vector3(0, 14, 0), LevelBlock.Shape.BOX, "CrabCrate")
	blk(structures, Vector3(-63.3, 5.4, -37.6) + gull, Vector3(0.08, 4.4, 0.45), "wood_dark", Vector3(0, 0, 41), LevelBlock.Shape.BOX, "LeaningPlank")
	blk(structures, Vector3(-62.4, 5.4, -42.0) + gull, Vector3(0.45, 0.08, 1.9), "wood_dark", Vector3(0, 63, 0), LevelBlock.Shape.BOX, "FallenPlank")
	blk(structures, Vector3(-63.6, 5.4, -39.2) + gull, Vector3(0.45, 0.08, 1.4), "wood_dark", Vector3(0, -24, 0), LevelBlock.Shape.BOX, "SnappedPlank")
	# The Betty, wedged on top and flying Brock's flag, with her guards.
	var betty := FishingBoat.new()
	betty.flag_until = &"castaway_betty_lift"
	betty.position = Vector3(-74.0, 9.85, -39.5) + gull
	betty.rotation_degrees = Vector3(0, 18, -7)
	b.add(betty, g, "BarnacleBetty")
	var task := ParrotTask.new()
	task.task_id = &"castaway_betty_lift"
	task.required_parrots = 3
	task.carried = betty
	task.destination = mooring
	task.lift_height = 9.0
	task.carry_time = 6.5
	task.position = Vector3(-70.2, 9.4, -38.2) + gull
	b.add(task, g, "BettyTask")
	crab(Vector3(-76.5, 9.45, -43.5) + gull, CrabModel.Variant.NORMAL, "castaway_crab_gull_1")
	crab(Vector3(-71.5, 9.45, -34.5) + gull, CrabModel.Variant.HERMIT, "castaway_crab_gull_2")
	gem(Vector3(-79.0, 10.0, -40.0) + gull, "castaway_gem_gull", Color("5fe08a"))
	palm(g, Vector3(-77.5, 9.4, -35.0) + gull, 6.0, 16.0, 200.0, 97)
	rock(g, Vector3(-71.0, 9.4, -44.5) + gull, Vector3(1.4, 0.9, 1.2), StylizedRock.Preset.MOSSY, 89, 30.0)
	barrel_prop(g, Vector3(-69.0, 9.4, -42.0) + gull, "castaway_barrel_gull", 3)
	# The trail: from the empty mooring along the beach, the ramp and the ledge.
	var marks := DragMarks.new()
	marks.points = PackedVector3Array([Vector3(-72.5, 1.2, 43), Vector3(-76.5, 1.2, 38), Vector3(-80, 1.2, 32),
		Vector3(-81.5, 1.2, 26), Vector3(-81, 1.2, 20), Vector3(-80, 1.2, 15), Vector3(-79, 1.2, 15)])
	marks.seed = 3
	b.add(marks, g, "DragMarks")
	var ramp_marks := DragMarks.new()
	ramp_marks.points = PackedVector3Array([Vector3(-53, 1.2, -40) + gull, Vector3(-61, 5.4, -40) + gull, Vector3(-65.4, 5.4, -40.4) + gull])
	ramp_marks.footprints = false
	ramp_marks.groove_color = Color("6e4a2c")
	ramp_marks.berm_color = Color("c9a46c")
	ramp_marks.seed = 5
	b.add(ramp_marks, g, "RampDragMarks")
	coin_trail(Vector3(-78.5, 1.6, 39), Vector3(-81.5, 1.6, 29), 4, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(-54.5, 2.2, -40) + gull, Vector3(-59.5, 4.9, -40) + gull, 4, 0.0, CoinTrail.TrailShape.LINE)
	# Shellby's chart leads to the north beach, by a cairn of stones.
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"castaway_x_north"
	x_spot.island_id = ISLAND
	x_spot.contents = "goblet"
	x_spot.gem_color = Palette.GEM_BLUE
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"castaway_map_2"
	x_spot.position = Vector3(-11.0, SAND, -88.5)
	b.add(x_spot, g, "NorthBeachX")
	var cairn := b.group("Cairn", g)
	rock(cairn, Vector3(-9.2, 1.2, -87.4), Vector3(1.3, 0.8, 1.2), StylizedRock.Preset.SAND_ROCK, 71, 20.0)
	rock(cairn, Vector3(-9.2, 1.85, -87.4), Vector3(0.9, 0.6, 0.85), StylizedRock.Preset.SAND_ROCK, 73, 70.0)
	rock(cairn, Vector3(-9.2, 2.3, -87.4), Vector3(0.55, 0.45, 0.5), StylizedRock.Preset.SAND_ROCK, 79, 140.0)


## Tok, the village lookout up his tower, who points out cages still locked;
## and Pip, a young otter on Driftwood Key whose lucky clam the pelican stole.
func _islanders() -> void:
	var tok := LookoutNPC.new()
	tok.display_name = "Tok"
	tok.lines = PackedStringArray([
		"Ahoy down there! ...Up here? Same thing. Tok's the name, lookout's the game.",
		"Nothing gets past this spyglass. Not crabs, not clouds, and definitely not caged parrots.",
		"Gus's sail? Oh, THAT sail. It made a lovely sunshade. Go on, take it.",
	])
	tok.repeat_lines = PackedStringArray(["Tok's spyglass sees all!", "Hold still, I'm looking...",
		"Ooh, a cloud shaped like a banana. Anyway!"])
	tok.cage_hints = PackedStringArray([
		"castaway_parrot_outpost|Look! The crabs locked a parrot up here on my own tower. Right behind you!",
		"castaway_parrot_wreck|I hear squawking from your shipwreck's crow's nest. Up the stern deck and keep climbing!",
		"castaway_parrot_summit|There's a cage on the forest summit. Over the rope bridge, then the terraces, or kick your way up the chimney.",
		"castaway_parrot_stack|A cage sits on the sea stack off the wreck. Only a mighty long jump gets you there.",
		"driftwood_parrot_tower|Southwest, over the water: Driftwood Key! A cage tops a tower of lashed rafts.",
		"driftwood_parrot_pen|More on Driftwood Key: the crabs keep one in a pen up on the knoll. Guarded, mind you.",
	])
	tok.all_free_lines = PackedStringArray(["Not a single cage left! The sky's full of your friends."])
	tok.talked_flag = &"castaway_met_tok"
	tok.position = TOWER + Vector3(-2.2, 14.1, -1.6)
	b.add(tok, gameplay, "Tok")
	var monkey := MonkeyModel.new()
	monkey.rotation.y = Player.yaw_of(Vector3(-1, 0, -0.6))
	b.add(monkey, tok, "MonkeyModel")
	tok.model = monkey
	var c := DRIFTWOOD
	var pip := FavorNPC.new()
	pip.display_name = "Pip"
	pip.lines = PackedStringArray([
		"Whoa, a real pirate! With a real hook!",
		"That greedy pelican swiped my lucky clam right out of my paws!",
		"Bop it when it swoops down low. It'll cough everything up, I bet!",
	])
	pip.waiting_lines = PackedStringArray(["Bop that pelican when it swoops low! My clam's in its pouch somewhere!"])
	pip.thanks_lines = PackedStringArray([
		"You chased off the pelican! And it coughed up my clam!",
		"...Huh, there's a pearl in it. You keep it, pirate. Pirates love pearls!",
	])
	pip.after_lines = PackedStringArray(["When I grow up I'm getting a hook too. Or at least a very pointy spoon."])
	pip.quest_flag = &"driftwood_met_pip"
	pip.done_flag = &"driftwood_pelican"
	pip.reward_flag = &"driftwood_pip_reward"
	pip.reward_kind = "pearl"
	pip.reward_id = &"driftwood_pip_pearl"
	pip.reward_island = ISLET
	pip.reward_color = Color("ffd9e8")
	pip.position = c + Vector3(8.5, 1.0, -19.0)
	b.add(pip, gameplay, "Pip")
	var otter := OtterModel.new()
	otter.rotation.y = Player.yaw_of(c + Vector3(12, 1.3, -24) - pip.position)
	b.add(otter, pip, "OtterModel")
	pip.model = otter
	# A fisher on the pier, for company.
	var fisher := NPC.new()
	fisher.display_name = "Marlo"
	fisher.lines = PackedStringArray([
		"Shh! You'll scare the fish. Not that there are any. Brock's crabs ate them all.",
		"Well, all the tasty ones.",
	])
	fisher.repeat_lines = PackedStringArray(["Still nothing. I think the fish are laughing at me.", "Heard Gus is fixing up his old dinghy. Lucky you!"])
	fisher.position = Vector3(-46.6, QUAY, 46.0)
	b.add(fisher, gameplay, "Marlo")
	var otter2 := OtterModel.new()
	otter2.rotation.y = Player.yaw_of(Vector3.RIGHT)
	b.add(otter2, fisher, "OtterModel")
	fisher.model = otter2


## The strait between the harbor and Driftwood Key (spec §117: no long
## stretches of nothing): a bell buoy to steer by, flotsam to ram for coins,
## a coin trail on the water, a pod of dolphins that races the boat, and
## Gull Bar, a sandbar islet just off the route with its own little prize.
func _crossing() -> void:
	var g := b.group("Crossing", gameplay)
	var buoy := BellBuoy.new()
	buoy.position = Vector3(-84, 0, 92)
	b.add(buoy, g, "BellBuoy")
	var k := 0
	for p: Vector3 in [Vector3(-62.5, 0, 87.5), Vector3(-70, 0, 86), Vector3(-93, 0, 101.5), Vector3(-100, 0, 100)]:
		k += 1
		var barrel := FloatingBarrel.new()
		barrel.barrel_id = StringName("crossing_barrel_%d" % k)
		barrel.position = p
		b.add(barrel, g, "FloatingBarrel")
	coin_trail(Vector3(-74, 1.0, 91), Vector3(-80, 1.0, 93.7), 5, 0.0, CoinTrail.TrailShape.LINE)
	var pod := DolphinPod.new()
	pod.position = Vector3(-80, 0, 100)
	b.add(pod, g, "DolphinPod")
	# Gull Bar: a sandbar off the harbor mouth, in Castaway's own waters,
	# with a palm, a crate of coins and a gem.
	var bar := Vector2(-30, 98)
	plateau(terrain, "GullBar", [bar + Vector2(-6, -2), bar + Vector2(-2, -4.5), bar + Vector2(4, -3.5), bar + Vector2(6.5, 0.5),
		bar + Vector2(2, 3.5), bar + Vector2(-4.5, 2.5)], 0.9, 4.0, "sand", {"shore": true, "shore_width": 6.0, "shore_drop": 2.6, "seed": 51})
	palm(g, Vector3(bar.x - 2.0, 0.9, bar.y - 0.8), 6.5, 18.0, 30.0, 131)
	crate_prop(g, Vector3(bar.x + 2.2, 0.9, bar.y + 0.6), "gull_bar_crate", 5, 20.0)
	gem(Vector3(bar.x + 3.6, 1.5, bar.y - 1.6), "gull_bar_gem", Color("ff9f43"))
	var dock := Marker3D.new()
	dock.position = Vector3(bar.x + 9.0, 0, bar.y + 4.0)
	b.add(dock, g, "GullBarMooring")
	var region := SeaRegion.new()
	region.region_name = "Gull Bar"
	region.island_id = ISLAND
	region.radius = 13.0
	region.position = Vector3(bar.x, 0, bar.y)
	region.boat_dock = dock
	region.arrival = dock
	b.add(region, g, "SeaRegionGullBar")


## Brock the Croc's first appearance (spec §100): after King Claw falls,
## his royal barge rows in under the headland's north cliff.
func _brock_cameo() -> void:
	var g := b.group("BrockCameo", gameplay)
	var cameo := BrockCameo.new()
	cameo.lines = PackedStringArray([
		"AHEM! AHEM!! Who has been bullying my crab king?",
		"...You? A soggy castaway with a hook for a hand? Ha!",
		"Behold BROCK THE CROC! Admiral of the Archipelago! Baron of Bananas! Keeper of Everyone Else's Treasure! Twice voted Handsomest Reptile!",
		"Keep your silly little wheel. The rest of your ship is scattered across MY islands, guarded by MY crabs. Good luck!",
		"Row, crabs! ROW! Toodle-oo!",
	])
	b.add(cameo, g, "BrockCameo")
	var marks := {}
	for d: Array in [["Lookout", Vector3(58, FOREST, -72.5), Vector3(0, 0, -1)], ["Hold", Vector3(58, 0, -97), Vector3(0, 0, 1)],
			["EnterFrom", Vector3(90, 0, -125), Vector3(-32, 0, 26)], ["ExitTo", Vector3(16, 0, -135), Vector3(-42, 0, -36)]]:
		var m := Marker3D.new()
		m.position = d[1]
		m.rotation.y = Player.yaw_of(d[2])
		b.add(m, g, d[0])
		marks[d[0]] = m
	cameo.lookout = marks["Lookout"]
	cameo.hold = marks["Hold"]
	cameo.enter_from = marks["EnterFrom"]
	cameo.exit_to = marks["ExitTo"]
	var barge := RoyalBarge.new()
	barge.position = (marks["EnterFrom"] as Marker3D).position
	b.add(barge, g, "RoyalBarge")
	cameo.barge = barge


## Emergent mischief at the grotto (spec §173–174): a crab scuttles about
## beside the TNT snail. Sooner or later it bumps the barrel, the snail
## blows, the crab goes flying and, as often as not, so does the cracked
## rock hiding the grotto.
func _grotto_mischief() -> void:
	var c := crab(Vector3(-7.5, 1.25, 36.5), CrabModel.Variant.NORMAL, "castaway_crab_grotto")
	c.patrol_radius = 3.5


## The Sunken Sloop (spec §114: dense underwater areas). Off the cove a
## little ship lies on the seabed among coral, kelp and fish. A chest sits
## in its lee, and a trail of coins leads down from the shallows.
func _sunken_reef() -> void:
	var g := b.group("SunkenReef", gameplay)
	var c := Vector3(6, -10.5, 78)
	var hull := HullSection.new()
	hull.length = 7.0
	hull.height = 2.8
	hull.beam = 1.8
	hull.lean_degrees = 28.0
	hull.damage = 0.7
	hull.damage_seed = 11
	hull.sink = 0.5
	hull.position = c
	hull.rotation_degrees.y = 25.0
	b.add(hull, g, "SunkenHull")
	var bow := BowPiece.new()
	bow.length = 4.0
	bow.height = 2.4
	bow.damage_seed = 9
	bow.sink = 0.45
	bow.position = c + Vector3(6.0, 0, -3.0)
	bow.rotation_degrees = Vector3(0, -65, 12)
	b.add(bow, g, "SunkenBow")
	var mast := BrokenMast.new()
	mast.height = 6.5
	mast.tilt_degrees = 48.0
	mast.tilt_direction = 120.0
	mast.tatter = 0.8
	mast.seed = 7
	mast.position = c + Vector3(-3.0, 0, 3.0)
	b.add(mast, g, "SunkenMast")
	var chest := TreasureChest.new()
	chest.chest_id = &"castaway_sunken_chest"
	chest.island_id = ISLAND
	chest.contents = "goblet"
	chest.coins = 8
	chest.position = c + Vector3(1.6, 0, 2.2)
	chest.rotation_degrees.y = 200.0
	chest.map_reward = &"driftwood_map_1"
	b.add(chest, g, "SunkenChest")
	var k := 0
	for d: Array in [[Vector3(-5, 0, -3), 1.2], [Vector3(4, 0, 4.5), 1.0], [Vector3(-1.5, 0, -5.5), 0.8], [Vector3(8.5, 0, 2), 1.1],
			[Vector3(-7, 0, 4), 0.9], [Vector3(2.5, 0, -8), 1.3], [Vector3(-9, 0, -2), 0.7], [Vector3(10, 0, -6), 0.9]]:
		k += 1
		var cc := CoralCluster.new()
		cc.seed = 20 + k
		cc.size = d[1]
		cc.position = c + d[0]
		b.add(cc, g, "Coral")
	for d: Array in [[Vector3(-6, 0, 7), 7, 5.5], [Vector3(7, 0, 8), 6, 6.5], [Vector3(-10, 0, -7), 9, 7.5]]:
		k += 1
		var kelp := KelpBed.new()
		kelp.seed = k
		kelp.count = d[1]
		kelp.height = d[2]
		kelp.position = c + d[0]
		b.add(kelp, g, "Kelp")
	var school := FishSchool.new()
	school.position = c + Vector3(-1, 3.0, 0)
	b.add(school, g, "FishSchoolYellow")
	var school2 := FishSchool.new()
	school2.count = 10
	school2.radius = 1.8
	school2.body_color = Color("ff8a3d")
	school2.stripe_color = Color("fff6e0")
	school2.position = c + Vector3(6, 2.0, 5)
	b.add(school2, g, "FishSchoolOrange")
	gem(c + Vector3(-5, 1.25, -3), "castaway_gem_reef", Color("ff5fa2"))
	coin_trail(Vector3(1, -2.0, 63), Vector3(4.5, -8.6, 72.5), 7, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(c + Vector3(-4, 1.6, -8), Vector3.ZERO, 8, 0.0, CoinTrail.TrailShape.RING)
	var hint := TutorialHint.new()
	hint.hint_id = &"hint_swim_down"
	hint.text = "Swim down with {dive}, back up with {jump}. Something glints below..."
	hint.size = Vector3(18, 6, 12)
	hint.position = Vector3(4, -1.0, 66)
	b.add(hint, g, "HintSwimDown")


## Beak Rock (spec §194): the Sunken Sloop's chest holds a map of a little
## island with a stone parrot on it. It's Driftwood Key, sailed past on the
## way to the tower parrot: the parrot-shaped rock by the raft tower keeps
## watch along the south beach, and the X is in the sand where its beak
## points.
func _beak_rock() -> void:
	var g := b.group("BeakRock", gameplay)
	var rock := BeakRock.new()
	rock.position = DRIFTWOOD + Vector3(-13.5, 1.0, 14.0)
	rock.rotation.y = Player.yaw_of(Vector3(1, 0, -0.25))
	b.add(rock, g, "BeakRock")
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"driftwood_x_beak"
	x_spot.island_id = ISLET
	x_spot.contents = "crown"
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"driftwood_map_1"
	x_spot.position = rock.transform * rock.beak_target()
	b.add(x_spot, g, "BeakX")


# --- Tutorial hints -----------------------------------------------------------------

func _hints() -> void:
	var g := b.group("Hints", gameplay)
	for d: Array in [
			["hint_jump", Vector3(0, SAND, 29.5), Vector3(14, 4, 8), "{jump} Jump - hold it to jump higher", &"", &""],
			["hint_dive", Vector3(18, SAND, 35), Vector3(10, 4, 8), "While running, {dive} to dive  ·  {jump} to roll out", &"", &""],
			["hint_swipe", Vector3(-2, LOW, 12), Vector3(14, 4, 10), "{attack} Hook swipe  ·  armored crabs need a ground pound", &"", &""],
			["hint_ledge", Vector3(-27.5, UPPER, -7), Vector3(5, 4, 7), "Jump at a ledge to grab it  ·  {jump} to climb up", &"", &""],
			["hint_wall_kick", _n(Vector3(1.2, 7.0, -20.5)), Vector3(5, 4, 4), "Slide down a wall and press {jump} to wall-kick", &"", &""],
			["hint_long_jump", Vector3(55.5, 8.0, 38), Vector3(4, 3, 4), "Long jump: run, hold {crouch} and press {jump}", &"", &""],
			["hint_ground_pound", _h(Vector3(62, 7.5, -16)), Vector3(14, 4, 14), "In the air, press {ground_pound} to ground pound", &"", &""],
			["hint_ring", Vector3(-7, 4.5, 49), Vector3(7, 3, 7), "Jump at a golden ring and press {tool_primary} to swing", &"", &""],
			["hint_boat", Vector3(-48, QUAY, 55), Vector3(6, 3, 10), "{interact} Board the boat  ·  steer with the stick, {jump} to hop out", &"", DINGHY],
			["hint_tools", _n(Vector3(11, 7.0, -36)), Vector3(8, 4, 6), "Swap hand attachments with {tool_previous} / {tool_next}", &"shovel", &""]]:
		var h := TutorialHint.new()
		h.hint_id = StringName(d[0])
		h.position = d[1]
		h.size = d[2]
		h.text = d[3]
		h.require_attachment = d[4]
		h.require_flag = d[5]
		b.add(h, g, String(d[0]).capitalize().replace(" ", ""))


# --- Dressing (props kit) -----------------------------------------------------------

func _decorate() -> void:
	var nature := b.group("Nature")
	var props := b.group("Props")
	var k := 0
	# Palms: along the beaches leaning seaward, round the village, and the
	# forest on the north half thick with them.
	for d: Array in [
			[Vector3(-10, SAND, 40.5), 7.5, 18.0, 160.0], [Vector3(8, SAND, 41.0), 6.5, 22.0, 200.0], [Vector3(17, SAND, 39.5), 8.5, 14.0, 150.0],
			[Vector3(-19, SAND, 48.0), 6.0, 20.0, 190.0], [Vector3(-88, SAND, 22.0), 7.0, 18.0, 90.0], [Vector3(-92, SAND, 40.0), 8.0, 12.0, 70.0],
			[Vector3(-80, SAND, 52.0), 6.5, 20.0, 120.0], [Vector3(80, SAND, 12.0), 7.5, 20.0, -90.0], [Vector3(70, SAND, 27.0), 6.0, 22.0, -130.0],
			[Vector3(30, SAND, 52.0), 7.0, 16.0, 180.0], [Vector3(-68, LOW, 22.5), 7.0, 10.0, 30.0], [Vector3(-38.5, LOW, 24.5), 6.5, 12.0, -20.0],
			[Vector3(-70.5, UPPER, -9.0), 7.0, 8.0, 0.0], [Vector3(-30.0, UPPER, -9.0), 6.5, 10.0, 60.0], [Vector3(10, LOW, 20.0), 8.0, 8.0, 30.0],
			[Vector3(22, LOW, 6.0), 7.0, 10.0, -60.0], [Vector3(60, LOW, -8.0), 7.5, 12.0, 0.0], [Vector3(82, LOW, 0.0), 6.5, 14.0, -90.0],
			[Vector3(-22, BLUFF, -9.0), 6.0, 10.0, 90.0], [_h(Vector3(76, 7.5, -14)), 7.5, 14.0, 60.0], [_h(Vector3(48, 7.5, -26)), 7.0, 12.0, -60.0],
			[_h(Vector3(80, 7.5, -44)), 6.5, 16.0, -120.0], [Vector3(-60, SAND, -86), 7.0, 18.0, 180.0], [Vector3(10, SAND, -88), 6.5, 20.0, 170.0]]:
		k += 1
		palm(nature, d[0], d[1], d[2], d[3], k * 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var woods: PackedVector2Array = Geometry2D.offset_polygon(PackedVector2Array(FOREST_OUTLINE), -5.0)[0]
	var placed: Array[Vector2] = []
	for i in 400:
		if placed.size() >= 64:
			break
		var p := Vector2(rng.randf_range(-80, 27), rng.randf_range(-81, -27))
		if not Geometry2D.is_point_in_polygon(p, woods):
			continue
		# Keep clear of the summit, its terraces, the cave, the log and the
		# path off the bridge, and of each other.
		if p.x > -47 and p.x < 12 and p.y > -70 and p.y < -27:
			continue
		if p.x > 0 and p.y > -46:
			continue
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 5.5):
			continue
		placed.append(p)
		k += 1
		if rng.randf() < 0.25:
			palm(nature, Vector3(p.x, FOREST, p.y), rng.randf_range(6.0, 9.5), rng.randf_range(2.0, 14.0), rng.randf_range(0.0, 360.0), k * 7)
		else:
			tree(nature, Vector3(p.x, FOREST, p.y), rng.randf_range(6.0, 10.0), rng.randf_range(2.4, 3.6), 0 if rng.randf() < 0.6 else 1, k * 13)
	# A few round trees about the village and the meadow too.
	for d: Array in [[Vector3(-74, LOW, 10), 6.5, 2.6, 0], [Vector3(-34, UPPER, -10), 6.0, 2.4, 2], [Vector3(4, LOW, 22), 7.0, 2.8, 0],
			[Vector3(30, LOW, -6), 7.5, 3.0, 1], [Vector3(-22, LOW, 9), 6.0, 2.4, 2]]:
		k += 1
		tree(nature, d[0], d[1], d[2], d[3], k * 13)
	# Rocks: cliff-foot clusters, beach boulders and a few in the shallows.
	var rk := 0
	for d: Array in [
			[Vector3(26, SAND, 30), Vector3(2.4, 1.6, 2.0), StylizedRock.Preset.SAND_ROCK], [Vector3(27.5, SAND, 28.2), Vector3(1.2, 0.8, 1.1), StylizedRock.Preset.SAND_ROCK],
			[Vector3(60, SAND, 21), Vector3(2.6, 1.8, 2.2), StylizedRock.Preset.CLIFF_ROCK], [Vector3(32, 0.2, 54), Vector3(2.0, 1.6, 1.8), StylizedRock.Preset.DARK_ROCK],
			[Vector3(-96, 0.2, 52), Vector3(2.4, 1.8, 2.2), StylizedRock.Preset.DARK_ROCK], [Vector3(-8, LOW, 22.0), Vector3(1.0, 0.7, 0.9), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(-34, FOREST, -40), Vector3(1.6, 1.0, 1.4), StylizedRock.Preset.MOSSY], [Vector3(82, FOREST, -36), Vector3(1.8, 1.2, 1.6), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(-60, FOREST, -60), Vector3(2.2, 1.4, 2.0), StylizedRock.Preset.MOSSY], [Vector3(84, SAND, 6), Vector3(2.2, 1.5, 2.0), StylizedRock.Preset.SAND_ROCK],
			[Vector3(-40, SAND, -90), Vector3(2.0, 1.4, 1.8), StylizedRock.Preset.SAND_ROCK], [Vector3(16, SAND, -92), Vector3(1.6, 1.1, 1.4), StylizedRock.Preset.DARK_ROCK]]:
		rk += 1
		rock(nature, d[0], d[1], d[2], rk * 11, rk * 37.0)
	# Grass, flowers, bushes and ferns on every grassy top; pebbles on sand.
	var grass_only: Array[StringName] = [&"grass"]
	var sand_only: Array[StringName] = [&"sand"]
	scatter(nature, Vector3(0, 20, -14), Vector2(200, 180), PropScatter.Kind.GRASS, 0.36, grass_only, 3, 11000)
	scatter(nature, Vector3(0, 20, -14), Vector2(200, 180), PropScatter.Kind.FLOWERS, 0.03, grass_only, 5, 1000)
	scatter(nature, Vector3(0, 20, -14), Vector2(200, 180), PropScatter.Kind.BUSHES, 0.005, grass_only, 7, 200)
	scatter(nature, Vector3(-26, 20, -55), Vector2(100, 50), PropScatter.Kind.FERNS, 0.05, grass_only, 9, 400)
	scatter(nature, Vector3(0, 20, -14), Vector2(200, 200), PropScatter.Kind.PEBBLES, 0.008, sand_only, 11, 700)
	# Wreck beach: debris, a crate of coins, an anchor.
	for d: Array in [[Vector3(50, SAND, 30), 4.0, 3], [Vector3(36, SAND, 39), 3.0, 5], [Vector3(64, SAND, 30), 3.5, 9]]:
		var deb := ShipDebris.new()
		deb.radius = d[1]
		deb.seed = d[2]
		deb.position = d[0]
		b.add(deb, props, "ShipDebris")
	crate_prop(props, Vector3(57.0, SAND, 33.0), "castaway_crate_wreck", 4, 30.0)
	var anchor := Anchor.new()
	anchor.position = Vector3(57.5, SAND, 43.0)
	anchor.rotation_degrees = Vector3(0, 40, 0)
	b.add(anchor, props, "Anchor")
	# An old cannon on the bluff, pointing out to sea.
	var gun := DecorCannon.new()
	gun.position = Vector3(1.5, BLUFF, -2.0)
	gun.rotation_degrees.y = -90.0
	b.add(gun, props, "BluffCannon")


func _opening() -> void:
	var seq := OpeningSequence.new()
	b.add(seq, null, "OpeningSequence")
	var cam := Marker3D.new()
	cam.position = Vector3(6, 5.5, 118)
	b.add(cam, seq, "VignetteCamera")
	var look := Marker3D.new()
	look.position = Vector3(0, 0.0, 96)
	b.add(look, seq, "VignetteTarget")
	seq.vignette_camera = cam
	seq.vignette_target = look
	seq.crab_dragging = crab(Vector3(5, 1.25, 31.5), CrabModel.Variant.NORMAL, "", gameplay.get_node("CoveBurrow"))
	seq.crab_noticing = crab(Vector3(-3.5, 1.25, 30.5), CrabModel.Variant.NORMAL, "", gameplay.get_node("CoveBurrow"))
	seq.crab_dragging.dormant = true
	seq.crab_noticing.dormant = true
