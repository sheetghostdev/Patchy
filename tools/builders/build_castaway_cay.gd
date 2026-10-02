extends RefCounted
## Generates res://world/islands/castaway_cay/castaway_cay.tscn — the opening
## island (spec §72–77, §146–153). "The sunny wreck-strewn cove where Patchy
## washes ashore and his treasure is scattered across the island."
##
## Layout (x east, z south, sea level y=0):
##  - South cove: Patchy washes ashore; crabs drag off his gold.
##  - East beach: the shipwreck (parrot #1 in the crow's nest) and a sea
##    stack reachable by long jump (parrot #4).
##  - West outpost: huts, Old Shellby, a crab-guarded watchtower (parrot #2),
##    the broken dock with Patchy's tiny boat.
##  - Center: grassy meadow, a 4 m ledge-grab cliff up to the ridge.
##  - North: hill lookout (ship part + parrot #3) via terraces or a wall-kick
##    chimney; the dark cave tease beside it.
##  - East headland across the gorge: only reachable by the six-parrot log
##    bridge; a chained-chest ground-pound puzzle and a grapple tease.
##  - Cove's west horn: a hook-ring run to a gem pillar.
##   tools/builders/build.sh castaway_cay

const PLAYER := "res://characters/patchy/player.tscn"
const RIG := "res://systems/camera/camera_rig.tscn"
const CRAB := "res://enemies/crab/crab.tscn"
const ISLAND := &"castaway_cay"
const ISLET := &"driftwood_key"
## Driftwood Key: a small neighbor islet south-west of the dock (by boat).
const DRIFTWOOD := Vector3(-130, 0, 140)

var b: SceneBuilder
var terrain: Node3D
var structures: Node3D
var gameplay: Node3D
var treasure: Node3D
var enemies: Node3D


func build() -> void:
	# Deterministic builds: regenerating the island gives an identical scene.
	seed(20261002)
	b = SceneBuilder.new("CastawayCay")
	var info := IslandInfo.new()
	info.island_id = ISLAND
	info.display_name = "Castaway Cay"
	info.music = &"castaway_explore"
	# The chest's crown is spawned when it opens.
	info.extra_treasures = 1
	info.sub_islands = [ISLET]
	b.add(info, null, "IslandInfo")
	var env := SkyEnvironment.new()
	env.preset = SkyEnvironment.Preset.CASTAWAY_DAY
	env.shadow_distance = 160.0
	b.add(env, null, "SkyEnvironment")
	b.add(Ambience.new(), null, "Ambience")
	b.add(Weather.new(), null, "Weather")
	terrain = b.group("Terrain")
	structures = b.group("Structures")
	gameplay = b.group("Gameplay")
	treasure = b.group("Treasure")
	enemies = b.group("Enemies")

	_terrain()
	_sea()
	_cove()
	_shipwreck()
	_outpost()
	_dock()
	_ridge_and_hill()
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

	var player := b.instance(PLAYER, null, Vector3(0, 1.25, 33), 0.0, "Player")
	var rig := b.instance(RIG, null, Vector3(0, 3, 40), 0.0, "CameraRig")
	rig.set(&"target", player)
	_opening(player)
	b.save("res://world/islands/castaway_cay/castaway_cay.tscn")


# --- Helpers ------------------------------------------------------------------------

func plateau(parent: Node, node_name: String, outline: Array, height: float, depth: float, surface: String, opts: Dictionary = {}) -> Plateau:
	var p := Plateau.new()
	var pts := PackedVector2Array()
	for v: Vector2 in outline:
		pts.append(v)
	p.outline = pts
	p.height = height
	p.depth = depth
	p.surface = surface
	p.noise_seed = opts.get("seed", node_name.hash() % 97)
	if opts.has("shore"):
		p.shore = true
		p.shore_width = opts.get("shore_width", 12.0)
		p.shore_drop = opts.get("shore_drop", 4.0)
	if opts.has("bevel"):
		p.bevel = opts.bevel
	if opts.has("smoothing"):
		p.smoothing = opts.smoothing
	p.no_ledge_grab = opts.get("no_ledge_grab", false)
	p.slide_surface = opts.get("slide", false)
	b.add(p, parent, node_name)
	if opts.get("no_wall_kick", false):
		p.add_to_group(&"no_wall_kick", true)
	return p


func blk(parent: Node, pos: Vector3, size: Vector3, surface: String, rot := Vector3.ZERO, shape: LevelBlock.Shape = LevelBlock.Shape.BOX, node_name: String = "Block") -> LevelBlock:
	var l := b.block(parent, pos, size, surface, "", shape, 0.0, node_name)
	l.rotation_degrees = rot
	return l


func coin_trail(pos: Vector3, end: Vector3, count: int, arc: float = 0.0, shape: CoinTrail.TrailShape = CoinTrail.TrailShape.ARC) -> CoinTrail:
	var t := CoinTrail.new()
	t.shape = shape if arc > 0.0 or shape != CoinTrail.TrailShape.ARC else CoinTrail.TrailShape.LINE
	t.end_point = end - pos
	t.arc_height = arc
	t.count = count
	t.position = pos
	b.add(t, treasure, "CoinTrail")
	return t


func gem(pos: Vector3, id: String, color: Color, kind: String = "gem") -> Collectible:
	var c := Collectible.new()
	c.kind = kind
	c.treasure_id = StringName(id)
	c.island_id = ISLAND
	c.gem_color = color
	c.position = pos
	b.add(c, treasure, id.capitalize().replace(" ", ""))
	return c


func heart(pos: Vector3) -> void:
	var c := Collectible.new()
	c.kind = "heart"
	c.position = pos
	b.add(c, treasure, "Heart")


func crab(pos: Vector3, variant: CrabModel.Variant = CrabModel.Variant.NORMAL, id: String = "", burrow: Node3D = null) -> Crab:
	var c: Crab = b.instance(CRAB, enemies, pos, randf() * 360.0, "Crab")
	c.variant = variant
	if id != "":
		c.persistent_id = StringName(id)
	if burrow != null:
		c.burrow = burrow
	return c


func cage(pos: Vector3, id: String, plumage: ParrotModel.Plumage, hanging: bool = false) -> ParrotCage:
	var c := ParrotCage.new()
	c.parrot_id = StringName(id)
	c.island_id = ISLAND
	c.plumage = plumage
	c.hanging = hanging
	c.position = pos
	b.add(c, gameplay, "ParrotCage_" + id)
	return c


# --- Terrain ------------------------------------------------------------------------

func _terrain() -> void:
	# Sandy island body with beaches sloping into the sea.
	plateau(terrain, "Beach", [Vector2(-84, 12), Vector2(-80, -22), Vector2(-66, -48), Vector2(-40, -66), Vector2(-8, -74),
		Vector2(24, -70), Vector2(52, -60), Vector2(76, -38), Vector2(88, -8), Vector2(86, 22), Vector2(72, 40),
		Vector2(54, 52), Vector2(34, 56), Vector2(18, 46), Vector2(2, 42), Vector2(-14, 46), Vector2(-28, 58),
		Vector2(-50, 64), Vector2(-70, 48)], 1.2, 10.0, "sand", {"shore": true, "shore_width": 16.0, "shore_drop": 5.0})
	# Grassy meadow, 1.8 m above the sand: one good jump.
	plateau(terrain, "Meadow", [Vector2(-62, 6), Vector2(-58, -26), Vector2(-40, -48), Vector2(-10, -58), Vector2(18, -56),
		Vector2(26, -40), Vector2(26, -12), Vector2(24, 10), Vector2(14, 22), Vector2(0, 26), Vector2(-16, 28),
		Vector2(-36, 32), Vector2(-56, 26)], 3.0, 4.0, "cliff")
	# A gentle grass ramp from the outpost beach up to the meadow.
	blk(terrain, Vector3(-44, 1.15, 33), Vector3(7, 1.9, 7), "grass", Vector3.ZERO, LevelBlock.Shape.RAMP, "MeadowRamp")
	# The ridge: 4 m cliffs (ledge-grab height from the meadow).
	plateau(terrain, "Ridge", [Vector2(-48, -12), Vector2(-44, -32), Vector2(-28, -46), Vector2(-6, -52), Vector2(12, -50),
		Vector2(19, -36), Vector2(19, -8), Vector2(8, 2), Vector2(-12, 4), Vector2(-34, 0)], 7.0, 4.2, "cliff")
	# Ridge access for the cautious: wooden stairs at the west end.
	blk(structures, Vector3(-50, 2.95, -8), Vector3(3, 4.1, 7), "wood", Vector3(0, -90, 0), LevelBlock.Shape.STAIRS, "RidgeStairs")
	# The hill and its stepping terraces (1.8 m steps).
	plateau(terrain, "Hill", [Vector2(-26, -30), Vector2(-20, -42), Vector2(-6, -46), Vector2(6, -42), Vector2(8, -30),
		Vector2(-4, -24), Vector2(-18, -22)], 12.4, 5.6, "cliff", {"seed": 5})
	plateau(terrain, "Terrace1", [Vector2(-36, -26), Vector2(-29, -31), Vector2(-23, -27), Vector2(-25, -18), Vector2(-33, -18)], 8.8, 2.0, "cliff", {"seed": 7})
	plateau(terrain, "Terrace2", [Vector2(-24, -21), Vector2(-15, -23), Vector2(-10, -19), Vector2(-13, -12), Vector2(-21, -13)], 10.6, 3.8, "cliff", {"seed": 9})
	# East headland across the gorge (sheer, no wall kicks: bridge only).
	plateau(terrain, "Headland", [Vector2(36, -56), Vector2(58, -50), Vector2(76, -30), Vector2(82, -4), Vector2(74, 14),
		Vector2(54, 18), Vector2(40, 10), Vector2(35, -14), Vector2(35, -38)], 7.5, 6.5, "cliff", {"seed": 13, "no_wall_kick": true})
	# Cove horn rock and sea pillars.
	plateau(terrain, "WestHorn", [Vector2(-30, 46), Vector2(-24, 44), Vector2(-20, 49), Vector2(-24, 54), Vector2(-30, 52)], 4.5, 8.0, "rock", {"seed": 21})
	plateau(terrain, "GemPillar", [Vector2(-4, 62), Vector2(1, 61), Vector2(3, 65), Vector2(-1, 68), Vector2(-5, 66)], 4.0, 12.0, "rock", {"seed": 23})
	# Summit slide: a sandy chute from the hill back down to the meadow (loopback).
	var chute := blk(terrain, Vector3(-33, 2.95, -40), Vector3(5, 9.4, 18), "sand", Vector3(0, 125, 0), LevelBlock.Shape.RAMP, "SummitSlide")
	chute.slide_surface = true


func _sea() -> void:
	# The stylized ocean: endless LOD surface, waves synced with swimming and
	# the boat, shallows that show the sand, shoreline foam.
	var ocean := Ocean.new()
	ocean.swim_area_size = Vector2(560, 560)
	ocean.swim_depth = 14.0
	# Gentler bob for swimming than the drawn waves (readable platforming).
	ocean.gameplay_wave_scale = 0.6
	b.add(ocean, null, "Ocean")
	b.add(UnderwaterEffect.new(), null, "UnderwaterEffect")
	# Sandy seabed so the water shades consistently.
	blk(terrain, Vector3(0, -11, 0), Vector3(560, 1, 560), "sand", Vector3.ZERO, LevelBlock.Shape.BOX, "Seabed")


func _sea_regions() -> void:
	var sea := OpenSea.new()
	b.add(sea, null, "OpenSea")
	var home := SeaRegion.new()
	home.region_name = "Castaway Cay"
	home.island_id = ISLAND
	home.radius = 108.0
	home.position = Vector3(0, 0, -5)
	home.boat_dock = structures.get_node("Dock/BoatMooring")
	home.arrival = gameplay.get_node("SpawnDock")
	b.add(home, gameplay, "SeaRegionCastaway")
	var islet := SeaRegion.new()
	islet.region_name = "Driftwood Key"
	islet.island_id = ISLET
	islet.radius = 42.0
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
	zone.size = Vector3(190, 60, 184)
	zone.position = Vector3(2, 10, -6)
	b.add(zone, gameplay, "IslandZoneCastaway")


# --- Areas --------------------------------------------------------------------------

func _cove() -> void:
	var burrow := CrabBurrow.new()
	burrow.position = Vector3(34, 1.2, 28)
	b.add(burrow, gameplay, "CoveBurrow")
	# The coin arc that teaches the first jump onto the meadow.
	coin_trail(Vector3(-2.5, 1.2, 30.0), Vector3(-2.5, 3.0, 24), 6, 2.2)
	heart(Vector3(-8, 3.6, 18))


func _shipwreck() -> void:
	var g := b.group("Shipwreck", structures)
	# Patchy's ship's stern half, beached and tilted: run up the deck, hop
	# onto the cabin roof, then up into the crow's nest (parrot #1).
	blk(g, Vector3(44, 1.2, 38), Vector3(5.0, 3.0, 10.0), "wood", Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "SternDeck")
	for side: float in [-1.0, 1.0]:
		blk(g, Vector3(44, 1.2, 38 + side * 2.68), Vector3(0.35, 3.7, 10.0), "wood_dark", Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "HullSide")
	blk(g, Vector3(51.25, 1.2, 38), Vector3(4.5, 4.8, 5.7), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "Cabin")
	blk(g, Vector3(51.25, 6.0, 38), Vector3(4.9, 0.25, 6.1), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "CabinRoof")
	# The captain's cabin door: the hub where treasure, parrots and ship parts
	# are on display.
	var cabin_door := SceneDoor.new()
	cabin_door.target_scene = "res://world/hub/captains_cabin.tscn"
	cabin_door.spawn_id = &"door"
	cabin_door.label = "Captain's cabin"
	cabin_door.position = Vector3(51.25, 1.2, 40.95)
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
	blk(g, Vector3(55.5, 1.2, 38), Vector3(0.9, 8.6, 0.9), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Mast")
	blk(g, Vector3(55.5, 7.6, 38), Vector3(3.4, 0.45, 3.4), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "CrowsNest")
	cage(Vector3(55.5, 8.05, 39.2), "castaway_parrot_wreck", ParrotModel.Plumage.SCARLET)
	gem(Vector3(55.5, 10.6, 38), "castaway_gem_masthead", Palette.GEM_BLUE)
	# The bow half lies further down the beach.
	var bow := BowPiece.new()
	bow.length = 5.0
	bow.height = 2.6
	bow.damage_seed = 4
	bow.position = Vector3(60.5, 1.2, 36.5)
	bow.rotation_degrees.y = -100.0
	b.add(bow, g, "Bow")
	var hull := HullSection.new()
	hull.length = 9.5
	hull.height = 3.4
	hull.lean_degrees = 18.0
	hull.damage_seed = 7
	hull.position = Vector3(44.0, 1.2, 34.4)
	hull.rotation_degrees.y = 180.0
	b.add(hull, g, "HullSection")
	for p: Vector3 in [Vector3(40.5, 1.2, 32.5), Vector3(42, 1.2, 31.6), Vector3(58.5, 1.2, 41.5)]:
		blk(g, p, Vector3(1.2, 1.2, 1.2), "wood", Vector3(0, 25, 0), LevelBlock.Shape.BOX, "Crate")
	# Broken mast lying on the sand: a balance beam.
	blk(g, Vector3(36, 1.2, 44.5), Vector3(0.9, 0.9, 12), "wood", Vector3(0, -60, 0), LevelBlock.Shape.CYLINDER, "FallenMast")
	crab(Vector3(46, 1.25, 31), CrabModel.Variant.HERMIT, "castaway_crab_wreck_1")
	crab(Vector3(58, 1.25, 33), CrabModel.Variant.NORMAL, "castaway_crab_wreck_2")
	crab(Vector3(38, 1.25, 26), CrabModel.Variant.CANNON, "castaway_crab_wreck_gunner")
	# A tall rock at the waterline, only reachable by a long jump from the
	# crow's nest (parrot #4).
	plateau(terrain, "WreckStack", [Vector2(59, 46), Vector2(62.5, 45.6), Vector2(64, 48.5), Vector2(62, 51.2), Vector2(58.8, 50.4)], 6.2, 14.0, "rock", {"seed": 25, "no_wall_kick": true})
	cage(Vector3(61.4, 6.2, 48.6), "castaway_parrot_stack", ParrotModel.Plumage.SUNNY)
	coin_trail(Vector3(56.4, 8.6, 40.0), Vector3(60.2, 7.0, 46.2), 5, 1.6)


func _outpost() -> void:
	var g := b.group("Outpost", structures)
	_hut(g, Vector3(-54, 3.0, 4), 10.0, Palette.COAT)
	_hut(g, Vector3(-46, 3.0, 18), -15.0, Color("2f8fe8"))
	_hut(g, Vector3(-60, 3.0, 18), 30.0, Color("f2b134"))
	# Lookout tower (parrot #2) climbed via stacked crates and a hut roof.
	for c: Vector3 in [Vector3(-38, 3.0, 2), Vector3(-38, 3.0, 6), Vector3(-42, 3.0, 2), Vector3(-42, 3.0, 6)]:
		blk(g, c, Vector3(0.5, 6.0, 0.5), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Stilt")
	blk(g, Vector3(-40, 9.0, 4), Vector3(5.4, 0.4, 5.4), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "TowerDeck")
	blk(g, Vector3(-40, 9.4, 1.5), Vector3(5.4, 0.9, 0.3), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "Rail")
	blk(g, Vector3(-44.5, 3.0, 9), Vector3(1.6, 1.6, 1.6), "wood", Vector3(0, 10, 0), LevelBlock.Shape.BOX, "CrateStep1")
	blk(g, Vector3(-46, 3.0, 11.2), Vector3(1.6, 3.2, 1.6), "wood", Vector3(0, -8, 0), LevelBlock.Shape.BOX, "CrateStep2")
	cage(Vector3(-40, 9.4, 5), "castaway_parrot_outpost", ParrotModel.Plumage.AZURE)
	crab(Vector3(-42, 3.05, 10), CrabModel.Variant.NORMAL, "castaway_crab_outpost_1")
	crab(Vector3(-36, 3.05, 8), CrabModel.Variant.ARMORED, "castaway_crab_outpost_2")
	gem(Vector3(-46, 9.2, 18), "castaway_gem_roof", Palette.GEM_RED)
	heart(Vector3(-56, 3.6, 10))
	var sign := Signpost.new()
	sign.texts = PackedStringArray(["Castaway Outpost", "Dock", "Ridge", "Shipwreck"])
	sign.directions = PackedFloat32Array([90.0, 180.0, 0.0, -90.0])
	sign.post_height = 2.6
	sign.position = Vector3(-48, 3.0, 28.6)
	b.add(sign, g, "OutpostSign")


func _hut(parent: Node, pos: Vector3, yaw: float, roof_color: Color) -> void:
	var h := b.group("Hut", parent)
	h.position = pos
	h.rotation_degrees.y = yaw
	for x: float in [-1.7, 1.7]:
		for z: float in [-1.7, 1.7]:
			blk(h, Vector3(x, 0, z), Vector3(0.35, 1.2, 0.35), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Stilt")
	blk(h, Vector3(0, 1.2, 0), Vector3(4.4, 0.3, 4.4), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "Floor")
	blk(h, Vector3(0, 1.5, 2.0), Vector3(4.0, 2.4, 0.3), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "Back")
	blk(h, Vector3(-2.0, 1.5, 0), Vector3(0.3, 2.4, 4.0), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "Left")
	blk(h, Vector3(2.0, 1.5, 0), Vector3(0.3, 2.4, 4.0), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "Right")
	blk(h, Vector3(-1.35, 1.5, -2.0), Vector3(1.4, 2.4, 0.3), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "FrontL")
	blk(h, Vector3(1.35, 1.5, -2.0), Vector3(1.4, 2.4, 0.3), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "FrontR")
	# Gable roof from two thatched ramps; the color identifies each hut.
	var surface := "roof_red" if roof_color == Palette.COAT else ("roof_blue" if roof_color.b > 0.8 else "thatch")
	var r1 := blk(h, Vector3(-1.25, 3.9, 0), Vector3(5.2, 1.5, 2.6), surface, Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "RoofL")
	r1.bevel = 0.05
	var r2 := blk(h, Vector3(1.25, 3.9, 0), Vector3(5.2, 1.5, 2.6), surface, Vector3(0, 90, 0), LevelBlock.Shape.RAMP, "RoofR")
	r2.bevel = 0.05


func _dock() -> void:
	var g := b.group("Dock", structures)
	var x := -52.0
	# Planks out over the water with a broken gap to jump (3 m).
	for d: Array in [["DockA", 57.0, 14.0, false], ["DockB", 74.0, 10.0, true]]:
		var dock := Dock.new()
		dock.length = d[2]
		dock.width = 3.2
		dock.post_depth = 9.0
		dock.water_line = -1.2
		dock.position = Vector3(x, 1.35, d[1])
		dock.rotation_degrees.y = 180.0
		b.add(dock, g, d[0])
	var lamp := LanternPost.new()
	lamp.position = Vector3(x - 2.2, 1.2, 55.5)
	lamp.rotation_degrees.y = 90.0
	b.add(lamp, g, "DockLamp")
	coin_trail(Vector3(x, 1.35, 60), Vector3(x, 1.35, 69), 5, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(x, 1.35, 70.4), Vector3(x, 1.35, 74.6), 4, 1.6)
	var goblet := gem(Vector3(x, 2.2, 83), "castaway_goblet_dock", Palette.GOLD, "goblet")
	goblet.gem_color = Palette.GEM_RED
	# Patchy's tiny patched sailboat, tied up beside the dock's far end.
	var boat := TinyBoat.new()
	boat.position = Vector3(x + 3.4, 0.0, 80)
	b.add(boat, g, "TinyBoat")
	var mooring := Marker3D.new()
	mooring.position = boat.position
	b.add(mooring, g, "BoatMooring")


func _ridge_and_hill() -> void:
	var g := b.group("RidgeHill", gameplay)
	# Ledge-grab teaching cliff: coins climb the 4 m face.
	coin_trail(Vector3(-4, 3.6, 7.5), Vector3(-4, 6.6, 6.0), 4, 0.0, CoinTrail.TrailShape.LINE)
	# Wall-kick chimney up the hill's south face (shortcut to the summit).
	blk(structures, Vector3(-1.2, 7.0, -23.0), Vector3(1.4, 6.2, 3.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChimneyA")
	blk(structures, Vector3(3.6, 7.0, -23.0), Vector3(1.4, 6.2, 3.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChimneyB")
	coin_trail(Vector3(1.2, 8.0, -21.6), Vector3(1.2, 12.6, -22.6), 5, 0.0, CoinTrail.TrailShape.LINE)
	# Terrace route coins.
	coin_trail(Vector3(-30, 7.2, -14), Vector3(-29, 9.0, -22), 4, 1.6)
	coin_trail(Vector3(-24, 9.0, -22), Vector3(-17, 10.8, -18), 4, 1.6)
	coin_trail(Vector3(-15, 10.8, -19), Vector3(-12, 12.6, -27), 4, 1.6)
	# Summit: ship part, parrot #3 in the old crow's nest, a gem, a lookout.
	var part := ShipPartPickup.new()
	part.part_id = &"compass"
	part.display_name = "Ship's Compass"
	part.position = Vector3(-6, 12.4, -36)
	b.add(part, g, "ShipCompass")
	blk(structures, Vector3(2, 12.4, -38), Vector3(0.9, 6.0, 0.9), "wood", Vector3(0, 0, -6), LevelBlock.Shape.CYLINDER, "BrokenMast")
	blk(structures, Vector3(2.6, 18.0, -38), Vector3(3.0, 0.4, 3.0), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "LookoutNest")
	cage(Vector3(-14, 12.4, -38), "castaway_parrot_summit", ParrotModel.Plumage.LIME)
	gem(Vector3(2.6, 19.0, -38), "castaway_gem_lookout", Palette.GEM_BLUE)
	crab(Vector3(-22, 7.05, -6), CrabModel.Variant.NORMAL, "castaway_crab_ridge")


func _cave() -> void:
	var g := b.group("DarkCave", structures)
	# A rocky tunnel mouth on the ridge beside the hill, opening north into
	# a chamber. Too dark for Patchy until he has the lantern.
	blk(g, Vector3(14.5, 7.0, -37.4), Vector3(6, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelWallN")
	blk(g, Vector3(13, 7.0, -31.6), Vector3(9, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelWallS")
	blk(g, Vector3(13, 11.0, -34.5), Vector3(10, 1.4, 7.4), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelRoof")
	# The chamber: floor slab over the ridge's edge, tall outer walls.
	blk(g, Vector3(13.5, 6.4, -42.6), Vector3(10.4, 0.6, 10.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberFloor")
	blk(g, Vector3(19.1, 3.0, -43.05), Vector3(1.2, 8.0, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallE")
	blk(g, Vector3(14.1, 3.0, -48.1), Vector3(11.2, 8.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallN")
	blk(g, Vector3(7.9, 7.0, -43.05), Vector3(1.2, 4.0, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallW")
	blk(g, Vector3(18.6, 3.0, -37.4), Vector3(2.2, 8.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallSE")
	blk(g, Vector3(13.5, 11.0, -43.05), Vector3(12.4, 1.4, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberRoof")
	var dz := DarknessZone.new()
	dz.size = Vector3(8.0, 4.0, 4.6)
	dz.inward = Vector3(-1, 0, 0)
	dz.refusal_depth = 2.2
	dz.position = Vector3(12.4, 9.0, -34.5)
	b.add(dz, gameplay, "CaveDarkness")
	var dz2 := DarknessZone.new()
	dz2.size = Vector3(10.0, 4.0, 9.6)
	dz2.inward = Vector3(0, 0, -1)
	dz2.refusal_depth = 0.6
	dz2.position = Vector3(13.5, 9.0, -42.8)
	b.add(dz2, gameplay, "ChamberDarkness")
	for z in [[-34.5, Vector3(9, 4, 4.6)], [-42.8, Vector3(10, 4, 9.6)]]:
		var zone := CameraZone.new()
		zone.distance_scale = 0.6
		zone.position = Vector3(12.8, 9.0, z[0])
		b.add(zone, gameplay, "CaveCameraZone")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = z[1]
		cs.shape = box
		b.add(cs, zone, "Shape")
	# Lantern puzzle: light both braziers to raise the gate.
	var fire_a := Brazier.new()
	fire_a.brazier_id = &"castaway_cave_brazier_a"
	fire_a.position = Vector3(10.0, 7.0, -40.6)
	b.add(fire_a, gameplay, "CaveBrazierA")
	var fire_b := Brazier.new()
	fire_b.brazier_id = &"castaway_cave_brazier_b"
	fire_b.position = Vector3(17.0, 7.0, -40.6)
	b.add(fire_b, gameplay, "CaveBrazierB")
	dz.lit_by = [fire_a, fire_b]
	dz2.lit_by = [fire_a, fire_b]
	var gate := Gate.new()
	gate.gate_id = &"castaway_cave_gate"
	gate.size = Vector3(10.4, 4.0, 0.4)
	gate.position = Vector3(13.5, 7.0, -42.6)
	gate.triggers = [fire_a, fire_b]
	b.add(gate, structures, "CaveGate")
	# Behind it: the shovel, a mound to try it on (a treasure map!) and a gem.
	var shovel := AttachmentPickup.new()
	shovel.attachment_id = &"shovel"
	shovel.position = Vector3(11.0, 7.0, -45.6)
	b.add(shovel, gameplay, "ShovelPickup")
	var mound := DigSpot.new()
	mound.spot_id = &"castaway_cave_mound"
	mound.island_id = ISLAND
	mound.contents = "map"
	mound.map_id = &"castaway_map_1"
	mound.position = Vector3(16.0, 7.0, -45.6)
	b.add(mound, gameplay, "CaveMapMound")
	gem(Vector3(13.5, 7.6, -46.6), "castaway_gem_cave", Color("ffb347"))
	# The map's X: under the old stump on the meadow.
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"castaway_x_spot"
	x_spot.island_id = ISLAND
	x_spot.contents = "relic"
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"castaway_map_1"
	x_spot.position = Vector3(-27.0, 3.0, 15.0)
	b.add(x_spot, gameplay, "TreasureMapX")
	blk(structures, Vector3(-29.2, 3.0, 13.2), Vector3(1.3, 0.9, 1.3), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "OldStump")


func _gorge_and_headland() -> void:
	var g := b.group("Headland", gameplay)
	# The log lies along the ridge edge; six parrots can lay it across.
	var log_body := FallenLog.new()
	log_body.length = 20.0
	log_body.position = Vector3(15, 7.75, -20)
	log_body.rotation_degrees.y = 90.0
	b.add(log_body, g, "FallenLog")
	# Set down bedded into both rims so its top is a single step up (0.3 m).
	var dest := Marker3D.new()
	dest.position = Vector3(27.0, 6.55, -22)
	b.add(dest, g, "LogBridgeSpot")
	var task := ParrotTask.new()
	task.task_id = &"castaway_log_bridge"
	task.required_parrots = 6
	task.carried = log_body
	task.destination = dest
	task.position = Vector3(12.5, 7.0, -18)
	b.add(task, g, "LogBridgeTask")
	# Chained-chest puzzle: pound all three mooring posts.
	var posts: Array[PoundPost] = []
	var center := Vector3(62, 7.5, -16)
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
	gem(Vector3(72, 8.2, -30), "castaway_gem_headland", Color("9b5cff"))
	# Brock's croc soldiers hold the headland: flank them or pound the ground.
	for d: Array in [[Vector3(52, 7.55, -10), "castaway_croc_1", 200.0], [Vector3(70, 7.55, -20), "castaway_croc_2", 120.0]]:
		var croc := CrocGrunt.new()
		croc.persistent_id = StringName(d[1])
		croc.position = d[0]
		croc.rotation_degrees.y = d[2]
		b.add(croc, enemies, "CrocGrunt")
	_boss_arena()
	# Grapple tease: a big iron ring on a sea pillar, far out of hook range.
	plateau(terrain, "GrapplePillar", [Vector2(86, -40), Vector2(91, -42), Vector2(94, -37), Vector2(90, -33), Vector2(85, -35)], 16.0, 22.0, "rock", {"seed": 31})
	# An old lookout pole on the pillar with a big iron ring: visible from
	# the headland, too far and too high for the hook.
	blk(structures, Vector3(88.3, 16.0, -37.3), Vector3(0.5, 5.8, 0.5), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "PillarPole")
	var tease := HookPoint.new()
	tease.grapple_only = true
	tease.grapple_arrival = "hop"
	tease.hang_length = 0.0
	tease.position = Vector3(87.6, 21.0, -36.6)
	tease.scale = Vector3.ONE * 2.0
	b.add(tease, g, "GrappleTease")
	# Up top: the hand cannon.
	var cannon := AttachmentPickup.new()
	cannon.attachment_id = &"cannon"
	cannon.position = Vector3(90.2, 16.0, -38.4)
	b.add(cannon, g, "CannonPickup")
	_cannon_secrets()


## King Claw's ring on the headland's north: tall rock spires with gaps.
## Stepping in wakes him; leaving resets the fight.
func _boss_arena() -> void:
	var g := b.group("ClawArena", structures)
	var center := Vector3(54, 7.5, -38)
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
	var cp := Checkpoint.new()
	cp.checkpoint_id = &"cp_claw_arena"
	cp.position = center + Vector3(-12.5, 0, 9.5)
	cp.respawn_yaw = 50.0
	b.add(cp, gameplay, "CpClawArena")


## Hand-cannon secrets: a cracked-rock grotto in the cove's west and a
## stone vault on the meadow that opens when two far-flung targets are hit.
func _cannon_secrets() -> void:
	var g := b.group("CannonSecrets", structures)
	var grotto := Vector3(-34, 1.2, 42)
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
	# The vault: walls of fitted stone and a gate tied to two targets.
	var v := Vector3(-36, 3.0, -16)
	blk(g, v + Vector3(0, 0, -2.2), Vector3(5.0, 3.6, 0.8), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultBack")
	blk(g, v + Vector3(-2.2, 0, 0), Vector3(0.8, 3.6, 5.0), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultW")
	blk(g, v + Vector3(2.2, 0, 0), Vector3(0.8, 3.6, 5.0), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultE")
	blk(g, v + Vector3(0, 3.6, 0), Vector3(5.6, 0.8, 5.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultRoof")
	var t1 := CannonTarget.new()
	t1.target_id = &"castaway_target_beach"
	t1.position = Vector3(-74, 1.2, -6)
	t1.rotation_degrees.y = -70.0
	b.add(t1, g, "TargetBeach")
	var t2 := CannonTarget.new()
	t2.target_id = &"castaway_target_horn"
	t2.position = Vector3(-26, 4.5, 49)
	t2.rotation_degrees.y = 160.0
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
	for p: Vector3 in [Vector3(-16.5, 8.4, 53.5), Vector3(-8.5, 8.6, 58.5)]:
		var hp := HookPoint.new()
		hp.position = p
		hp.hang_length = 1.6
		b.add(hp, g, "HookRing")
	gem(Vector3(-1, 5.2, 64.5), "castaway_gem_pillar", Palette.GEM_RED)
	coin_trail(Vector3(-21, 5.5, 51), Vector3(-17.5, 6.5, 53.2), 3, 0.8)


func _coins() -> void:
	# Breadcrumbs from the cove toward the shipwreck (parrot #1 early on).
	coin_trail(Vector3(10, 1.8, 34), Vector3(28, 1.8, 36), 7, 0.0, CoinTrail.TrailShape.LINE)
	# Up the tilted deck, onto the cabin and the nest.
	coin_trail(Vector3(40.5, 1.9, 38), Vector3(47.5, 4.3, 38), 5, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(48.4, 4.6, 38), Vector3(50.2, 6.6, 38), 3, 1.0)
	# Along the fallen mast.
	coin_trail(Vector3(31.5, 2.6, 47.1), Vector3(40.5, 2.6, 41.9), 5, 0.0, CoinTrail.TrailShape.LINE)
	# A ring around the meadow's armored crab encourages a ground pound.
	coin_trail(Vector3(-12, 3.6, 12), Vector3.ZERO, 8, 0.0, CoinTrail.TrailShape.RING)
	crab(Vector3(-12, 3.05, 12), CrabModel.Variant.ARMORED, "castaway_crab_meadow_armored")
	crab(Vector3(4, 3.05, 4), CrabModel.Variant.NORMAL, "castaway_crab_meadow")
	# A greedy pelican patrols the wreck beach; TNT snails wander near cracked
	# rock (kick a barrel at the grotto before the cannon turns up).
	var bird := Pelican.new()
	bird.persistent_id = &"castaway_pelican_wreck"
	bird.position = Vector3(46, 1.2, 34)
	b.add(bird, enemies, "PelicanWreck")
	var snail := TNTSnail.new()
	snail.position = Vector3(-27.5, 1.25, 37.5)
	snail.rotation_degrees.y = 60.0
	b.add(snail, enemies, "SnailGrotto")
	var snail2 := TNTSnail.new()
	snail2.position = Vector3(-30, 3.05, -10)
	b.add(snail2, enemies, "SnailVault")


func _checkpoints() -> void:
	for d: Array in [["cp_cove", Vector3(-6, 1.2, 30), 0.0], ["cp_outpost", Vector3(-48, 3.0, 12), 0.0],
			["cp_ridge", Vector3(-24, 7.0, -4), 0.0], ["cp_summit", Vector3(-10, 12.4, -32), 0.0]]:
		var cp := Checkpoint.new()
		cp.checkpoint_id = StringName(d[0])
		cp.position = d[1]
		cp.respawn_yaw = d[2]
		b.add(cp, gameplay, String(d[0]).capitalize().replace(" ", ""))
	for spot: Array in [["Cove", Vector3(0, 1.3, 33)], ["Wreck", Vector3(40, 1.3, 30)], ["Outpost", Vector3(-48, 3.1, 12)], ["GullRock", Vector3(-63.5, 5.5, -40)],
			["Ridge", Vector3(-24, 7.1, -4)], ["Summit", Vector3(-10, 12.5, -32)], ["Headland", Vector3(55, 7.6, -14)], ["Dock", Vector3(-52, 1.4, 62)]]:
		var m := Marker3D.new()
		m.position = spot[1]
		b.add(m, gameplay, "Teleport" + String(spot[0]))
		m.add_to_group(&"debug_teleport", true)
	# Arrival point for the boat (SceneTransition spawn id "dock").
	var dock := Marker3D.new()
	dock.position = Vector3(-52, 1.4, 80)
	dock.set_meta(&"spawn_id", &"dock")
	b.add(dock, gameplay, "SpawnDock")
	dock.add_to_group(&"spawn_point", true)


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
	var cp := Checkpoint.new()
	cp.checkpoint_id = &"cp_driftwood"
	cp.position = c + Vector3(10, 1.0, -17)
	cp.respawn_yaw = 200.0
	b.add(cp, g, "CpDriftwood")
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
## the Barnacle Betty, and hauled her up Gull Rock on the north-west beach.
## Follow the drag marks up the beach and the crabs' plank ramp, grab the
## ledge to the top, and call three parrots to fly her home to Shellby's
## jetty. Shellby pays with his old chart, whose X is on the north beach.
func _barnacle_betty() -> void:
	var g := b.group("BarnacleBetty", gameplay)
	# Shellby's jetty on the west beach, and the empty water beside it.
	var jetty := Dock.new()
	jetty.length = 12.0
	jetty.width = 2.6
	jetty.post_depth = 7.0
	jetty.water_line = -1.2
	jetty.position = Vector3(-79.5, 1.35, 18.0)
	jetty.rotation_degrees.y = 90.0
	b.add(jetty, structures, "ShellbyJetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(-88.5, 0.0, 15.4)
	mooring.rotation_degrees.y = 90.0
	b.add(mooring, g, "BettyMooring")
	var npc := FavorNPC.new()
	npc.display_name = "Old Shellby"
	npc.lines = PackedStringArray([
		"Well, shiver my shell! You washed up with half the sea's driftwood.",
		"Brock's crabs nicked my boat right off her mooring last night. The Barnacle Betty! Dragged her off up the beach, see?",
		"Follow those marks and bring my Betty home, and there's something in it for you.",
	])
	npc.waiting_lines = PackedStringArray([
		"Those drag marks lead north up the beach. Crabs can't have hauled her far... can they?",
		"If she's stuck somewhere high, a few parrot friends could lift her. Three should do it.",
	])
	npc.thanks_lines = PackedStringArray([
		"My Betty! Not a scratch on her! ...Well. New scratches.",
		"Here, my old fishing chart. Some pirate inked an X on the back, years ago. Never did own a shovel.",
	])
	npc.after_lines = PackedStringArray([
		"Betty and me, back on the water. Best fishing's at dawn, while the crabs are still snoring.",
		"Your own little boat at the dock floats too... mostly.",
	])
	npc.talked_flag = &"castaway_met_shellby"
	npc.quest_flag = &"castaway_betty_quest"
	npc.done_flag = &"castaway_betty_lift"
	npc.reward_flag = &"castaway_betty_reward"
	npc.reward_kind = "map"
	npc.reward_id = &"castaway_map_2"
	npc.reward_message = "Got Shellby's fishing chart!"
	npc.position = Vector3(-84.5, 1.35, 18.4)
	b.add(npc, gameplay, "OldShellby")
	var model := TurtleModel.new()
	model.rotation.y = Player.yaw_of(mooring.position - npc.position)
	b.add(model, npc, "TurtleModel")
	npc.model = model
	# Gull Rock: a sea cliff with a lower ledge on its landward side.
	plateau(terrain, "GullRock", [Vector2(-80, -34), Vector2(-81, -41), Vector2(-77, -46.5), Vector2(-70.5, -47),
		Vector2(-66.5, -43), Vector2(-66, -36.5), Vector2(-69.5, -32), Vector2(-75.5, -31)], 9.4, 11.0, "cliff", {"seed": 31})
	# Its east face is square where the ramp's top edge meets it (no lip).
	plateau(terrain, "GullLedge", [Vector2(-67.5, -44.5), Vector2(-61.2, -44), Vector2(-61, -41.6), Vector2(-61, -38.4),
		Vector2(-62, -35.5), Vector2(-67.5, -35)], 5.4, 6.0, "cliff", {"seed": 33})
	# The crabs' plank ramp up to the ledge, a crate they used as a step and
	# the planks that gave way under the boat on the last stretch.
	blk(structures, Vector3(-57.0, 1.2, -40.0), Vector3(2.6, 4.2, 8.0), "wood", Vector3(0, 90, 0), LevelBlock.Shape.RAMP, "CrabRamp")
	blk(structures, Vector3(-65.4, 5.4, -42.6), Vector3(1.4, 1.4, 1.4), "wood", Vector3(0, 14, 0), LevelBlock.Shape.BOX, "CrabCrate")
	blk(structures, Vector3(-63.3, 5.4, -37.6), Vector3(0.08, 4.4, 0.45), "wood_dark", Vector3(0, 0, 41), LevelBlock.Shape.BOX, "LeaningPlank")
	blk(structures, Vector3(-62.4, 5.4, -42.0), Vector3(0.45, 0.08, 1.9), "wood_dark", Vector3(0, 63, 0), LevelBlock.Shape.BOX, "FallenPlank")
	blk(structures, Vector3(-63.6, 5.4, -39.2), Vector3(0.45, 0.08, 1.4), "wood_dark", Vector3(0, -24, 0), LevelBlock.Shape.BOX, "SnappedPlank")
	# The Betty, wedged on top and flying Brock's flag, with her guards.
	var betty := FishingBoat.new()
	betty.flag_until = &"castaway_betty_lift"
	betty.position = Vector3(-74.0, 9.85, -39.5)
	betty.rotation_degrees = Vector3(0, 18, -7)
	b.add(betty, g, "BarnacleBetty")
	var task := ParrotTask.new()
	task.task_id = &"castaway_betty_lift"
	task.required_parrots = 3
	task.carried = betty
	task.destination = mooring
	task.lift_height = 9.0
	task.carry_time = 6.5
	task.position = Vector3(-70.2, 9.4, -38.2)
	b.add(task, g, "BettyTask")
	crab(Vector3(-76.5, 9.45, -43.5), CrabModel.Variant.NORMAL, "castaway_crab_gull_1")
	crab(Vector3(-71.5, 9.45, -34.5), CrabModel.Variant.HERMIT, "castaway_crab_gull_2")
	gem(Vector3(-79.0, 10.0, -40.0), "castaway_gem_gull", Color("5fe08a"))
	palm(g, Vector3(-77.5, 9.4, -35.0), 6.0, 16.0, 200.0, 97)
	rock(g, Vector3(-71.0, 9.4, -44.5), Vector3(1.4, 0.9, 1.2), StylizedRock.Preset.MOSSY, 89, 30.0)
	barrel_prop(g, Vector3(-69.0, 9.4, -42.0), "castaway_barrel_gull", 3)
	# The trail: from the empty mooring up the beach, the ramp and the ledge.
	var marks := DragMarks.new()
	marks.points = PackedVector3Array([Vector3(-82.5, 1.2, 14.5), Vector3(-80.5, 1.2, 6), Vector3(-78.5, 1.2, -4),
		Vector3(-76.5, 1.2, -12), Vector3(-73, 1.2, -18), Vector3(-68.5, 1.2, -25), Vector3(-64, 1.2, -32),
		Vector3(-58.5, 1.2, -37.5), Vector3(-53, 1.2, -40)])
	marks.seed = 3
	b.add(marks, g, "DragMarks")
	var ramp_marks := DragMarks.new()
	ramp_marks.points = PackedVector3Array([Vector3(-53, 1.2, -40), Vector3(-61, 5.4, -40), Vector3(-65.4, 5.4, -40.4)])
	ramp_marks.footprints = false
	ramp_marks.groove_color = Color("6e4a2c")
	ramp_marks.berm_color = Color("c9a46c")
	ramp_marks.seed = 5
	b.add(ramp_marks, g, "RampDragMarks")
	coin_trail(Vector3(-79.5, 1.6, 2), Vector3(-77.5, 1.6, -8), 4, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(-54.5, 2.2, -40), Vector3(-59.5, 4.9, -40), 4, 0.0, CoinTrail.TrailShape.LINE)
	# Shellby's chart leads to the north beach, by a cairn of stones.
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"castaway_x_north"
	x_spot.island_id = ISLAND
	x_spot.contents = "goblet"
	x_spot.gem_color = Palette.GEM_BLUE
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"castaway_map_2"
	x_spot.position = Vector3(-11.0, 1.2, -64.5)
	b.add(x_spot, g, "NorthBeachX")
	var cairn := b.group("Cairn", g)
	rock(cairn, Vector3(-9.2, 1.2, -63.4), Vector3(1.3, 0.8, 1.2), StylizedRock.Preset.SAND_ROCK, 71, 20.0)
	rock(cairn, Vector3(-9.2, 1.85, -63.4), Vector3(0.9, 0.6, 0.85), StylizedRock.Preset.SAND_ROCK, 73, 70.0)
	rock(cairn, Vector3(-9.2, 2.3, -63.4), Vector3(0.55, 0.45, 0.5), StylizedRock.Preset.SAND_ROCK, 79, 140.0)


## Two more islanders (spec §101): Tok, the outpost lookout, who points out
## cages still locked; and Pip, a young otter on Driftwood Key whose lucky
## clam the pelican stole.
func _islanders() -> void:
	blk(structures, Vector3(-50.5, 3.0, 25.5), Vector3(1.1, 0.9, 1.1), "wood", Vector3(0, 12, 0), LevelBlock.Shape.BOX, "TokCrate")
	var tok := LookoutNPC.new()
	tok.display_name = "Tok"
	tok.lines = PackedStringArray([
		"Ahoy down there! Tok's the name, lookout's the game.",
		"Nothing gets past this spyglass. Not crabs, not clouds, and definitely not caged parrots.",
	])
	tok.repeat_lines = PackedStringArray(["Tok's spyglass sees all!", "Hold still, I'm looking...",
		"Ooh, a cloud shaped like a banana. Anyway!"])
	tok.cage_hints = PackedStringArray([
		"castaway_parrot_outpost|Look up! The crabs locked a parrot on our own watchtower. Climb the crates by the blue hut.",
		"castaway_parrot_wreck|I hear squawking from your shipwreck's crow's nest. Up the stern deck and keep climbing!",
		"castaway_parrot_summit|There's a cage on the hill summit. Take the terraces, or kick your way up the chimney.",
		"castaway_parrot_stack|A cage sits on the sea stack off the wreck. Only a mighty long jump gets you there.",
		"driftwood_parrot_tower|Southwest, over the water: Driftwood Key! A cage tops a tower of lashed rafts.",
		"driftwood_parrot_pen|More on Driftwood Key: the crabs keep one in a pen up on the knoll. Guarded, mind you.",
	])
	tok.all_free_lines = PackedStringArray(["Not a single cage left! The sky's full of your friends."])
	tok.talked_flag = &"castaway_met_tok"
	tok.position = Vector3(-50.5, 3.9, 25.5)
	b.add(tok, gameplay, "Tok")
	var monkey := MonkeyModel.new()
	monkey.rotation.y = Player.yaw_of(Vector3(-44, 3.0, 33) - tok.position)
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


## The strait between the dock and Driftwood Key (spec §117: no long
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
	# Gull Bar: a sandbar with a palm, a crate of coins and a gem.
	var bar := Vector2(-96, 66)
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
	for d: Array in [["Lookout", Vector3(50, 7.5, -49.5), Vector3(0, 0, -1)], ["Hold", Vector3(50, 0, -74), Vector3(0, 0, 1)],
			["EnterFrom", Vector3(82, 0, -100), Vector3(-32, 0, 26)], ["ExitTo", Vector3(8, 0, -110), Vector3(-42, 0, -36)]]:
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


# --- Tutorial hints -----------------------------------------------------------------

func _hints() -> void:
	var g := b.group("Hints", gameplay)
	for d: Array in [
			["hint_jump", Vector3(0, 1.2, 29.5), Vector3(14, 4, 8), "{jump} Jump - hold it to jump higher", &""],
			["hint_dive", Vector3(18, 1.2, 35), Vector3(10, 4, 8), "While running, {dive} to dive  ·  {jump} to roll out", &""],
			["hint_swipe", Vector3(4, 3.0, 8), Vector3(14, 4, 10), "{attack} Hook swipe  ·  armored crabs need a ground pound", &""],
			["hint_ledge", Vector3(-4, 3.0, 7), Vector3(14, 4, 5), "Jump at a ledge to grab it  ·  {jump} to climb up", &""],
			["hint_wall_kick", Vector3(1.2, 7.0, -20.5), Vector3(5, 4, 4), "Slide down a wall and press {jump} to wall-kick", &""],
			["hint_long_jump", Vector3(55.5, 8.0, 38), Vector3(4, 3, 4), "Long jump: run, hold {crouch} and press {jump}", &""],
			["hint_ground_pound", Vector3(62, 7.5, -16), Vector3(14, 4, 14), "In the air, press {ground_pound} to ground pound", &""],
			["hint_ring", Vector3(-25, 4.5, 49), Vector3(7, 3, 7), "Jump at a golden ring and press {tool_primary} to swing", &""],
			["hint_boat", Vector3(-52, 1.35, 78), Vector3(6, 3, 10), "{interact} Board the boat  ·  steer with the stick, {jump} to hop out", &""],
			["hint_tools", Vector3(11, 7.0, -36), Vector3(8, 4, 6), "Swap hand attachments with {tool_previous} / {tool_next}", &"shovel"]]:
		var h := TutorialHint.new()
		h.hint_id = StringName(d[0])
		h.position = d[1]
		h.size = d[2]
		h.text = d[3]
		h.require_attachment = d[4]
		b.add(h, g, String(d[0]).capitalize().replace(" ", ""))


# --- Dressing (props kit) -----------------------------------------------------------

const COIN_SCENE := "res://collectibles/coin.tscn"
const HEART_SCENE := "res://collectibles/heart.tscn"


func palm(parent: Node, pos: Vector3, height: float, lean: float, lean_dir: float, seed: int) -> PalmTree:
	var t := PalmTree.new()
	t.height = height
	t.lean_degrees = lean
	t.lean_direction = lean_dir
	t.seed = seed
	t.coconut_count = seed % 4
	t.position = pos
	b.add(t, parent, "Palm")
	return t


func rock(parent: Node, pos: Vector3, size: Vector3, preset: StylizedRock.Preset, seed: int, yaw: float = 0.0) -> StylizedRock:
	var r := StylizedRock.new()
	r.preset = preset
	r.size = size
	r.seed = seed
	r.position = pos
	r.rotation_degrees.y = yaw
	b.add(r, parent, "Rock")
	return r


func crate_prop(parent: Node, pos: Vector3, id: String, coins: int = 3, yaw: float = 0.0) -> Crate:
	var c := Crate.new()
	c.persistent_id = StringName(id)
	c.contents = load(COIN_SCENE)
	c.contents_count = coins
	c.position = pos
	c.rotation_degrees.y = yaw
	b.add(c, parent, "Crate")
	return c


func barrel_prop(parent: Node, pos: Vector3, id: String, coins: int = 2, lying: bool = false) -> Barrel:
	var c := Barrel.new()
	c.persistent_id = StringName(id)
	c.contents = load(COIN_SCENE)
	c.contents_count = coins
	c.lying = lying
	c.position = pos
	b.add(c, parent, "Barrel")
	return c


func scatter(parent: Node, center: Vector3, area: Vector2, kind: PropScatter.Kind, density: float, surfaces: Array[StringName], seed: int, max_count: int = 3000) -> PropScatter:
	var sc := PropScatter.new()
	sc.kind = kind
	sc.area_size = area
	sc.density = density
	sc.surface_filter = surfaces
	sc.seed = seed
	sc.max_instances = max_count
	sc.ray_height = 30.0
	sc.ray_depth = 40.0
	sc.position = center
	b.add(sc, parent, "Scatter")
	return sc


func _decorate() -> void:
	var nature := b.group("Nature")
	var props := b.group("Props")
	# Palms: beach rings leaning seaward, a few on the meadow and heights.
	var k := 0
	for d: Array in [
			[Vector3(-10, 1.2, 38.5), 7.5, 18.0, 160.0], [Vector3(8, 1.2, 40.0), 6.5, 22.0, 200.0], [Vector3(17, 1.2, 38.5), 8.5, 14.0, 150.0],
			[Vector3(-19, 1.2, 39.0), 6.0, 20.0, 190.0], [Vector3(-73, 1.2, 9.0), 7.0, 18.0, 90.0], [Vector3(-70, 1.2, -20.0), 8.0, 12.0, 70.0],
			[Vector3(-55, 1.2, -46.5), 6.5, 20.0, 40.0], [Vector3(-74, 1.2, 24.0), 7.5, 16.0, 110.0], [Vector3(-63, 1.2, 40.0), 6.0, 24.0, 135.0],
			[Vector3(-24, 1.2, -60.0), 7.0, 18.0, 0.0], [Vector3(2, 1.2, -66.0), 8.5, 14.0, 10.0], [Vector3(30, 1.2, -62.0), 6.5, 20.0, -20.0],
			[Vector3(44, 1.2, -57.0), 7.0, 16.0, -40.0], [Vector3(80, 1.2, 12.0), 7.5, 20.0, -90.0], [Vector3(70, 1.2, 27.0), 6.0, 22.0, -130.0],
			[Vector3(-22, 3.0, 21.0), 8.0, 8.0, 30.0], [Vector3(14, 3.0, 14.0), 7.0, 10.0, -60.0], [Vector3(22, 3.0, -30.0), 7.5, 12.0, -90.0],
			[Vector3(-38, 7.0, -20.0), 6.5, 10.0, 120.0], [Vector3(6, 7.0, -6.0), 7.0, 8.0, 0.0], [Vector3(44, 7.5, -4.0), 8.0, 14.0, 60.0],
			[Vector3(66, 7.5, 4.0), 7.0, 18.0, -120.0], [Vector3(-22, 12.4, -40.0), 6.0, 10.0, 150.0]]:
		k += 1
		palm(nature, d[0], d[1], d[2], d[3], k * 7)
	# Rocks: cliff-foot clusters, beach boulders and a few in the shallows.
	var rk := 0
	for d: Array in [
			[Vector3(26, 1.2, 30), Vector3(2.4, 1.6, 2.0), StylizedRock.Preset.SAND_ROCK], [Vector3(27.5, 1.2, 28.2), Vector3(1.2, 0.8, 1.1), StylizedRock.Preset.SAND_ROCK],
			[Vector3(-38, 1.2, 36.5), Vector3(1.8, 1.2, 1.6), StylizedRock.Preset.CLIFF_ROCK], [Vector3(60, 1.2, 21), Vector3(2.6, 1.8, 2.2), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(-62, 1.2, -30), Vector3(2.2, 1.4, 2.0), StylizedRock.Preset.MOSSY], [Vector3(8, 1.2, -60), Vector3(1.6, 1.1, 1.4), StylizedRock.Preset.SAND_ROCK],
			[Vector3(32, 0.2, 50), Vector3(2.0, 1.6, 1.8), StylizedRock.Preset.DARK_ROCK], [Vector3(-78, 0.2, -30), Vector3(2.4, 1.8, 2.2), StylizedRock.Preset.DARK_ROCK],
			[Vector3(-30, 3.0, 4.5), Vector3(1.4, 1.0, 1.2), StylizedRock.Preset.MOSSY], [Vector3(-8, 3.0, 22.0), Vector3(1.0, 0.7, 0.9), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(-14, 7.0, -18.0), Vector3(1.6, 1.0, 1.4), StylizedRock.Preset.MOSSY], [Vector3(76, 7.5, -10), Vector3(1.8, 1.2, 1.6), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(18.5, 7.0, -29.6), Vector3(1.4, 1.2, 1.2), StylizedRock.Preset.DARK_ROCK], [Vector3(84, 1.2, 0), Vector3(2.2, 1.5, 2.0), StylizedRock.Preset.SAND_ROCK]]:
		rk += 1
		rock(nature, d[0], d[1], d[2], rk * 11, rk * 37.0)
	# Grass, flowers, bushes and ferns on every grassy top; pebbles on sand.
	var grass_only: Array[StringName] = [&"grass"]
	var sand_only: Array[StringName] = [&"sand"]
	scatter(nature, Vector3(2, 20, -5), Vector2(190, 160), PropScatter.Kind.GRASS, 0.42, grass_only, 3, 9000)
	scatter(nature, Vector3(2, 20, -5), Vector2(190, 160), PropScatter.Kind.FLOWERS, 0.035, grass_only, 5, 900)
	scatter(nature, Vector3(2, 20, -5), Vector2(190, 160), PropScatter.Kind.BUSHES, 0.004, grass_only, 7, 120)
	scatter(nature, Vector3(-10, 25, -35), Vector2(50, 30), PropScatter.Kind.FERNS, 0.05, grass_only, 9, 200)
	scatter(nature, Vector3(2, 20, -5), Vector2(190, 160), PropScatter.Kind.PEBBLES, 0.01, sand_only, 11, 600)
	# Outpost life: breakable crates and barrels (coins inside).
	crate_prop(props, Vector3(-50.5, 3.0, 9.5), "castaway_crate_outpost_1", 3, 12.0)
	crate_prop(props, Vector3(-51.6, 3.0, 10.8), "castaway_crate_outpost_2", 2, -20.0)
	barrel_prop(props, Vector3(-57.5, 3.0, 12.5), "castaway_barrel_outpost_1", 2)
	barrel_prop(props, Vector3(-44.0, 3.0, 22.5), "castaway_barrel_outpost_2", 3)
	barrel_prop(props, Vector3(-53.0, 1.35, 59.5), "castaway_barrel_dock", 2, true)
	crate_prop(props, Vector3(-50.8, 1.35, 66.0), "castaway_crate_dock", 3, 8.0)
	# Wreck beach: debris, a crate of coins, an anchor.
	for d: Array in [[Vector3(50, 1.2, 30), 4.0, 3], [Vector3(36, 1.2, 39), 3.0, 5], [Vector3(64, 1.2, 30), 3.5, 9]]:
		var deb := ShipDebris.new()
		deb.radius = d[1]
		deb.seed = d[2]
		deb.position = d[0]
		b.add(deb, props, "ShipDebris")
	crate_prop(props, Vector3(57.0, 1.2, 33.0), "castaway_crate_wreck", 4, 30.0)
	var anchor := Anchor.new()
	anchor.position = Vector3(57.5, 1.2, 43.0)
	anchor.rotation_degrees = Vector3(0, 40, 0)
	b.add(anchor, props, "Anchor")
	# Torches flank the dark cave's mouth (outside the darkness).
	for z: float in [-30.6, -38.4]:
		var torch := Torch.new()
		torch.position = Vector3(18.8, 7.0, z)
		b.add(torch, props, "CaveTorch")
	# A decorative cannon guards the outpost tower.
	var gun := DecorCannon.new()
	gun.position = Vector3(-38.4, 9.4, 2.9)
	gun.rotation_degrees.y = -90.0
	b.add(gun, props, "TowerCannon")


func _opening(player: Node3D) -> void:
	var seq := OpeningSequence.new()
	b.add(seq, null, "OpeningSequence")
	seq.player = player
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
