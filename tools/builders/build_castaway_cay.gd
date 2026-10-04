extends IslandBuilder
## Generates res://world/islands/castaway_cay/castaway_cay.tscn: the opening
## island (spec §72–77, §146–153; docs/ARCHIPELAGO.md), Patchy's Outset. He
## washes up after the storm on a big, inhabited pirate island: a village
## over its harbor, a meadow with a waterfall and a river, a mountain to
## climb, woods with a giant tree, an old fort across a gorge, beaches and
## caves all round, and something to find (or a way to climb) at every turn.
## Where everything is: CastawayLayout (world/islands/castaway_cay/).
##   tools/builders/build.sh castaway_cay world

const L := preload("res://world/islands/castaway_cay/castaway_layout.gd")
const ISLAND := &"castaway_cay"
const ISLET := &"driftwood_key"
const DINGHY := &"castaway_dinghy"
const SAND := L.SAND
const QUAY := L.QUAY
const LOW := L.LOW
const MID := L.MID
const TERRACE := L.TERRACE
const BLUFF := L.BLUFF
const HIGH := L.HIGH
const FORT := L.FORT
const DOWNS := L.DOWNS
const SHELF := L.SHELF
const UPPER := L.UPPER
const SUMMIT := L.SUMMIT


func build() -> void:
	# Deterministic builds: regenerating the island gives an identical scene.
	seed(20261004)
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
	_water()
	_wreck_shore()
	_south_cove()
	_meadow()
	_village()
	_tavern()
	_harbor()
	_shipyard()
	_bluff()
	_lookout()
	_woods()
	_giant_tree()
	_cave()
	_mountain()
	_gorge_and_fort()
	_east_downs()
	_north_beach()
	_barnacle_betty()
	_driftwood_key()
	_islanders()
	_villagers()
	_crossing()
	_brock_cameo()
	_sunken_reef()
	_beak_rock()
	_sea_regions()
	_checkpoints()
	_hints()
	_decorate()
	_opening()
	b.save("res://world/islands/castaway_cay/castaway_cay.tscn")


# --- Helpers ------------------------------------------------------------------------

## Stairs (or a ramp) from `from` (its foot, on the lower level) up to `to`
## (its head, on the upper level).
func steps(parent: Node, from: Vector3, to: Vector3, width: float, node_name: String, shape: LevelBlock.Shape = LevelBlock.Shape.STAIRS, surface := "wood") -> LevelBlock:
	var flat := Vector3(to.x - from.x, 0, to.z - from.z)
	var mid := Vector3((from.x + to.x) * 0.5, from.y, (from.z + to.z) * 0.5)
	var block := blk(parent, mid, Vector3(width, to.y - from.y, flat.length()), surface, Vector3(0, rad_to_deg(Player.yaw_of(flat)), 0), shape, node_name)
	block.step_count = clampi(roundi((to.y - from.y) / 0.32), 2, 60)
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


## A rounded, slightly lumpy outline: an ellipse of `rx` by `rz` round
## `center` (x, z), turned `turn` degrees.
func _blob(center: Vector2, rx: float, rz: float, blob_seed: int, turn := 0.0, n := 10, rough := 0.18) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = blob_seed
	var out: Array = []
	var t := deg_to_rad(turn)
	for k in n:
		var a := TAU * k / n
		var r := 1.0 + rng.randf_range(-rough, rough)
		var p := Vector2(cos(a) * rx * r, sin(a) * rz * r).rotated(t)
		out.append(center + p)
	return out


## A grassy hill on top of the ground at `base`: a flat top `h` m up with
## gentle sloping sides all round (walkable).
func _hill(parent: Node, node_name: String, center: Vector2, rx: float, rz: float, base: float, h: float, hill_seed: int, turn := 0.0, surface := "grass") -> Plateau:
	return plateau(parent, node_name, _blob(center, rx, rz, hill_seed, turn), base + h, h + 1.5, surface,
		{"shore": true, "shore_width": h * 3.2, "shore_drop": h, "seed": hill_seed})


## A packed-dirt path along `points` (x, z), `width` wide, laid on ground at
## `y` (a hair above it).
func _path(parent: Node, node_name: String, points: Array, width: float, y: float) -> void:
	var line := PackedVector2Array()
	for p: Vector2 in points:
		line.append(p)
	var polys := Geometry2D.offset_polyline(line, width * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND)
	var k := 0
	for poly: PackedVector2Array in polys:
		k += 1
		var p := plateau(parent, "%s%d" % [node_name, k], Array(poly), y + 0.03, 0.25, "dirt", {"seed": k, "bevel": 0.02, "smoothing": 0})
		p.side_noise = 0.0


# --- Terrain ------------------------------------------------------------------------

func _terrain() -> void:
	plateau(terrain, "Coast", L.COAST, SAND, 12.0, "sand", {"shore": true, "shore_width": 18.0, "shore_drop": 6.0, "seed": 1})
	plateau(terrain, "LowlandsWest", L.LOWLANDS_WEST, LOW, 6.0, "cliff_warm", {"seed": 3})
	plateau(terrain, "LowlandsEast", L.LOWLANDS_EAST, LOW, 6.0, "cliff_warm", {"seed": 4})
	plateau(terrain, "EastDowns", L.EAST_DOWNS, DOWNS, 10.0, "cliff_warm", {"seed": 6})
	plateau(terrain, "VillageMid", L.VILLAGE_MID, MID, 10.0, "cliff_warm", {"seed": 7})
	plateau(terrain, "VillageTop", L.VILLAGE_TOP, TERRACE, 14.0, "cliff_warm", {"seed": 8})
	plateau(terrain, "Bluff", L.BLUFF_TOP, BLUFF, 18.0, "cliff_warm", {"seed": 9})
	plateau(terrain, "Highlands", L.HIGHLANDS, HIGH, 20.0, "cliff_warm", {"seed": 10})
	plateau(terrain, "Shelf", L.SHELF_TOP, SHELF, 12.0, "cliff_warm", {"seed": 11})
	plateau(terrain, "UpperRocks", L.UPPER_TOP, UPPER, 12.0, "cliff_grey", {"seed": 12})
	plateau(terrain, "Summit", L.SUMMIT_TOP, SUMMIT, 12.0, "cliff_grey", {"seed": 13})
	plateau(terrain, "Headland", L.HEADLAND, FORT, 26.0, "cliff_grey", {"seed": 14, "no_wall_kick": true})
	# Sandy seabed 11 m down, so the water shades consistently and there's a
	# bottom to dive to (the ocean is the world's). Two slabs that reach
	# Driftwood Key without running under Pinwheel Isle's or Bell Atoll's.
	blk(terrain, Vector3(-10, -11, 111.5), Vector3(580, 1, 413), "sand", Vector3.ZERO, LevelBlock.Shape.BOX, "Seabed")
	blk(terrain, Vector3(0, -11, -187.5), Vector3(560, 1, 185), "sand", Vector3.ZERO, LevelBlock.Shape.BOX, "SeabedNorth")
	# Rolling hills on the meadow and the downs, so the low ground isn't flat.
	var hills := b.group("Hills", terrain)
	for d: Array in [[Vector2(-20, 14), 14.0, 10.0, 2.2, 31, 20.0], [Vector2(6, -14), 10.0, 8.0, 1.6, 33, -30.0],
			[Vector2(70, 18), 16.0, 11.0, 2.4, 35, 10.0], [Vector2(74, -16), 10.0, 8.0, 1.8, 37, 40.0],
			[Vector2(-48, 4), 9.0, 7.0, 1.4, 39, 0.0], [Vector2(150, 0), 13.0, 10.0, 2.0, 41, 20.0]]:
		var base: float = DOWNS if (d[0] as Vector2).x > 120.0 else LOW
		_hill(hills, "Hill", d[0], d[1], d[2], base, d[3], d[4], d[5])
	# Mount Patch's knolls on the highlands (stepping stones up to the shelf).
	_hill(hills, "HighKnoll", Vector2(-80, -92), 10.0, 8.0, HIGH, 2.0, 43, 20.0)
	_hill(hills, "HighKnoll", Vector2(-140, -76), 8.0, 5.5, HIGH, 1.6, 45, -10.0)


## The waterfall pool at the highlands' foot, and the river out of it
## through the meadow and across Wreck Shore to the sea (deep enough to swim
## in the pool, a wade in the river).
func _water() -> void:
	var g := b.group("River", terrain)
	var pool := WaterVolume.new()
	pool.round = true
	pool.show_surface = true
	pool.wave_height = 0.04
	pool.size = Vector3(L.POOL_R * 2.0 + 2.0, L.POOL_WATER - SAND + 0.4, L.POOL_R * 2.0 + 2.0)
	pool.position = Vector3(L.POOL.x, L.POOL_WATER, L.POOL.z)
	b.add(pool, g, "Pool")
	# The river: water boxes along its course, then a shallow sheet across
	# the sand to the sea.
	var k := 0
	for i in L.RIVER.size() - 1:
		var a: Vector2 = L.RIVER[i]
		var c: Vector2 = L.RIVER[i + 1]
		var w := WaterVolume.new()
		w.show_surface = true
		w.wave_height = 0.02
		w.size = Vector3(10.5, L.RIVER_WATER - SAND + 0.3, a.distance_to(c) + 2.0)
		w.position = Vector3((a.x + c.x) * 0.5, L.RIVER_WATER, (a.y + c.y) * 0.5)
		w.rotation.y = Player.yaw_of(Vector3(c.x - a.x, 0, c.y - a.y))
		k += 1
		b.add(w, g, "River%d" % k)


## A waterfall: a ribbon of streaming water from `top` straight down to
## `bottom_y`, `width` wide, facing `facing`, a little wider at its foot,
## with spray where it lands.
func _falls(parent: Node, node_name: String, top: Vector3, bottom_y: float, width: float, facing: Vector3) -> void:
	var g := b.group(node_name, parent)
	var mb := PropBuilder.new()
	var f := facing.normalized()
	var side := f.cross(Vector3.UP).normalized() * width * 0.5
	var steps_n := 8
	var prev_l := -1
	var prev_r := -1
	for k in steps_n + 1:
		var t := float(k) / steps_n
		var p := Vector3(top.x, lerpf(top.y, bottom_y, t), top.z) + f * (sin(t * PI * 0.5) * 0.9)
		var w := side * (1.0 + t * 0.4)
		var l := mb.vert(p - w, f, Color.WHITE, Vector2(0.0, t))
		var r := mb.vert(p + w, f, Color.WHITE, Vector2(1.0, t))
		if prev_l >= 0:
			mb.quad(prev_l, prev_r, r, l, f)
		prev_l = l
		prev_r = r
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, HorizonIsland._waterfall_material())
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add(mi, g, "Water")
	var mist := PropBuilder.new()
	var foot := Vector3(top.x, bottom_y, top.z) + f * 1.2
	for k in 5:
		var off := side.normalized() * (k - 2.0) * width * 0.28 + Vector3.UP * (0.2 + 0.5 * (k % 2))
		mist.ellipsoid(Vector3(width * 0.32, width * 0.2, width * 0.28), Transform3D(Basis.IDENTITY, foot + off), Color("f4fbff"), 3, 8)
	var mm := MeshInstance3D.new()
	mm.mesh = mist.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mm.transparency = 0.3
	b.add(mm, g, "Spray")


# --- Wreck Shore (south-east) -------------------------------------------------------

## Where Patchy washes up: a wide beach with his ship's stern beached on it
## (the captain's cabin; run up the deck to the crow's nest, parrot #1; long
## jump to the sea stack, parrot #4), the crabs' burrow under the meadow's
## edge and the river running out across the sand.
func _wreck_shore() -> void:
	var g := b.group("Shipwreck", structures)
	var o := L.WRECK
	blk(g, o + Vector3(44, SAND, 38), Vector3(5.0, 3.0, 10.0), "wood", Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "SternDeck")
	for side: float in [-1.0, 1.0]:
		blk(g, o + Vector3(44, SAND, 38 + side * 2.68), Vector3(0.35, 3.7, 10.0), "wood_dark", Vector3(0, -90, 0), LevelBlock.Shape.RAMP, "HullSide")
	blk(g, o + Vector3(51.25, SAND, 38), Vector3(4.5, 4.8, 5.7), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "Cabin")
	blk(g, o + Vector3(51.25, 6.0, 38), Vector3(4.9, 0.25, 6.1), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "CabinRoof")
	# The captain's cabin door: the hub where treasure, parrots and ship parts
	# are on display.
	var cabin_door := SceneDoor.new()
	cabin_door.target_scene = GameManager.get_island_scene(&"captains_cabin")
	cabin_door.spawn_id = &"door"
	cabin_door.label = "Captain's cabin"
	cabin_door.position = o + Vector3(51.25, SAND, 40.95)
	b.add(cabin_door, g, "CabinDoor")
	var door_spawn := Marker3D.new()
	door_spawn.position = o + Vector3(51.25, 1.3, 42.6)
	door_spawn.rotation_degrees.y = 180.0
	door_spawn.set_meta(&"spawn_id", &"cabin_door")
	b.add(door_spawn, gameplay, "SpawnCabinDoor")
	door_spawn.add_to_group(&"spawn_point", true)
	# Recovered ship parts go back on deck (spec §79).
	var resto := ShipRestoration.new()
	b.add(resto, g, "Restoration")
	var helm := Marker3D.new()
	helm.position = o + Vector3(51.6, 6.25, 35.8)
	helm.rotation_degrees.y = -90.0
	b.add(helm, resto, "Helm")
	var binnacle := Marker3D.new()
	binnacle.position = o + Vector3(52.8, 6.25, 35.8)
	b.add(binnacle, resto, "Binnacle")
	resto.helm = helm
	resto.binnacle = binnacle
	blk(g, o + Vector3(55.5, SAND, 38), Vector3(0.9, 8.6, 0.9), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Mast")
	blk(g, o + Vector3(55.5, 7.6, 38), Vector3(3.4, 0.45, 3.4), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "CrowsNest")
	cage(o + Vector3(55.5, 8.05, 39.2), "castaway_parrot_wreck", ParrotModel.Plumage.SCARLET)
	gem(o + Vector3(55.5, 10.6, 38), "castaway_gem_masthead", Palette.GEM_BLUE)
	var bow := BowPiece.new()
	bow.length = 5.0
	bow.height = 2.6
	bow.damage_seed = 4
	bow.position = o + Vector3(60.5, SAND, 36.5)
	bow.rotation_degrees.y = -100.0
	b.add(bow, g, "Bow")
	var hull := HullSection.new()
	hull.length = 9.5
	hull.height = 3.4
	hull.lean_degrees = 18.0
	hull.damage_seed = 7
	hull.position = o + Vector3(44.0, SAND, 34.4)
	hull.rotation_degrees.y = 180.0
	b.add(hull, g, "HullSection")
	for p: Vector3 in [Vector3(40.5, SAND, 32.5), Vector3(42, SAND, 31.6), Vector3(58.5, SAND, 41.5)]:
		blk(g, o + p, Vector3(1.2, 1.2, 1.2), "wood", Vector3(0, 25, 0), LevelBlock.Shape.BOX, "Crate")
	# Broken mast lying on the sand: a balance beam.
	blk(g, o + Vector3(36, SAND, 44.5), Vector3(0.9, 0.9, 12), "wood", Vector3(0, -60, 0), LevelBlock.Shape.CYLINDER, "FallenMast")
	crab(o + Vector3(46, 1.25, 31), CrabModel.Variant.HERMIT, "castaway_crab_wreck_1")
	crab(o + Vector3(58, 1.25, 33), CrabModel.Variant.NORMAL, "castaway_crab_wreck_2")
	crab(o + Vector3(38, 1.25, 26), CrabModel.Variant.CANNON, "castaway_crab_wreck_gunner")
	# A tall rock at the waterline, only reachable by a long jump from the
	# crow's nest (parrot #4).
	var stack: Array = []
	for p: Vector2 in [Vector2(59, 46), Vector2(62.5, 45.6), Vector2(64, 48.5), Vector2(62, 51.2), Vector2(58.8, 50.4)]:
		stack.append(p + Vector2(o.x, o.z))
	plateau(terrain, "WreckStack", stack, 6.2, 14.0, "rock", {"seed": 25, "no_wall_kick": true})
	cage(o + Vector3(61.4, 6.2, 48.6), "castaway_parrot_stack", ParrotModel.Plumage.SUNNY)
	coin_trail(o + Vector3(56.4, 8.6, 40.0), o + Vector3(60.2, 7.0, 46.2), 5, 1.6)
	coin_trail(o + Vector3(40.5, 1.9, 38), o + Vector3(47.5, 4.3, 38), 5, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(o + Vector3(48.4, 4.6, 38), o + Vector3(50.2, 6.6, 38), 3, 1.0)
	coin_trail(o + Vector3(31.5, 2.6, 47.1), o + Vector3(40.5, 2.6, 41.9), 5, 0.0, CoinTrail.TrailShape.LINE)
	var bird := Pelican.new()
	bird.persistent_id = &"castaway_pelican_wreck"
	bird.position = o + Vector3(46, SAND, 34)
	b.add(bird, enemies, "PelicanWreck")
	for d: Array in [[Vector3(50, SAND, 30), 4.0, 3], [Vector3(36, SAND, 39), 3.0, 5], [Vector3(64, SAND, 30), 3.5, 9], [Vector3(26, SAND, 40), 3.0, 13]]:
		var deb := ShipDebris.new()
		deb.radius = d[1]
		deb.seed = d[2]
		deb.position = o + d[0]
		b.add(deb, g, "ShipDebris")
	crate_prop(g, o + Vector3(57.0, SAND, 33.0), "castaway_crate_wreck", 4, 30.0)
	var anchor := Anchor.new()
	anchor.position = o + Vector3(57.5, SAND, 43.0)
	anchor.rotation_degrees = Vector3(0, 40, 0)
	b.add(anchor, g, "Anchor")
	# The thieves' burrow under the meadow's edge, and the way up beside it.
	var burrow := CrabBurrow.new()
	burrow.position = Vector3(78, SAND, 76)
	b.add(burrow, gameplay, "CoveBurrow")
	steps(terrain, Vector3(96, SAND - 0.05, 69.0), Vector3(96, LOW, 59.6), 6.0, "MeadowRamp", LevelBlock.Shape.RAMP, "grass")
	coin_trail(Vector3(84, 1.8, 92), Vector3(80, 1.8, 82), 5, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(96, SAND + 0.7, 70), Vector3(96, LOW + 0.7, 61), 4, 0.0, CoinTrail.TrailShape.LINE)
	var sign := Signpost.new()
	sign.texts = PackedStringArray(["Barnacle Bay", "Waterfall", "Old Fort"])
	sign.directions = PackedFloat32Array([90.0, 0.0, -30.0])
	sign.post_height = 2.6
	sign.position = Vector3(90, SAND, 84)
	b.add(sign, structures, "ShoreSign")
	# The river runs out across the sand to the sea: a wade.
	var stream := WaterVolume.new()
	stream.show_surface = true
	stream.wave_height = 0.01
	stream.size = Vector3(9.0, 0.6, 36.0)
	stream.position = Vector3(47.6, SAND + 0.22, 86)
	stream.rotation.y = Player.yaw_of(Vector3(0.12, 0, 1))
	b.add(stream, terrain, "RiverMouth")
	for d: Array in [[Vector3(43, SAND, 80), Vector3(1.3, 0.7, 1.2)], [Vector3(47.5, SAND, 84), Vector3(1.1, 0.6, 1.0)], [Vector3(51.5, SAND, 88), Vector3(1.2, 0.7, 1.1)]]:
		rock(structures, d[0], d[1], StylizedRock.Preset.DARK_ROCK, int(d[0].x * 3), d[0].z * 7.0)


# --- The south cove -----------------------------------------------------------------

## Between the river's mouth and the harbor's spit: the horn of rock, the
## ring run out to the gem pillar at the waterline, and the cove's palms.
func _south_cove() -> void:
	var g := b.group("RingRun", gameplay)
	var o := Vector3(8, 0, 30)
	var horn: Array = []
	for p: Vector2 in [Vector2(-12, 46), Vector2(-6, 44), Vector2(-2, 49), Vector2(-6, 54), Vector2(-12, 52)]:
		horn.append(p + Vector2(o.x, o.z))
	plateau(terrain, "Horn", horn, 4.5, 8.0, "rock", {"seed": 21})
	var pillar: Array = []
	for p: Vector2 in [Vector2(14, 62), Vector2(19, 61), Vector2(21, 65), Vector2(17, 68), Vector2(13, 66)]:
		pillar.append(p + Vector2(o.x, o.z))
	plateau(terrain, "GemPillar", pillar, 4.0, 12.0, "rock", {"seed": 23})
	for p: Vector3 in [Vector3(1.5, 8.4, 53.5), Vector3(9.5, 8.6, 58.5)]:
		var hp := HookPoint.new()
		hp.position = o + p
		hp.hang_length = 1.6
		b.add(hp, g, "HookRing")
	gem(o + Vector3(17, 5.2, 64.5), "castaway_gem_pillar", Palette.GEM_RED)
	coin_trail(o + Vector3(-3, 5.5, 51), o + Vector3(0.5, 6.5, 53.2), 3, 0.8)
	# A sloping rock to scramble up onto the horn.
	steps(terrain, o + Vector3(-19.0, SAND - 0.05, 49), o + Vector3(-12.55, 4.5, 49), 3.0, "HornRamp", LevelBlock.Shape.RAMP, "rock")


# --- The meadow ---------------------------------------------------------------------

## The waterfall off the highlands' south lip into the pool, the alcove
## behind it (walk in along the ledge at the cliff's foot), the basalt
## columns climbing up beside it to the highlands, the river's footbridge,
## and the meadow's critters.
func _meadow() -> void:
	var g := b.group("Waterfall", structures)
	var p := L.POOL
	# The lip the water pours off, roofing the alcove behind the falls.
	blk(g, Vector3(p.x, HIGH - 2.6, -35.2), Vector3(14.5, 2.6, 9.4), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "FallsLip")
	_falls(g, "Falls", Vector3(p.x, HIGH, -30.4), L.POOL_WATER, 7.5, Vector3.BACK)
	# The alcove: a dry floor behind the water, the ledge in along the
	# cliff's foot from the pool's west bank, and what's hidden there.
	blk(g, Vector3(p.x, SAND, -35.6), Vector3(11.6, LOW - SAND, 6.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "AlcoveFloor")
	blk(g, Vector3(17.2, SAND, -32.6), Vector3(6.0, LOW - SAND, 2.6), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "AlcoveLedge")
	var chest := TreasureChest.new()
	chest.chest_id = &"castaway_falls_chest"
	chest.island_id = ISLAND
	chest.contents = "goblet"
	chest.coins = 8
	chest.position = Vector3(p.x + 1.5, LOW, -37.2)
	b.add(chest, gameplay, "FallsChest")
	gem(Vector3(p.x - 3.5, LOW + 0.6, -37.0), "castaway_gem_falls", Color("5fd3ff"))
	# Basalt columns up the cliff west of the falls, each a jump (or a
	# ledge grab) above the last: the climber's way up to the highlands.
	var k := 0
	for d: Array in [[Vector3(11.5, LOW, -30.0), 5.6], [Vector3(8.0, LOW, -31.5), 7.6], [Vector3(4.6, LOW, -30.4), 9.6],
			[Vector3(1.2, LOW, -31.6), 11.6], [Vector3(-2.4, LOW, -31.0), 13.6], [Vector3(-6.0, LOW, -32.4), 15.6],
			[Vector3(-9.4, LOW, -32.6), 17.6]]:
		k += 1
		var col := blk(g, Vector3(d[0].x, SAND, d[0].z), Vector3(2.8, float(d[1]) - SAND, 2.6), "stone", Vector3(0, k * 23.0, 0), LevelBlock.Shape.CYLINDER, "Basalt%d" % k)
		col.bevel = 0.06
		if k % 2 == 1:
			coin_trail(Vector3(d[0].x, float(d[1]) + 0.8, d[0].z), Vector3(d[0].x, float(d[1]) + 0.8, d[0].z), 1, 0.0, CoinTrail.TrailShape.LINE)
	# The footbridge over the river, and stepping stones higher up.
	var bridge := b.group("Footbridge", structures)
	blk(bridge, Vector3(36.4, LOW - 0.32, 25), Vector3(15.0, 0.42, 3.0), "wood", Vector3(0, -17, 0), LevelBlock.Shape.BOX, "Deck")
	for s: float in [-1.0, 1.0]:
		var rail := FenceSegment.new()
		rail.style = FenceSegment.Style.RAIL
		rail.position = Vector3(36.4, LOW + 0.1, 25) + Vector3(-1, 0, 0).rotated(Vector3.UP, deg_to_rad(-17)).cross(Vector3.UP) * 1.35 * s
		rail.rotation_degrees.y = -17.0
		b.add(rail, bridge, "Rail")
	for d: Array in [[Vector3(30, SAND, 4), 1.7], [Vector3(32.5, SAND, 7.5), 1.8], [Vector3(35, SAND, 5.0), 1.7]]:
		blk(structures, d[0], Vector3(1.8, float(d[1]), 1.8), "stone", Vector3(0, d[0].x * 17.0, 0), LevelBlock.Shape.CYLINDER, "SteppingStone")
	# Critters: an armored crab in a ring of coins (pound it), a couple of
	# meadow crabs, a TNT snail by the downs.
	coin_trail(Vector3(-2, LOW + 0.6, 34), Vector3.ZERO, 8, 0.0, CoinTrail.TrailShape.RING)
	crab(Vector3(-2, LOW + 0.05, 34), CrabModel.Variant.ARMORED, "castaway_crab_meadow_armored")
	crab(Vector3(66, LOW + 0.05, 40), CrabModel.Variant.NORMAL, "castaway_crab_meadow")
	crab(Vector3(90, LOW + 0.05, 4), CrabModel.Variant.NORMAL, "castaway_crab_meadow_2")
	heart(Vector3(70, LOW + 2.4 + 0.6, 18))
	gem(Vector3(-20, LOW + 2.2 + 0.7, 14), "castaway_gem_hilltop", Color("ffd34d"))
	coin_trail(Vector3(10, LOW + 0.6, 44), Vector3(28, LOW + 0.6, 30), 6, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(46, LOW + 0.6, 22), Vector3(52, LOW + 0.6, -4), 6, 0.0, CoinTrail.TrailShape.LINE)


# --- Barnacle Bay -------------------------------------------------------------------

## The village climbing the hill over the harbor: the plaza (the well, the
## market, the Soggy Biscuit), houses backed against each terrace's wall
## (their roofs are the climber's shortcut to the next), stairs between,
## the bell tower on the top terrace, laundry, bunting and lanterns.
func _village() -> void:
	var g := b.group("Village", structures)
	# The plaza's houses, backs to the middle terrace's wall.
	_house(g, "HouseBlue", Vector3(-146, LOW, 27.8), 180.0, {"size": Vector2(6, 5), "wall_color": Color("5fa8d3"), "roof_color": Color("d9483b"), "chimney": true, "seed": 11})
	_house(g, "HouseYellow", Vector3(-134, LOW, 28.6), 180.0, {"size": Vector2(6, 5), "wall_color": Color("f2c14e"), "roof_color": Color("3f8fd8"), "accent_color": Color("d9483b"), "seed": 12})
	_house(g, "HouseWhite", Vector3(-91, LOW, 25.6), 180.0, {"size": Vector2(5, 6), "walls": VillageHouse.Walls.PLASTER, "wall_color": Color("f3ead8"),
		"trim_color": Color("8a5a36"), "roof_color": Color("2f9e6e"), "gable_front": true, "chimney": true, "seed": 13})
	# The middle terrace's houses, backs to the top terrace's wall.
	_house(g, "HouseLoft", Vector3(-150, MID, -7.0), 180.0, {"size": Vector2(7, 5), "wall_color": Color("e8833a"), "roof_color": Color("8a5a36"),
		"accent_color": Color("2f7d5b"), "chimney": true, "seed": 14})
	_house(g, "HouseStone", Vector3(-132, MID, -7.0), 180.0, {"size": Vector2(7, 5.5), "walls": VillageHouse.Walls.STONE, "wall_color": Color("f6e7c8"),
		"roof_color": Color("d9483b"), "trim_color": Color("6e4128"), "seed": 15})
	_house(g, "HouseGreen", Vector3(-113, MID, -7.6), 180.0, {"size": Vector2(6, 5), "wall_color": Color("7fc28a"), "roof_color": Color("f2b134"),
		"accent_color": Color("3f8fd8"), "seed": 16})
	_house(g, "HousePink", Vector3(-95, MID, -8.6), 180.0, {"size": Vector2(6, 5), "wall_color": Color("f29bb5"), "roof_color": Color("3f8fd8"),
		"accent_color": Color("f2c14e"), "chimney": true, "seed": 17})
	# The top terrace's houses, backs to the bluff.
	_house(g, "HouseTop", Vector3(-118, TERRACE, -33.0), 180.0, {"size": Vector2(7, 5), "walls": VillageHouse.Walls.PLASTER, "wall_color": Color("eaf2f6"),
		"roof_color": Color("2f72b3"), "trim_color": Color("6e4128"), "chimney": true, "seed": 18})
	_house(g, "HouseCliff", Vector3(-156, TERRACE, -16.0), 90.0, {"size": Vector2(6, 5), "wall_color": Color("c9a3e6"), "roof_color": Color("d9483b"),
		"accent_color": Color("2f7d5b"), "seed": 19})
	# Stairs: plaza up to the middle terrace (stairs, and a grassy ramp in
	# the west), middle up to the top, top up to the bluff, plaza down to
	# the quay and down to the shipyard.
	steps(g, Vector3(-120, LOW, 34.0), Vector3(-120, MID, 25.4), 3.6, "StairsMid", LevelBlock.Shape.STAIRS, "stone")
	steps(terrain, Vector3(-157, LOW - 0.05, 37.6), Vector3(-157, MID, 24.4), 4.0, "RampMid", LevelBlock.Shape.RAMP, "grass")
	steps(g, Vector3(-104, MID, 2.6), Vector3(-104, TERRACE, -9.9), 3.2, "StairsTop", LevelBlock.Shape.STAIRS, "stone")
	steps(g, Vector3(-94, TERRACE, -23.4), Vector3(-94, BLUFF, -35.5), 3.0, "StairsBluff", LevelBlock.Shape.STAIRS, "stone")
	steps(g, Vector3(-112, QUAY, 59.6), Vector3(-112, LOW, 53.6), 4.0, "StairsQuay", LevelBlock.Shape.STAIRS, "stone")
	steps(g, Vector3(-82, QUAY, 59.6), Vector3(-82, LOW, 55.1), 3.0, "StairsQuayEast", LevelBlock.Shape.STAIRS, "stone")
	steps(g, Vector3(-50, SAND, 59.6), Vector3(-50, LOW, 48.9), 3.0, "StairsYard", LevelBlock.Shape.STAIRS, "wood")
	# The plaza: the well, the market stalls, a signpost.
	var well := VillageWell.new()
	well.position = Vector3(-112, LOW, 41)
	b.add(well, g, "Well")
	var k := 0
	for d: Array in [[Vector3(-128, LOW, 48.5), MarketStall.Goods.FISH, Color("3fa7ef")], [Vector3(-121, LOW, 49.5), MarketStall.Goods.FRUIT, Color("e8483c")],
			[Vector3(-98, LOW, 48.5), MarketStall.Goods.POTS, Color("5fcf5f")]]:
		k += 1
		var st := MarketStall.new()
		st.goods = d[1]
		st.canvas = d[2]
		st.seed = k
		st.position = d[0]
		b.add(st, g, "Stall")
	var sign := Signpost.new()
	sign.texts = PackedStringArray(["Barnacle Bay", "Lookout", "Shipyard", "Pier", "Waterfall"])
	sign.directions = PackedFloat32Array([0.0, 60.0, 120.0, 180.0, 270.0])
	sign.post_height = 2.8
	sign.position = Vector3(-104, LOW, 44)
	b.add(sign, g, "PlazaSign")
	for d: Array in [[StringLine.Kind.BUNTING, Vector3(-142, LOW + 4.6, 36), Vector3(-98, LOW + 4.6, 33), 0.0, 1.0],
			[StringLine.Kind.BUNTING, Vector3(-126, LOW + 4.4, 44), Vector3(-104, LOW + 4.4, 46), 0.0, 0.8],
			[StringLine.Kind.LAUNDRY, Vector3(-145.6, MID + 2.6, -6.5), Vector3(-136.4, MID + 2.6, -6.5), 0.0, 0.5],
			[StringLine.Kind.LAUNDRY, Vector3(-127.6, MID + 2.6, -6.5), Vector3(-116.4, MID + 2.6, -7.0), 0.0, 0.5],
			[StringLine.Kind.LANTERNS, Vector3(-134, QUAY + 3.6, 57.6), Vector3(-68, QUAY + 3.6, 57.6), 3.6, 0.9]]:
		k += 1
		var line := StringLine.new()
		line.kind = d[0]
		line.start_point = d[1]
		line.end_point = d[2]
		line.posts = d[3]
		line.sag = d[4]
		line.seed = k
		b.add(line, g, "Line")
	for d: Array in [[Vector3(-142, MID, 23.4), 0.0], [Vector3(-110, MID, 23.0), 0.0], [Vector3(-130, TERRACE, -11.0), 0.0],
			[Vector3(-90, LOW, 52.0), 0.0], [Vector3(-136, LOW, 52.6), 0.0]]:
		var fence := FenceSegment.new()
		fence.style = FenceSegment.Style.RAIL
		fence.position = d[0]
		fence.rotation_degrees.y = d[1]
		b.add(fence, g, "Fence")
	crate_prop(g, Vector3(-138, LOW, 33.6), "castaway_crate_village_1", 3, 12.0)
	barrel_prop(g, Vector3(-96, LOW, 31.0), "castaway_barrel_village_1", 2)
	barrel_prop(g, Vector3(-158, MID, -2.0), "castaway_barrel_village_2", 3)
	crate_prop(g, Vector3(-124, MID, -2.4), "castaway_crate_village_2", 2, -20.0)
	heart(Vector3(-118, LOW + 0.6, 38))
	# Up the roofs: coins along the ridges, a gem on the loft's chimney.
	gem(Vector3(-146, LOW + 5.6, 27.8), "castaway_gem_roof", Palette.GEM_RED)
	coin_trail(Vector3(-128, LOW + 3.1, 48.0), Vector3(-121, LOW + 3.1, 49.0), 3, 0.6)
	coin_trail(Vector3(-152.0, MID + 6.1, -7.0), Vector3(-148.0, MID + 6.1, -7.0), 3, 0.0, CoinTrail.TrailShape.LINE)
	gem(Vector3(-147.6, MID + 7.3, -6.0), "castaway_gem_chimney", Color("ff9f43"))
	_bell_tower()


## The bell tower on the top terrace: a stone tower with ledges stepping
## round it to the belfry. Hit the bell (any hit rings it) and a gem waits
## on the roof's peak.
func _bell_tower() -> void:
	var g := b.group("BellTower", structures)
	var c := Vector3(-142, TERRACE, -28)
	blk(g, c, Vector3(4.6, 9.0, 4.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "Tower")
	for d: Vector3 in [Vector3(2.0, 0, 2.0), Vector3(-2.0, 0, 2.0), Vector3(2.0, 0, -2.0), Vector3(-2.0, 0, -2.0)]:
		blk(g, c + d + Vector3(0, 9.0, 0), Vector3(0.6, 3.0, 0.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "BelfryPost")
	blk(g, c + Vector3(0, 12.0, 0), Vector3(5.6, 0.5, 5.6), "roof_red", Vector3.ZERO, LevelBlock.Shape.BOX, "BelfryRoof")
	blk(g, c + Vector3(0, 12.5, 0), Vector3(2.6, 1.2, 2.6), "roof_red", Vector3.ZERO, LevelBlock.Shape.BOX, "BelfryCap")
	var bell := Bell.new()
	bell.size = 1.2
	bell.position = c + Vector3(0, 9.0, 0)
	b.add(bell, g, "Bell")
	# Ledges round the outside, each a jump above the last.
	for k in 4:
		var a := deg_to_rad(-90.0 + 90.0 * k)
		var out := Vector3(cos(a), 0, sin(a))
		blk(g, c + out * 3.1 + Vector3(0, 1.0 + 2.0 * k, 0), Vector3(2.0, 0.5, 2.0), "stone", Vector3(0, rad_to_deg(a), 0), LevelBlock.Shape.BOX, "Ledge%d" % (k + 1))
	gem(c + Vector3(0, 14.3, 0), "castaway_gem_belfry", Color("9b5cff"))


## The Soggy Biscuit: a walk-in tavern at the plaza's east end. Auntie Ink
## keeps the bar; there are stools, barrels and a lantern or two.
func _tavern() -> void:
	var g := b.group("Tavern", structures)
	var at := Vector3(-76, LOW, 40)
	_house(g, "SoggyBiscuit", at, 90.0, {"size": Vector2(10, 7), "walls": VillageHouse.Walls.STONE, "wall_color": Color("f6e7c8"),
		"roof_color": Color("2f9e6e"), "trim_color": Color("6e4128"), "accent_color": Color("d9483b"), "porch": 2.6, "interior": true,
		"door_offset": -1.5, "sign_text": "The Soggy Biscuit", "wall_height": 3.6, "roof_pitch": 2.2, "chimney": true, "seed": 21})
	# Inside: the bar along the back, stools, tables, barrels.
	blk(g, at + Vector3(1.2, 0, -1.0), Vector3(0.7, 0.95, 5.6), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "Bar")
	blk(g, at + Vector3(1.2, 0.95, -1.0), Vector3(0.9, 0.1, 5.8), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "BarTop")
	blk(g, at + Vector3(3.0, 1.6, -1.0), Vector3(0.4, 0.08, 5.0), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "BackShelf")
	for z: float in [-3.0, -1.0, 1.0]:
		blk(g, at + Vector3(0.1, 0, z), Vector3(0.5, 0.7, 0.5), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Stool")
	for p: Vector3 in [Vector3(-1.9, 0, -3.2), Vector3(-0.9, 0, 4.0)]:
		blk(g, at + p, Vector3(1.3, 0.85, 1.3), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Table")
	barrel_prop(g, at + Vector3(2.3, 0, 3.6), "castaway_barrel_tavern_1", 2)
	barrel_prop(g, at + Vector3(2.3, 0, 4.4), "castaway_barrel_tavern_2", 3, true)
	var lamp := Torch.new()
	lamp.position = at + Vector3(-2.5, 0, 4.3)
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
		"They say there's something behind the waterfall. They also say my biscuits are crunchy. People say things."])
	ink.talked_flag = &"castaway_met_ink"
	ink.position = at + Vector3(2.3, 0, -1.0)
	b.add(ink, gameplay, "AuntieInk")
	var model := OctopusModel.new()
	model.rotation.y = Player.yaw_of(Vector3.LEFT)
	model.scale = Vector3.ONE * 1.35
	b.add(model, ink, "OctopusModel")
	ink.model = model
	# The old stump out the back (the cave map's X is under it).
	blk(structures, Vector3(-68.6, LOW, 44.4), Vector3(1.3, 0.9, 1.3), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "OldStump")
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"castaway_x_spot"
	x_spot.island_id = ISLAND
	x_spot.contents = "relic"
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"castaway_map_1"
	x_spot.position = Vector3(-67.0, LOW, 46.6)
	b.add(x_spot, gameplay, "TreasureMapX")


## The harbor: the quay along the bay's north shore, the pier out into the
## bay, the boat's mooring at its end, and lanterns.
func _harbor() -> void:
	var g := b.group("Harbor", structures)
	var quay := Dock.new()
	quay.length = 70.0
	quay.width = 4.0
	quay.post_depth = 4.0
	quay.water_line = -1.4
	quay.rope_rails = false
	quay.bollards = false
	quay.position = Vector3(-66, QUAY, 60.0)
	quay.rotation_degrees.y = 90.0
	b.add(quay, g, "Quay")
	var pier := Dock.new()
	pier.length = 27.0
	pier.width = 3.2
	pier.post_depth = 9.0
	pier.water_line = -1.4
	pier.position = Vector3(-100, QUAY, 62.0)
	pier.rotation_degrees.y = 180.0
	b.add(pier, g, "Pier")
	for z: float in [70.0, 80.0]:
		var lamp := LanternPost.new()
		lamp.position = Vector3(-101.9, QUAY, z)
		lamp.rotation_degrees.y = 90.0
		b.add(lamp, g, "PierLamp")
	var mooring := Marker3D.new()
	mooring.position = L.MOORING
	mooring.rotation.y = PI
	b.add(mooring, g, "BoatMooring")
	var arrival := Marker3D.new()
	arrival.position = Vector3(-100, QUAY + 0.1, 85)
	b.add(arrival, gameplay, "PierArrival")
	coin_trail(Vector3(-100, QUAY + 0.6, 66), Vector3(-100, QUAY + 0.6, 78), 6, 0.0, CoinTrail.TrailShape.LINE)
	var goblet := gem(Vector3(-101.2, QUAY + 0.9, 88.4), "castaway_goblet_dock", Palette.GOLD, "goblet")
	goblet.gem_color = Palette.GEM_RED
	for x: float in [-126.0, -74.0]:
		var nets := NetRack.new()
		nets.position = Vector3(x, QUAY, 60.2)
		nets.seed = int(x)
		b.add(nets, g, "NetRack")
	barrel_prop(g, Vector3(-106.0, QUAY, 59.8), "castaway_barrel_dock", 2, true)
	crate_prop(g, Vector3(-90.0, QUAY, 59.6), "castaway_crate_dock", 3, 8.0)


## Gus's shipyard on the bay's east spit: his workshop, the old dinghy up
## on trestles, a slipway down into the bay, timber. The dinghy's tiller
## lies on the bottom off the pier.
func _shipyard() -> void:
	var g := b.group("Shipyard", structures)
	_house(g, "Workshop", Vector3(-44, SAND, 76), 90.0, {"size": Vector2(6, 4), "wall_color": Color("b58456"), "roof_color": Color("6e7f8f"),
		"trim_color": Color("6e4128"), "accent_color": Color("d9483b"), "sign_text": "Shipwright", "wall_height": 3.0, "seed": 31})
	var dinghy := DinghyRepair.new()
	dinghy.fixed_flag = DINGHY
	dinghy.position = Vector3(-53.0, SAND, 90.0)
	dinghy.rotation_degrees.y = 90.0
	b.add(dinghy, gameplay, "DinghyRepair")
	steps(g, Vector3(-73, -1.6, 90.0), Vector3(-60.5, SAND, 90.0), 3.4, "Slipway", LevelBlock.Shape.RAMP, "wood")
	for d: Array in [[Vector3(-44.6, SAND, 87.0), Vector3(3.4, 0.5, 1.2), 10.0], [Vector3(-44.4, SAND + 0.5, 87.2), Vector3(3.2, 0.5, 1.0), 4.0],
			[Vector3(-42.5, SAND, 92.5), Vector3(1.2, 0.6, 3.0), -15.0]]:
		blk(g, d[0], d[1], "wood", Vector3(0, d[2], 0), LevelBlock.Shape.BOX, "Timber")
	barrel_prop(g, Vector3(-48.0, SAND, 99.0), "castaway_barrel_yard", 2)
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
		"The sail's up Tok's lookout tower on the bluff, above the village. Climb round the outside.",
		"The tiller sank off the end of the pier. Dive down and have a look.",
	])
	gus.fixing_lines = PackedStringArray([
		"The sail AND the tiller! You're handier than you look.",
		"Stand back. This'll take a minute of hammering...",
	])
	gus.launch_lines = PackedStringArray([
		"There! She's yours. Treat her kindly and she'll take you to any island you can see.",
		"Mind, it's a long swim if you sink her. The open sea's no place for paddling.",
		"Come back with a bit of gold and I'll fit her out proper: a quicker sail, a tougher hull, even a cannon.",
	])
	gus.after_lines = PackedStringArray([
		"Back again? Let's see what she needs. Faster, tougher, louder... or just prettier.",
	])
	gus.position = Vector3(-55.5, SAND, 86.0)
	b.add(gus, gameplay, "Gus")
	var walrus := WalrusModel.new()
	walrus.rotation.y = Player.yaw_of(Vector3(0.3, 0, 1))
	b.add(walrus, gus, "WalrusModel")
	gus.model = walrus
	var tiller := QuestItemPickup.new()
	tiller.item_id = &"dinghy_tiller"
	tiller.gone_after = DINGHY
	tiller.position = Vector3(-108.0, -3.3, 79.0)
	b.add(tiller, gameplay, "TillerPickup")


## The bluff above the village: the rope bridge across the ravine into the
## woods, an old cannon looking out over the bay.
func _bluff() -> void:
	var g := b.group("Bluff", structures)
	var bridge := RopeBridge.new()
	bridge.start_point = Vector3.ZERO
	# Its far end rests a hair above the woods' edge so the sag still
	# meets the ground there.
	bridge.end_point = Vector3(0, HIGH - BLUFF + 0.2, -10.9)
	bridge.width = 1.8
	bridge.sag = 0.6
	bridge.rail_collision = true
	bridge.position = Vector3(-90, BLUFF, -55.2)
	b.add(bridge, g, "RopeBridge")
	crab(Vector3(-118, BLUFF + 0.05, -50), CrabModel.Variant.NORMAL, "castaway_crab_bluff")
	coin_trail(Vector3(-90, BLUFF + 1.1, -56.5), Vector3(-90, HIGH + 0.6, -64.5), 6, 0.0, CoinTrail.TrailShape.LINE)
	var gun := DecorCannon.new()
	gun.position = Vector3(-124, BLUFF, -44)
	gun.rotation_degrees.y = 120.0
	b.add(gun, g, "BluffCannon")


## Tok's lookout tower: a stone column on the bluff with plank landings
## spiralling round it up to a deck under a little roof, the best view on
## the island. Parrot #2 is caged up there and Tok keeps watch beside the
## dinghy's sail, borrowed for a sunshade.
func _lookout() -> void:
	var g := b.group("Lookout", structures)
	var c := L.TOWER
	var deck := c.y + 14.1
	blk(g, c, Vector3(4.2, 13.6, 4.2), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "TowerCore")
	blk(g, c + Vector3(0, 13.6, 0), Vector3(7.4, 0.5, 7.4), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TowerDeck")
	for k in 12:
		var a := TAU * k / 12.0
		if k == 4 or k == 5:
			continue
		blk(g, Vector3(c.x + cos(a) * 3.5, deck, c.z + sin(a) * 3.5), Vector3(0.22, 1.0, 0.22), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "RailPost")
	for d: Vector3 in [Vector3(3.3, 0, 0), Vector3(-3.3, 0, 0), Vector3(0, 0, 3.3), Vector3(0, 0, -3.3)]:
		blk(g, Vector3(c.x, deck, c.z) + d, Vector3(0.3, 3.0, 0.3), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "RoofPost")
	blk(g, Vector3(c.x, deck + 3.0, c.z), Vector3(8.8, 0.35, 8.8), "roof_red", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TowerRoof")
	blk(g, Vector3(c.x, deck + 3.35, c.z), Vector3(0.18, 3.0, 0.18), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "FlagPole")
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


# --- The Whispering Woods (north-west highlands) -----------------------------------

## Old broadleaf trees and palms thick over the highlands, paths from the
## rope bridge to the giant tree and the cave, an abandoned camp, a hidden
## glade, and the stair down the cliff to the north beach.
func _woods() -> void:
	var nature := b.group("Woods")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var woods: PackedVector2Array = Geometry2D.offset_polygon(PackedVector2Array(L.HIGHLANDS), -6.0)[0]
	var keep_clear: Array = [[Vector2(L.GIANT_TREE.x, L.GIANT_TREE.z), 15.0], [Vector2(-160, -92), 14.0], [Vector2(-104, -108), 9.0],
		[Vector2(-62, -120), 6.0], [Vector2(-80, -92), 12.0], [Vector2(-140, -76), 9.0], [Vector2(-160, -87), 9.0], [Vector2(-60, -112), 6.0]]
	var placed: Array[Vector2] = []
	var k := 0
	for i in 1400:
		if placed.size() >= 110:
			break
		var p := Vector2(rng.randf_range(-184, -44), rng.randf_range(-120, -62))
		if not Geometry2D.is_point_in_polygon(p, woods):
			continue
		# Not on the mountain's shelf, the paths or the clearings.
		if Geometry2D.is_point_in_polygon(p, PackedVector2Array(L.SHELF_TOP)) or p.x > -46:
			continue
		if keep_clear.any(func(c: Array) -> bool: return p.distance_to(c[0]) < float(c[1])):
			continue
		if _near_path(p, [Vector2(-90, -66), Vector2(-104, -80), L.GIANT_TREE_V2, Vector2(-150, -94)], 3.5):
			continue
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 6.0):
			continue
		placed.append(p)
		k += 1
		if rng.randf() < 0.2:
			palm(nature, Vector3(p.x, HIGH, p.y), rng.randf_range(7.0, 10.0), rng.randf_range(2.0, 14.0), rng.randf_range(0.0, 360.0), k * 7)
		else:
			tree(nature, Vector3(p.x, HIGH, p.y), rng.randf_range(7.0, 12.0), rng.randf_range(2.6, 4.2), 0 if rng.randf() < 0.55 else 1, k * 13)
	_path(terrain, "WoodsPath", [Vector2(-90, -67), Vector2(-104, -80), Vector2(-116, -88)], 3.0, HIGH)
	_path(terrain, "CavePath", [Vector2(-118, -94), Vector2(-136, -98), Vector2(-150, -94)], 2.6, HIGH)
	# The abandoned camp: a lean-to, a cold fire ring, a chest, two crabs
	# who think it's theirs now.
	var camp := b.group("Camp", structures)
	var c := Vector3(-104, HIGH, -108)
	blk(camp, c + Vector3(0, 0, -2.0), Vector3(4.0, 2.4, 3.0), "thatch", Vector3(0, 0, 0), LevelBlock.Shape.RAMP, "LeanTo")
	for a in 7:
		var ang := TAU * a / 7.0
		rock(camp, c + Vector3(cos(ang) * 1.3, 0, 2.0 + sin(ang) * 1.3), Vector3(0.45, 0.35, 0.4), StylizedRock.Preset.DARK_ROCK, 300 + a, a * 40.0)
	blk(camp, c + Vector3(-2.6, 0, 2.4), Vector3(0.7, 0.6, 2.6), "wood", Vector3(0, 30, 0), LevelBlock.Shape.CYLINDER, "LogSeat")
	var chest := TreasureChest.new()
	chest.chest_id = &"castaway_camp_chest"
	chest.island_id = ISLAND
	chest.contents = "gem"
	chest.coins = 6
	chest.position = c + Vector3(3.4, 0, -0.8)
	chest.rotation_degrees.y = 200.0
	b.add(chest, gameplay, "CampChest")
	crab(c + Vector3(3.0, 0.05, 3.0), CrabModel.Variant.NORMAL, "castaway_crab_camp_1")
	crab(c + Vector3(-3.0, 0.05, 0.5), CrabModel.Variant.HERMIT, "castaway_crab_camp_2")
	# The hidden glade: a ring of flowers and a heart, behind the knoll.
	heart(Vector3(-80, HIGH + 2.0 + 0.6, -92))
	crab(Vector3(-128, HIGH + 0.05, -76), CrabModel.Variant.NORMAL, "castaway_crab_woods")
	crab(Vector3(-70, HIGH + 0.05, -104), CrabModel.Variant.ARMORED, "castaway_crab_woods_armored")
	coin_trail(Vector3(-92, HIGH + 0.6, -70), Vector3(-114, HIGH + 0.6, -88), 8, 0.0, CoinTrail.TrailShape.LINE)
	# Down to the north beach: a long wooden stair along the cliff.
	var s := steps(structures, Vector3(-36, SAND, -123.5), Vector3(-60, HIGH, -123.5), 3.0, "BeachStairs", LevelBlock.Shape.STAIRS, "wood")
	s.add_to_group(&"no_ledge_grab", true)
	blk(structures, Vector3(-62.4, HIGH - 0.6, -120.5), Vector3(4.4, 0.6, 7.0), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "BeachStairsLanding")
	coin_trail(Vector3(-38, SAND + 1.4, -123.5), Vector3(-54, HIGH - 3.0, -123.5), 5, 0.0, CoinTrail.TrailShape.LINE)


func _shift(pts: Array, by: Vector3) -> Array:
	var out: Array = []
	for p: Vector2 in pts:
		out.append(p + Vector2(by.x, by.z))
	return out


func _near_path(p: Vector2, line: Array, dist: float) -> bool:
	for i in line.size() - 1:
		if p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])) < dist:
			return true
	return false


## The giant tree: a trunk wider than a house, roots to climb on, and a
## spiral of branch platforms up to the treehouse in its crown, where a
## Heart Piece waits. Its canopy rides high above.
func _giant_tree() -> void:
	var g := b.group("GiantTree", structures)
	var c := L.GIANT_TREE
	var top := c.y + 26.0
	blk(g, c, Vector3(7.0, 26.0, 7.0), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Trunk")
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var out := Vector3(cos(a), 0, sin(a))
		blk(g, c + out * 5.4, Vector3(2.4, 2.2, 5.0), "wood_dark", Vector3(0, rad_to_deg(Player.yaw_of(-out)), 0), LevelBlock.Shape.RAMP, "Root%d" % (k + 1))
	# Branches spiralling up: a jump between each.
	for k in 12:
		var a := deg_to_rad(30.0 + 40.0 * k)
		var out := Vector3(cos(a), 0, sin(a))
		var y := c.y + 2.0 * (k + 1)
		blk(g, c + out * 5.7 + Vector3(0, y - c.y - 0.45, 0), Vector3(2.8, 0.45, 2.4), "wood", Vector3(0, rad_to_deg(Player.yaw_of(out)), 0), LevelBlock.Shape.BOX, "Branch%d" % (k + 1))
		blk(g, c + out * 4.0 + Vector3(0, y - c.y - 0.8, 0), Vector3(0.6, 0.6, 2.2), "wood_dark", Vector3(0, rad_to_deg(Player.yaw_of(out)), 0), LevelBlock.Shape.BOX, "Bough%d" % (k + 1))
		if k % 3 == 1:
			coin_trail(c + out * 5.7 + Vector3(0, y - c.y + 0.9, 0), c + out * 5.7 + Vector3(0, y - c.y + 0.9, 0), 1, 0.0, CoinTrail.TrailShape.LINE)
	# The treehouse deck on top of the trunk, its hut and the Heart Piece.
	blk(g, Vector3(c.x, top - 0.6, c.z), Vector3(8.4, 0.6, 8.4), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TreehouseDeck")
	_house(g, "Treehouse", Vector3(c.x + 0.6, top, c.z - 1.2), 0.0, {"size": Vector2(3.8, 3.0), "wall_height": 2.4, "roof_pitch": 1.4,
		"wall_color": Color("b58456"), "roof_color": Color("e8c66e"), "trim_color": Color("6e4128"), "windows": false, "seed": 41})
	for k in 10:
		var a := TAU * k / 10.0
		if k == 3:
			continue
		blk(g, Vector3(c.x + cos(a) * 3.9, top, c.z + sin(a) * 3.9), Vector3(0.18, 0.9, 0.18), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TreehouseRail")
	var piece := HeartPiece.new()
	piece.piece_id = &"castaway_heart_piece_tree"
	piece.position = Vector3(c.x - 1.8, top + 0.6, c.z + 1.6)
	b.add(piece, gameplay, "TreeHeartPiece")
	# The canopy, high over the deck and out past the spiral.
	var crown := PropBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	for k in 9:
		var a := TAU * k / 9.0 + rng.randf_range(-0.2, 0.2)
		var r := rng.randf_range(9.0, 12.0) if k % 2 == 0 else rng.randf_range(4.0, 7.0)
		var y := top + rng.randf_range(5.5, 9.0) if r < 8.0 else top + rng.randf_range(1.0, 6.0)
		var size := rng.randf_range(5.0, 7.0)
		var col := Color("3f9a3c").lerp(Color("2b7a3a"), rng.randf())
		crown.ellipsoid(Vector3(size, size * 0.7, size), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(c.x + cos(a) * r, y, c.z + sin(a) * r)), col, 4, 8)
	crown.ellipsoid(Vector3(9.0, 5.5, 9.0), Transform3D(Basis.IDENTITY, Vector3(c.x, top + 10.5, c.z)), Color("3f9a3c"), 5, 10)
	crown.flat_shade()
	var mi := MeshInstance3D.new()
	mi.mesh = crown.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	b.add(mi, g, "Canopy")
	crab(c + Vector3(6.0, 0.05, 6.0), CrabModel.Variant.NORMAL, "castaway_crab_tree")


## The dark cave in the woods' west: a rocky tunnel into a chamber too dark
## for Patchy until he has the lantern. Light both braziers to raise the
## gate: behind it the shovel, a mound (a treasure map) and a gem.
func _c(v: Vector3) -> Vector3:
	return v + Vector3(-174, 12, -52)


func _cave() -> void:
	var g := b.group("DarkCave", structures)
	blk(g, _c(Vector3(14.5, 7.0, -37.4)), Vector3(6, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelWallN")
	blk(g, _c(Vector3(13, 7.0, -31.6)), Vector3(9, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelWallS")
	blk(g, _c(Vector3(13, 11.0, -34.5)), Vector3(10, 1.4, 7.4), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "TunnelRoof")
	blk(g, _c(Vector3(13.5, 6.4, -42.6)), Vector3(10.4, 0.6, 10.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberFloor")
	blk(g, _c(Vector3(19.1, 7.0, -43.05)), Vector3(1.2, 4.0, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallE")
	blk(g, _c(Vector3(14.1, 7.0, -48.1)), Vector3(11.2, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallN")
	blk(g, _c(Vector3(7.9, 7.0, -43.05)), Vector3(1.2, 4.0, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallW")
	blk(g, _c(Vector3(18.6, 7.0, -37.4)), Vector3(2.2, 4.0, 1.2), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberWallSE")
	blk(g, _c(Vector3(13.5, 11.0, -43.05)), Vector3(12.4, 1.4, 11.3), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChamberRoof")
	# A rocky mound over it all, so it reads as a hill with a cave mouth.
	var mound := PropBuilder.new()
	mound.append(HorizonIsland.lump(Vector3(9.5, 4.0, 10.0), 77, Transform3D(Basis.IDENTITY, _c(Vector3(13.5, 11.6, -41.0))), 0.22, [], 6, 10))
	mound.recolor(func(q: Vector3, _n: Vector3, _col: Color) -> Color: return Color("8a8070").lerp(Color("6cbd45"), clampf((q.y - _c(Vector3.ZERO).y - 13.5) / 2.0, 0.0, 1.0)), 0)
	var mm := MeshInstance3D.new()
	mm.mesh = mound.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	b.add(mm, g, "CaveHill")
	var dz := DarknessZone.new()
	dz.size = Vector3(8.0, 4.0, 4.6)
	dz.inward = Vector3(-1, 0, 0)
	dz.refusal_depth = 2.2
	dz.position = _c(Vector3(12.4, 9.0, -34.5))
	b.add(dz, gameplay, "CaveDarkness")
	var dz2 := DarknessZone.new()
	dz2.size = Vector3(10.0, 4.0, 9.6)
	dz2.inward = Vector3(0, 0, -1)
	dz2.refusal_depth = 0.6
	dz2.position = _c(Vector3(13.5, 9.0, -42.8))
	b.add(dz2, gameplay, "ChamberDarkness")
	for z in [[-34.5, Vector3(9, 4, 4.6)], [-42.8, Vector3(10, 4, 9.6)]]:
		var zone := CameraZone.new()
		zone.distance_scale = 0.6
		zone.position = _c(Vector3(12.8, 9.0, z[0]))
		b.add(zone, gameplay, "CaveCameraZone")
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = z[1]
		cs.shape = box
		b.add(cs, zone, "Shape")
	var fire_a := Brazier.new()
	fire_a.brazier_id = &"castaway_cave_brazier_a"
	fire_a.position = _c(Vector3(10.0, 7.0, -40.6))
	b.add(fire_a, gameplay, "CaveBrazierA")
	var fire_b := Brazier.new()
	fire_b.brazier_id = &"castaway_cave_brazier_b"
	fire_b.position = _c(Vector3(17.0, 7.0, -40.6))
	b.add(fire_b, gameplay, "CaveBrazierB")
	dz.lit_by = [fire_a, fire_b]
	dz2.lit_by = [fire_a, fire_b]
	var gate := Gate.new()
	gate.gate_id = &"castaway_cave_gate"
	gate.size = Vector3(10.4, 4.0, 0.4)
	gate.position = _c(Vector3(13.5, 7.0, -42.6))
	gate.triggers = [fire_a, fire_b]
	b.add(gate, structures, "CaveGate")
	var shovel := AttachmentPickup.new()
	shovel.attachment_id = &"shovel"
	shovel.position = _c(Vector3(11.0, 7.0, -45.6))
	b.add(shovel, gameplay, "ShovelPickup")
	var spot := DigSpot.new()
	spot.spot_id = &"castaway_cave_mound"
	spot.island_id = ISLAND
	spot.contents = "map"
	spot.map_id = &"castaway_map_1"
	spot.position = _c(Vector3(16.0, 7.0, -45.6))
	b.add(spot, gameplay, "CaveMapMound")
	gem(_c(Vector3(13.5, 7.6, -46.6)), "castaway_gem_cave", Color("ffb347"))
	for z: float in [-30.6, -38.4]:
		var torch := Torch.new()
		torch.position = _c(Vector3(18.8, 7.0, z))
		b.add(torch, structures, "CaveTorch")


# --- Mount Patch --------------------------------------------------------------------

## The climb: a miner's stair (or rock steps for the nimble) from the
## highlands up to the shelf; the wall-kick chimney (or ledges round the
## west) up to the upper rocks; pillars spiralling round the summit; and
## the summit itself, with the Ship's Compass, parrot #3, an old mast to
## climb and the best view in the archipelago. The summit slide is the fast
## way down. A stream off the shelf feeds the waterfall.
func _mountain() -> void:
	var g := b.group("MountPatch", structures)
	# Highlands -> shelf: the miner's stair and rock steps on the south-west.
	var stair := steps(g, Vector3(14, HIGH, -34.4), Vector3(14, SHELF, -47.9), 3.0, "ShelfStairs", LevelBlock.Shape.STAIRS, "wood")
	stair.add_to_group(&"no_ledge_grab", true)
	var k := 0
	for d: Array in [[Vector3(-37, HIGH, -46), 21.2], [Vector3(-34.5, HIGH, -49.5), 23.4], [Vector3(-31, HIGH, -51.5), 25.6], [Vector3(-27.5, HIGH, -53.4), 27.8]]:
		k += 1
		blk(g, d[0], Vector3(3.2, float(d[1]) - HIGH, 3.2), "rock", Vector3(0, k * 31.0, 0), LevelBlock.Shape.CYLINDER, "RockStep%d" % k)
	# Shelf -> upper: the wall-kick chimney, and ledges round the west.
	blk(g, Vector3(4.2, SHELF, -55.0), Vector3(1.4, UPPER - SHELF, 6.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChimneyWest")
	blk(g, Vector3(8.0, SHELF, -55.0), Vector3(1.4, UPPER - SHELF, 6.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ChimneyEast")
	coin_trail(Vector3(6.1, SHELF + 1.6, -53.0), Vector3(6.1, UPPER - 1.0, -55.0), 6, 0.0, CoinTrail.TrailShape.LINE)
	k = 0
	for d: Array in [[Vector3(-18, SHELF, -66), 32.2], [Vector3(-19.5, SHELF, -69.2), 34.4], [Vector3(-21, SHELF, -72.4), 36.6],
			[Vector3(-22.5, SHELF, -75.6), 38.8], [Vector3(-23.2, SHELF, -78.8), 41.0]]:
		k += 1
		blk(g, d[0], Vector3(2.8, float(d[1]) - SHELF, 2.8), "stone", Vector3(0, k * 29.0, 0), LevelBlock.Shape.CYLINDER, "WestLedge%d" % k)
	# Upper -> summit: pillars round the summit's east side, each a little
	# higher than the last.
	k = 0
	for deg: float in [75.0, 55.0, 35.0, 15.0, -5.0, -25.0, -45.0]:
		var a := deg_to_rad(deg)
		var at := Vector3(11 + 15 * cos(a), UPPER, -79 + 15 * sin(a))
		var h := 1.7 * (k + 1)
		k += 1
		blk(g, at, Vector3(2.6, h, 2.6), "stone", Vector3(0, k * 17.0, 0), LevelBlock.Shape.CYLINDER, "SummitPillar%d" % k)
		if k % 2 == 0:
			coin_trail(at + Vector3(0, h + 0.8, 0), at + Vector3(0, h + 0.8, 0), 1, 0.0, CoinTrail.TrailShape.LINE)
	# The summit: the Ship's Compass, parrot #3, an old mast with a nest on
	# top (a gem), a flag.
	var part := ShipPartPickup.new()
	part.part_id = &"compass"
	part.display_name = "Ship's Compass"
	part.position = Vector3(8, SUMMIT, -80)
	b.add(part, gameplay, "ShipCompass")
	cage(Vector3(15, SUMMIT, -74), "castaway_parrot_summit", ParrotModel.Plumage.LIME)
	blk(g, Vector3(13, SUMMIT, -86), Vector3(0.9, 6.0, 0.9), "wood", Vector3(0, 0, -5), LevelBlock.Shape.CYLINDER, "SummitMast")
	blk(g, Vector3(13.5, SUMMIT + 5.6, -86), Vector3(3.0, 0.4, 3.0), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "SummitNest")
	gem(Vector3(13.5, SUMMIT + 6.6, -86), "castaway_gem_summit_nest", Palette.GEM_BLUE)
	blk(g, Vector3(4, SUMMIT, -86), Vector3(0.16, 6.5, 0.16), "wood", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "SummitFlagPole")
	# The summit slide: a sandy chute down to the shelf's west side, with
	# low rails to keep Patchy on it.
	var chute := _slab(terrain, "SummitSlide", Vector3(-34, SHELF, -92), Vector3(0.2, SUMMIT, -86.2), 4.0, 0.8, "sand")
	chute.slide_surface = true
	for side: float in [-1.0, 1.0]:
		var off := Vector3(-6, 0, 33).normalized() * 2.15 * side
		_slab(structures, "SlideRail", Vector3(-34, SHELF + 0.5, -92) + off, Vector3(-1.4, SUMMIT + 0.5, -86.3) + off, 0.3, 0.5, "wood")
	# The shelf's east shoulder stands a little higher.
	plateau(terrain, "ShelfShoulder", [Vector2(31, -56), Vector2(42, -59), Vector2(50, -67), Vector2(53, -80), Vector2(50, -92),
		Vector2(40, -98), Vector2(33, -88), Vector2(35, -70)], SHELF + 2.6, 6.0, "cliff_warm", {"seed": 61})
	# Crags breaking up the mountain's skyline.
	var crags := PropBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	for d: Array in [[Vector3(-30, SHELF, -86), Vector3(4, 5, 4)], [Vector3(44, SHELF + 2.6, -86), Vector3(4.5, 6, 4)], [Vector3(30, SHELF, -100), Vector3(3.5, 4, 3.5)],
			[Vector3(-12, UPPER, -88), Vector3(3, 4.5, 3)], [Vector3(28, UPPER, -88), Vector3(3, 4, 3)], [Vector3(20, SUMMIT, -88), Vector3(2.4, 3.5, 2.4)],
			[Vector3(-42, HIGH, -66), Vector3(3.5, 6, 3.5)], [Vector3(54, HIGH, -96), Vector3(4, 7, 4)], [Vector3(-36, HIGH, -98), Vector3(4, 6.5, 3.5)],
			[Vector3(46, HIGH, -54), Vector3(3, 5, 3)], [Vector3(-8, SHELF, -103), Vector3(3.5, 4, 3)], [Vector3(8, UPPER, -97), Vector3(3, 4, 3)],
			[Vector3(-4, SUMMIT, -84), Vector3(1.8, 2.6, 1.8)]]:
		var from := crags.mark()
		crags.append(HorizonIsland.lump(d[1], rng.randi(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), d[0]), 0.25, [], 5, 8))
		crags.recolor(func(_q: Vector3, _n: Vector3, _col: Color) -> Color: return Color("a9a59c").lerp(Color("8a857c"), rng.randf()), from)
	var cm := MeshInstance3D.new()
	cm.mesh = crags.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	b.add(cm, g, "Crags")
	# The stream off the shelf: a little fall, then across the lawn to the
	# big falls' lip.
	_falls(g, "ShelfFalls", Vector3(26, SHELF, -50.6), HIGH, 3.2, Vector3.BACK)
	var stream := WaterVolume.new()
	stream.show_surface = true
	stream.wave_height = 0.01
	stream.size = Vector3(3.2, 0.5, 18.0)
	stream.position = Vector3(26, HIGH + 0.12, -40.4)
	b.add(stream, g, "Stream")
	crab(Vector3(24, SHELF + 0.05, -56), CrabModel.Variant.NORMAL, "castaway_crab_shelf")
	crab(Vector3(-10, SHELF + 0.05, -96), CrabModel.Variant.HERMIT, "castaway_crab_shelf_2")
	gem(Vector3(44, SHELF + 2.6 + 6.6, -86), "castaway_gem_crag", Color("3ddc97"))
	coin_trail(Vector3(14, HIGH + 1.4, -36.4), Vector3(14, SHELF + 0.8, -47.0), 6, 0.0, CoinTrail.TrailShape.LINE)


# --- The gorge and the old fort (north-east) ---------------------------------------

## A slab of rock (or wood) tilted from `from` up to `to`, `width` wide and
## `thick` deep: a chute, a plank, a fallen pillar.
func _slab(parent: Node, node_name: String, from: Vector3, to: Vector3, width: float, thick: float, surface: String) -> LevelBlock:
	var d := to - from
	var flat := Vector3(d.x, 0, d.z)
	var l := blk(parent, Vector3.ZERO, Vector3(width, thick, d.length()), surface, Vector3.ZERO, LevelBlock.Shape.BOX, node_name)
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	l.transform = Transform3D(basis, (from + to) * 0.5 - basis.y * thick)
	l.set_meta(&"flat_length", flat.length())
	return l


## The gorge between the highlands and the headland (six parrots can lay
## the old log across it), and the old fort on the headland: ruined walls
## and towers to clamber over, Brock's crocs in the yard, Patchy's chest in
## chains, the powder room, King Claw's ring on the point, and the pillar
## off the east cliff with the hand cannon on top.
func _gorge_and_fort() -> void:
	var g := b.group("Headland", gameplay)
	var log_body := FallenLog.new()
	log_body.length = 24.0
	log_body.position = Vector3(57.0, HIGH + 0.75, -72.0)
	log_body.rotation_degrees.y = 90.0
	b.add(log_body, g, "FallenLog")
	var dest := Marker3D.new()
	dest.position = Vector3(70.0, HIGH - 0.45, -80.0)
	b.add(dest, g, "LogBridgeSpot")
	var task := ParrotTask.new()
	task.task_id = &"castaway_log_bridge"
	task.required_parrots = 6
	task.carried = log_body
	task.destination = dest
	task.position = Vector3(55.0, HIGH, -86.0)
	b.add(task, g, "LogBridgeTask")
	_fort_ruins()
	# Patchy's sea chest, chained: pound all three mooring posts.
	var posts: Array[PoundPost] = []
	var center := L.FORT_YARD
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
	for d: Array in [[Vector3(92, FORT + 0.05, -84), "castaway_croc_1", 250.0], [center + Vector3(8, 0.05, 6), "castaway_croc_2", 120.0],
			[Vector3(140, FORT + 0.05, -82), "castaway_croc_3", 200.0]]:
		var croc := CrocGrunt.new()
		croc.persistent_id = StringName(d[1])
		croc.position = d[0]
		croc.rotation_degrees.y = d[2]
		b.add(croc, enemies, "CrocGrunt")
	_boss_arena()
	# The grapple tease: a big iron ring on a sea pillar off the east cliff,
	# far out of hook range; the hand cannon waits on top.
	plateau(terrain, "GrapplePillar", _blob(Vector2(198, -95), 4.0, 4.2, 31, 0.0, 8, 0.12), FORT + 8.5, 34.0, "rock", {"seed": 31})
	blk(structures, Vector3(197.6, FORT + 8.5, -94.4), Vector3(0.5, 5.8, 0.5), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "PillarPole")
	var tease := HookPoint.new()
	tease.grapple_only = true
	tease.grapple_arrival = "hop"
	tease.hang_length = 0.0
	tease.position = Vector3(197.0, FORT + 13.5, -93.8)
	tease.scale = Vector3.ONE * 2.0
	b.add(tease, g, "GrappleTease")
	var cannon := AttachmentPickup.new()
	cannon.attachment_id = &"cannon"
	cannon.position = Vector3(199.4, FORT + 8.5, -95.8)
	b.add(cannon, g, "CannonPickup")
	gem(Vector3(176, FORT + 0.6, -112), "castaway_gem_headland", Color("9b5cff"))
	_checkpoint(gameplay, "cp_fort", Vector3(86, FORT, -84), 90.0, "CpFort")


## The fort's ruins round its yard: walls (broken through here and there,
## walkable along the top), four corner towers (the north-east one still
## tall enough for a lookout and a cannon target), the gatehouse facing the
## gorge, and the powder room whose gate opens to two cannon targets.
func _fort_ruins() -> void:
	var g := b.group("Fort", structures)
	var x0 := 100.0
	var x1 := 148.0
	var z0 := -110.0
	var z1 := -74.0
	var wall_h := 4.6
	var t := 1.8
	# Walls as runs between gaps: [from, to] along each side.
	for run: Array in [[Vector3(x0, FORT, z1), Vector3(127, FORT, z1)], [Vector3(134, FORT, z1), Vector3(x1, FORT, z1)],
			[Vector3(x0, FORT, z0), Vector3(111, FORT, z0)], [Vector3(117, FORT, z0), Vector3(x1, FORT, z0)],
			[Vector3(x0, FORT, z0), Vector3(x0, FORT, -95.5)], [Vector3(x0, FORT, -88.5), Vector3(x0, FORT, z1)],
			[Vector3(x1, FORT, z0), Vector3(x1, FORT, -97)], [Vector3(x1, FORT, -90), Vector3(x1, FORT, z1)]]:
		var a: Vector3 = run[0]
		var c: Vector3 = run[1]
		var along := c - a
		var mid := (a + c) * 0.5
		var size := Vector3(t, wall_h, along.length() + t) if absf(along.x) < 0.1 else Vector3(along.length() + t, wall_h, t)
		blk(g, mid, size, "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "Wall")
		# Crenellations along the top's outer edge (a walkway inside them).
		var outward := Vector3(signf(mid.x - (x0 + x1) * 0.5), 0, 0) if absf(along.x) < 0.1 else Vector3(0, 0, signf(mid.z - (z0 + z1) * 0.5))
		var n := int(along.length() / 2.4)
		for i in n:
			var p := a.lerp(c, (i + 0.5) / n) + Vector3(0, wall_h, 0) + outward * 0.5
			blk(g, p, Vector3(0.8, 0.7, 0.8), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "Merlon")
	# Corner towers (the north-west one fallen to a stump).
	for d: Array in [[Vector3(x0, FORT, z1), 8.5], [Vector3(x1, FORT, z1), 8.5], [Vector3(x0, FORT, z0), 5.4], [Vector3(x1, FORT, z0), 10.5]]:
		blk(g, d[0], Vector3(6.6, float(d[1]), 6.6), "stone", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "Tower")
		blk(g, d[0] + Vector3(0, float(d[1]), 0), Vector3(7.2, 0.5, 7.2), "stone", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "TowerTop")
	# Stone stairs up the inside of the south wall, and ledges up the
	# towers from the wall tops.
	steps(g, Vector3(112, FORT, -76.0), Vector3(121, FORT + wall_h, -76.0), 2.2, "WallStairs", LevelBlock.Shape.STAIRS, "stone")
	for d: Array in [[Vector3(x1 - 4.6, FORT + wall_h, z1 + 0.2), 2.2], [Vector3(x1 - 2.6, FORT + wall_h, z0 + 4.2), 2.1], [Vector3(x1 - 4.8, FORT + wall_h + 2.1, z0 + 2.4), 2.1],
			[Vector3(x0 + 3.6, FORT + wall_h, z1 + 0.2), 2.0]]:
		blk(g, d[0], Vector3(1.8, float(d[1]), 1.8), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "TowerStep")
	# The gatehouse on the west wall, facing the gorge.
	for z: float in [-96.2, -87.8]:
		blk(g, Vector3(x0, FORT, z), Vector3(3.0, 6.4, 1.8), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "GatePillar")
	blk(g, Vector3(x0, FORT + 6.4, -92.0), Vector3(3.2, 1.2, 10.2), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "GateLintel")
	# Brock's flags on the towers.
	var flags := MeshBuilder.new()
	for d: Vector3 in [Vector3(x0, FORT + 8.5, z1), Vector3(x1, FORT + 10.5, z0), Vector3(x1, FORT + 8.5, z1)]:
		var pole := d + Vector3(1.6, 0, 1.6)
		blk(g, pole, Vector3(0.14, 4.0, 0.14), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "FlagPole")
		# Croc green with a row of white teeth.
		var top := pole + Vector3(0, 3.9, 0)
		flags.triangle(top, top + Vector3(2.2, 0, 0), top + Vector3(2.2, -1.4, 0), Color("3f8a3a"), true)
		flags.triangle(top, top + Vector3(2.2, -1.4, 0), top + Vector3(0, -1.4, 0), Color("3f8a3a"), true)
		for tooth in 4:
			var x := 0.3 + tooth * 0.48
			flags.triangle(top + Vector3(x, -0.7, 0.02), top + Vector3(x + 0.42, -0.7, 0.02), top + Vector3(x + 0.21, -1.02, 0.02), Color.WHITE, true)
	var fm := MeshInstance3D.new()
	fm.mesh = flags.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	b.add(fm, g, "BrockFlags")
	# Old guns on the south wall, pointing out to sea.
	for x: float in [136.5, 141.0]:
		var gun := DecorCannon.new()
		gun.position = Vector3(x, FORT + wall_h, z1 - 0.3)
		gun.rotation_degrees.y = 180.0
		b.add(gun, g, "FortCannon")
	# The powder room in the yard's north-west corner.
	var v := Vector3(106.5, FORT, -104.0)
	blk(g, v + Vector3(0, 0, -2.2), Vector3(5.0, 3.6, 0.8), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultBack")
	blk(g, v + Vector3(-2.2, 0, 0), Vector3(0.8, 3.6, 5.0), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultW")
	blk(g, v + Vector3(2.2, 0, 0), Vector3(0.8, 3.6, 5.0), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultE")
	blk(g, v + Vector3(0, 3.6, 0), Vector3(5.6, 0.8, 5.6), "stone", Vector3.ZERO, LevelBlock.Shape.BOX, "VaultRoof")
	var t1 := CannonTarget.new()
	t1.target_id = &"castaway_target_arch"
	t1.position = Vector3(196.0, 12.0, 13.0)
	t1.rotation_degrees.y = 90.0
	b.add(t1, g, "TargetArch")
	var t2 := CannonTarget.new()
	t2.target_id = &"castaway_target_tower"
	t2.position = Vector3(x1 - 1.6, FORT + 11.0, z0 + 1.6)
	t2.rotation_degrees.y = 200.0
	b.add(t2, g, "TargetTower")
	var vault := Gate.new()
	vault.gate_id = &"castaway_vault_gate"
	vault.size = Vector3(3.6, 3.6, 0.4)
	vault.position = v + Vector3(0, 0, 2.2)
	vault.triggers = [t1, t2]
	b.add(vault, g, "VaultGate")
	gem(v + Vector3(0, 0.8, -0.6), "castaway_relic_vault", Palette.GOLD, "relic")
	coin_trail(v + Vector3(-1.2, 0.5, 0.6), v + Vector3(1.2, 0.5, 0.6), 4, 0.0, CoinTrail.TrailShape.LINE)
	gem(Vector3(x1, FORT + 11.2, z0), "castaway_gem_fort_tower", Palette.GEM_RED)
	coin_trail(Vector3(x0 + 5.5, FORT + wall_h + 0.6, z1 - 0.45), Vector3(126, FORT + wall_h + 0.6, z1 - 0.45), 8, 0.0, CoinTrail.TrailShape.LINE)


## King Claw's ring on the headland's point: tall rock spires with gaps.
## Stepping in wakes him; leaving resets the fight.
func _boss_arena() -> void:
	var g := b.group("ClawArena", structures)
	var center := L.CLAW_RING
	var arena_r := 11.0
	for k in 10:
		var a := TAU * k / 10.0 + 0.2
		# Leave a wide way in facing the fort (south-west).
		if k == 3 or k == 4:
			continue
		var h := 3.6 + 1.2 * sin(k * 2.3)
		var spire := blk(g, center + Vector3(cos(a), 0, sin(a)) * (arena_r + 1.4), Vector3(1.8, h, 1.8), "rock", Vector3(0, k * 37.0, 0), LevelBlock.Shape.CYLINDER, "Spire")
		spire.add_to_group(&"no_ledge_grab", true)
	var boss := KingClaw.new()
	boss.position = center
	boss.arena_center = center
	boss.arena_radius = arena_r
	boss.rotation_degrees.y = 200.0
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
	_checkpoint(gameplay, "cp_claw_arena", center + Vector3(-9.0, 0, 13.0), 30.0, "CpClawArena")


# --- The east downs -----------------------------------------------------------------

## Grassy downs above the east coast: a ramp up from the meadow, the grotto
## behind its cracked rock (a TNT snail and a careless crab nearby), and the
## sea arch off the coast, climbable by a rock and a ledge grab, with a gem
## along its top and a cannon target at its far end.
func _east_downs() -> void:
	var g := b.group("EastDowns", structures)
	steps(terrain, Vector3(96, LOW - 0.05, 20), Vector3(114.2, DOWNS, 20), 5.0, "DownsRamp", LevelBlock.Shape.RAMP, "grass")
	var grotto := Vector3(100.5, LOW, -8.0)
	blk(g, grotto + Vector3(2.4, 0, 0), Vector3(1.0, 3.2, 4.4), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoBack")
	blk(g, grotto + Vector3(0, 0, -2.0), Vector3(4.8, 3.2, 0.8), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoSideN")
	blk(g, grotto + Vector3(0, 0, 2.0), Vector3(4.8, 3.2, 0.8), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoSideS")
	blk(g, grotto + Vector3(0.1, 3.2, 0), Vector3(5.2, 0.9, 4.8), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "GrottoRoof")
	var crack := CrackedRock.new()
	crack.rock_id = &"castaway_grotto_rock"
	crack.size = Vector3(3.2, 3.2, 0.9)
	crack.position = grotto + Vector3(-2.1, 0, 0)
	crack.rotation_degrees.y = 90.0
	b.add(crack, g, "GrottoCrackedRock")
	gem(grotto + Vector3(0.8, 0.6, 0), "castaway_gem_grotto", Color("3ddc97"))
	coin_trail(grotto + Vector3(1.6, 0.6, -1.0), grotto + Vector3(1.6, 0.6, 1.0), 3, 0.0, CoinTrail.TrailShape.LINE)
	var snail := TNTSnail.new()
	snail.position = grotto + Vector3(-6.0, 0.05, 3.0)
	snail.rotation_degrees.y = 60.0
	b.add(snail, enemies, "SnailGrotto")
	var c := crab(grotto + Vector3(-4.0, 0.05, -2.0), CrabModel.Variant.NORMAL, "castaway_crab_grotto")
	c.patrol_radius = 3.5
	# The sea arch.
	plateau(terrain, "StepRock", _blob(Vector2(191, -10), 1.8, 1.8, 51, 0.0, 8, 0.1), DOWNS + 2.2, 16.0, "rock", {"seed": 51})
	plateau(terrain, "ArchPillarS", _blob(Vector2(196, -14), 4.0, 3.6, 53, 20.0, 9, 0.14), 12.0, 24.0, "rock", {"seed": 53})
	plateau(terrain, "ArchPillarN", _blob(Vector2(196, 12), 4.0, 3.8, 55, -10.0, 9, 0.14), 12.0, 24.0, "rock", {"seed": 55})
	var span := blk(g, Vector3(196, 10.0, -1.0), Vector3(5.0, 2.0, 22.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "ArchSpan")
	span.bevel = 0.4
	gem(Vector3(196, 12.7, -1.0), "castaway_gem_arch", Color("ff5fa2"))
	coin_trail(Vector3(196, 12.6, -10), Vector3(196, 12.6, 8), 6, 0.0, CoinTrail.TrailShape.LINE)
	crab(Vector3(150, DOWNS + 2.0 + 0.05, 0), CrabModel.Variant.NORMAL, "castaway_crab_downs")
	crab(Vector3(170, DOWNS + 0.05, -40), CrabModel.Variant.HERMIT, "castaway_crab_downs_2")
	gem(Vector3(150, DOWNS + 2.0 + 0.7, 0), "castaway_gem_downs", Color("ffd34d"))


# --- The north beach ----------------------------------------------------------------

## Under the cliffs: Shellby's chart's X by a cairn of stones, the
## smuggler's nook (a chest under a rock overhang) and the stair up.
func _north_beach() -> void:
	var g := b.group("NorthBeach", structures)
	var x_spot := DigSpot.new()
	x_spot.spot_id = &"castaway_x_north"
	x_spot.island_id = ISLAND
	x_spot.contents = "goblet"
	x_spot.gem_color = Palette.GEM_BLUE
	x_spot.coins = 10
	x_spot.hidden = true
	x_spot.marked_by_map = &"castaway_map_2"
	x_spot.position = Vector3(8.0, SAND, -131.0)
	b.add(x_spot, gameplay, "NorthBeachX")
	var cairn := b.group("Cairn", gameplay)
	rock(cairn, Vector3(9.8, 1.2, -129.9), Vector3(1.3, 0.8, 1.2), StylizedRock.Preset.SAND_ROCK, 71, 20.0)
	rock(cairn, Vector3(9.8, 1.85, -129.9), Vector3(0.9, 0.6, 0.85), StylizedRock.Preset.SAND_ROCK, 73, 70.0)
	rock(cairn, Vector3(9.8, 2.3, -129.9), Vector3(0.55, 0.45, 0.5), StylizedRock.Preset.SAND_ROCK, 79, 140.0)
	# The smuggler's nook: a rock overhang against the cliff.
	var n := Vector3(-14, SAND, -119.0)
	blk(g, n + Vector3(-5.0, 0, 0), Vector3(1.4, 5.0, 6.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "NookWallW")
	blk(g, n + Vector3(5.0, 0, 0), Vector3(1.4, 5.0, 6.0), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "NookWallE")
	blk(g, n + Vector3(0, 5.0, 0.6), Vector3(12.0, 1.6, 7.6), "rock", Vector3.ZERO, LevelBlock.Shape.BOX, "NookRoof")
	var chest := TreasureChest.new()
	chest.chest_id = &"castaway_nook_chest"
	chest.island_id = ISLAND
	chest.contents = "pearl"
	chest.coins = 8
	chest.position = n + Vector3(0, 0, 1.0)
	chest.rotation_degrees.y = 180.0
	b.add(chest, gameplay, "NookChest")
	crab(n + Vector3(2.0, 0.05, -2.5), CrabModel.Variant.HERMIT, "castaway_crab_nook")
	crab(Vector3(30, SAND + 0.05, -128), CrabModel.Variant.NORMAL, "castaway_crab_north")
	coin_trail(Vector3(-30, SAND + 0.6, -128), Vector3(-6, SAND + 0.6, -128), 7, 0.0, CoinTrail.TrailShape.LINE)


# --- Side quest, islets and islanders -------------------------------------------

# --- Side quest and islanders -------------------------------------------------------

## The side quest (spec §103): Brock's crabs stole Old Shellby's fishing boat,
## the Barnacle Betty, and hauled her up Gull Rock on the west beach.
## Follow the drag marks along the beach and up the crabs' plank ramp, grab
## the ledge to the top, and call three parrots to fly her home to Shellby's
## jetty on the bay's west shore. Shellby pays with his old chart, whose X
## is on the north beach.
func _barnacle_betty() -> void:
	var g := b.group("BarnacleBetty", gameplay)
	# Gull Rock stands at the west beach's edge, half in the sea.
	var gull := Vector3(-124, 0, 54)
	var jetty := Dock.new()
	jetty.length = 11.0
	jetty.width = 2.6
	jetty.post_depth = 7.0
	jetty.water_line = -1.2
	jetty.position = Vector3(-140.0, 1.35, 96.0)
	jetty.rotation_degrees.y = -90.0
	b.add(jetty, structures, "ShellbyJetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(-128.0, 0.0, 99.0)
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
	npc.position = Vector3(-142.4, 1.35, 94.6)
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
	marks.points = PackedVector3Array([Vector3(-144, 1.2, 92), Vector3(-152, 1.2, 82), Vector3(-162, 1.2, 70), Vector3(-171, 1.2, 56),
		Vector3(-176, 1.2, 42), Vector3(-178, 1.2, 28), Vector3(-176.5, 1.2, 18), Vector3(-175.5, 1.2, 14)])
	marks.seed = 3
	b.add(marks, g, "DragMarks")
	var ramp_marks := DragMarks.new()
	ramp_marks.points = PackedVector3Array([Vector3(-53, 1.2, -40) + gull, Vector3(-61, 5.4, -40) + gull, Vector3(-65.4, 5.4, -40.4) + gull])
	ramp_marks.footprints = false
	ramp_marks.groove_color = Color("6e4a2c")
	ramp_marks.berm_color = Color("c9a46c")
	ramp_marks.seed = 5
	b.add(ramp_marks, g, "RampDragMarks")
	coin_trail(Vector3(-170, 1.6, 60), Vector3(-176, 1.6, 44), 4, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(Vector3(-54.5, 2.2, -40) + gull, Vector3(-59.5, 4.9, -40) + gull, 4, 0.0, CoinTrail.TrailShape.LINE)



func _driftwood_key() -> void:
	var g := b.group("DriftwoodKey", gameplay)
	var t := b.group("DriftwoodTerrain", terrain)
	var c := L.DRIFTWOOD
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
		"castaway_parrot_summit|There's a cage right on top of Mount Patch! Up the miner's stair, the chimney or the west ledges, then hop the pillars round the summit.",
		"castaway_parrot_stack|A cage sits on the sea stack by your wreck. Only a mighty long jump from the crow's nest gets you there.",
		"driftwood_parrot_tower|Southwest, over the water: Driftwood Key! A cage tops a tower of lashed rafts.",
		"driftwood_parrot_pen|More on Driftwood Key: the crabs keep one in a pen up on the knoll. Guarded, mind you.",
	])
	tok.all_free_lines = PackedStringArray(["Not a single cage left! The sky's full of your friends."])
	tok.talked_flag = &"castaway_met_tok"
	tok.position = L.TOWER + Vector3(-2.2, 14.1, -1.6)
	b.add(tok, gameplay, "Tok")
	var monkey := MonkeyModel.new()
	monkey.rotation.y = Player.yaw_of(Vector3(-1, 0, -0.6))
	b.add(monkey, tok, "MonkeyModel")
	tok.model = monkey
	var c := L.DRIFTWOOD
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
	fisher.position = Vector3(-101.4, QUAY, 76.0)
	b.add(fisher, gameplay, "Marlo")
	var otter2 := OtterModel.new()
	otter2.rotation.y = Player.yaw_of(Vector3.RIGHT)
	b.add(otter2, fisher, "OtterModel")
	fisher.model = otter2


## The strait between the bay mouth and Driftwood Key (spec §117: no long
## stretches of nothing): a bell buoy to steer by, flotsam to ram for coins,
## a coin trail on the water, a pod of dolphins that races the boat, and
## Gull Bar, a sandbar islet just off the route with its own little prize.
func _crossing() -> void:
	var g := b.group("Crossing", gameplay)
	var buoy := BellBuoy.new()
	buoy.position = Vector3(-160, 0, 160)
	b.add(buoy, g, "BellBuoy")
	var k := 0
	for p: Vector3 in [Vector3(-136, 0, 148), Vector3(-146, 0, 146), Vector3(-176, 0, 172), Vector3(-184, 0, 170)]:
		k += 1
		var barrel := FloatingBarrel.new()
		barrel.barrel_id = StringName("crossing_barrel_%d" % k)
		barrel.position = p
		b.add(barrel, g, "FloatingBarrel")
	coin_trail(Vector3(-150, 1.0, 155), Vector3(-157, 1.0, 158.5), 5, 0.0, CoinTrail.TrailShape.LINE)
	var pod := DolphinPod.new()
	pod.position = Vector3(-165, 0, 172)
	b.add(pod, g, "DolphinPod")
	# Gull Bar: a sandbar off the harbor mouth, in Castaway's own waters,
	# with a palm, a crate of coins and a gem.
	var bar := Vector2(-20, 146)
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
	for d: Array in [["Lookout", Vector3(124, FORT, -147.0), Vector3(0, 0, -1)], ["Hold", Vector3(124, 0, -172), Vector3(0, 0, 1)],
			["EnterFrom", Vector3(170, 0, -205), Vector3(-32, 0, 26)], ["ExitTo", Vector3(70, 0, -212), Vector3(-42, 0, -36)]]:
		var m := Marker3D.new()
		m.position = d[1]
		m.rotation.y = Player.yaw_of(d[2])
		b.add(m, g, d[0])
		marks[d[0]] = m
	cameo.lookout = marks["Lookout"]
	cameo.hold = marks["Hold"]
	cameo.enter_from = marks["EnterFrom"]
	cameo.exit_to = marks["ExitTo"]
	cameo.trigger_radius = 60.0
	var barge := RoyalBarge.new()
	barge.position = (marks["EnterFrom"] as Marker3D).position
	b.add(barge, g, "RoyalBarge")
	cameo.barge = barge


## The Sunken Sloop (spec §114: dense underwater areas). Off the south coast a
## little ship lies on the seabed among coral, kelp and fish. A chest sits
## in its lee, and a trail of coins leads down from the shallows.
func _sunken_reef() -> void:
	var g := b.group("SunkenReef", gameplay)
	var c := Vector3(40, -10.0, 146)
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
	coin_trail(Vector3(36, -2.0, 128), Vector3(39, -8.6, 140), 7, 0.0, CoinTrail.TrailShape.LINE)
	coin_trail(c + Vector3(-4, 1.6, -8), Vector3.ZERO, 8, 0.0, CoinTrail.TrailShape.RING)
	var hint := TutorialHint.new()
	hint.hint_id = &"hint_swim_down"
	hint.text = "Swim down with {dive}, back up with {jump}. Something glints below..."
	hint.size = Vector3(18, 6, 12)
	hint.position = Vector3(36, -1.0, 128)
	b.add(hint, g, "HintSwimDown")


## Beak Rock (spec §194): the Sunken Sloop's chest holds a map of a little
## island with a stone parrot on it. It's Driftwood Key, sailed past on the
## way to the tower parrot: the parrot-shaped rock by the raft tower keeps
## watch along the south beach, and the X is in the sand where its beak
## points.
func _beak_rock() -> void:
	var g := b.group("BeakRock", gameplay)
	var rock := BeakRock.new()
	rock.position = L.DRIFTWOOD + Vector3(-13.5, 1.0, 14.0)
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


## Two more villagers with a tip each for the curious: Bubbles the otter
## by the well (the waterfall's secret), Juno the monkey by the bell tower
## (the giant tree in the woods).
func _villagers() -> void:
	var bubbles := NPC.new()
	bubbles.display_name = "Bubbles"
	bubbles.lines = PackedStringArray([
		"You fell out of the sky! No wait, the sea. You fell out of the sea!",
		"And this morning a whole gang of crabs went by carrying a big chest! Up past the meadow, toward the old fort.",
		"Wanna know a secret? There's a cave BEHIND the waterfall. Walk along the rocks at the bottom of the cliff.",
		"And the stone posts next to it go all the way up the cliff. I'm not allowed to climb them. Yet.",
	])
	bubbles.repeat_lines = PackedStringArray(["Behind the waterfall! Along the rocks! Don't tell my mum I told you.",
		"I counted the stairs to the top terrace. Then I forgot. Then I counted again."])
	bubbles.talked_flag = &"castaway_met_bubbles"
	bubbles.position = Vector3(-107.5, LOW, 37.6)
	b.add(bubbles, gameplay, "Bubbles")
	var otter := OtterModel.new()
	otter.rotation.y = Player.yaw_of(Vector3(-0.4, 0, 1))
	otter.scale = Vector3.ONE * 0.8
	b.add(otter, bubbles, "OtterModel")
	bubbles.model = otter
	var juno := NPC.new()
	juno.display_name = "Juno"
	juno.lines = PackedStringArray([
		"Ooh, a new face. And a hook! Very climb-y.",
		"Over the rope bridge from the bluff, the woods go on and on. In the middle there's a tree so big it has a house on top.",
		"Branch, jump, branch, jump, all the way up. Something shiny's kept up there. I'd fetch it, but heights.",
	])
	juno.repeat_lines = PackedStringArray(["The giant tree! Branch, jump, branch, jump.",
		"Ring the bell on the tower if you can get up there. Everyone pretends they don't love it."])
	juno.talked_flag = &"castaway_met_juno"
	juno.position = Vector3(-136, TERRACE, -22.5)
	b.add(juno, gameplay, "Juno")
	var monkey := MonkeyModel.new()
	monkey.rotation.y = Player.yaw_of(Vector3(0, 0, 1))
	b.add(monkey, juno, "MonkeyModel")
	juno.model = monkey


# --- Waters, checkpoints, hints ------------------------------------------------------

func _sea_regions() -> void:
	var home := SeaRegion.new()
	home.region_name = "Castaway Cay"
	home.island_id = ISLAND
	home.radius = L.WATERS_RADIUS
	home.position = L.WATERS_CENTER
	home.boat_dock = structures.get_node("Harbor/BoatMooring")
	home.arrival = gameplay.get_node("PierArrival")
	b.add(home, gameplay, "SeaRegionCastaway")
	var islet := SeaRegion.new()
	islet.region_name = "Driftwood Key"
	islet.island_id = ISLET
	islet.radius = 36.0
	islet.position = L.DRIFTWOOD
	islet.boat_dock = gameplay.get_node("DriftwoodKey/BoatLanding")
	var islet_arrival := Marker3D.new()
	islet_arrival.position = L.DRIFTWOOD + Vector3(12.0, 1.3, -24.0)
	islet_arrival.rotation_degrees.y = 200.0
	b.add(islet_arrival, gameplay, "DriftwoodArrival")
	islet.arrival = islet_arrival
	b.add(islet, gameplay, "SeaRegionDriftwood")
	var zone := IslandZone.new()
	zone.island_id = ISLAND
	zone.display_name = "Castaway Cay"
	zone.announce = false
	zone.size = Vector3(420, 120, 320)
	zone.position = Vector3(-6, 30, -14)
	b.add(zone, gameplay, "IslandZoneCastaway")


func _checkpoints() -> void:
	for d: Array in [["cp_shore", Vector3(84, SAND, 92), 0.0], ["cp_village", Vector3(-112, LOW, 36), 0.0],
			["cp_bluff", Vector3(-100, BLUFF, -38.5), 0.0], ["cp_woods", Vector3(-92, HIGH, -72), 0.0], ["cp_falls", Vector3(8, HIGH, -38), 0.0],
			["cp_shelf", Vector3(14, SHELF, -54), 0.0], ["cp_summit", Vector3(6, SUMMIT, -78), 0.0], ["cp_downs", Vector3(124, DOWNS, 20), 270.0]]:
		_checkpoint(gameplay, d[0], d[1], d[2], String(d[0]).capitalize().replace(" ", ""))
	for spot: Array in [["Shore", L.WASHED_UP], ["Wreck", Vector3(104, 1.3, 92)], ["Village", Vector3(-112, LOW + 0.1, 36)],
			["Shipyard", Vector3(-55, 1.3, 82)], ["Pier", Vector3(-100, QUAY + 0.1, 84)], ["Bluff", Vector3(-100, BLUFF + 0.1, -38.5)],
			["Woods", Vector3(-92, HIGH + 0.1, -72)], ["GiantTree", L.GIANT_TREE + Vector3(8, 0.1, 6)], ["Cave", Vector3(-148, HIGH + 0.1, -92)],
			["Falls", Vector3(12, LOW + 0.1, -22)], ["Shelf", Vector3(14, SHELF + 0.1, -54)], ["Summit", Vector3(6, SUMMIT + 0.1, -78)],
			["Fort", Vector3(86, FORT + 0.1, -84)], ["Downs", Vector3(124, DOWNS + 0.1, 20)], ["NorthBeach", Vector3(-20, 1.3, -130)],
			["GullRock", Vector3(-188.5, 5.5, 13)]]:
		var m := Marker3D.new()
		m.position = spot[1]
		b.add(m, gameplay, "Teleport" + String(spot[0]))
		m.add_to_group(&"debug_teleport", true)


func _hints() -> void:
	var g := b.group("Hints", gameplay)
	for d: Array in [
			["hint_jump", Vector3(86, SAND, 94), Vector3(16, 4, 12), "{jump} Jump - hold it to jump higher", &"", &""],
			["hint_dive", Vector3(70, SAND, 84), Vector3(12, 4, 10), "While running, {dive} to dive  ·  {jump} to roll out", &"", &""],
			["hint_swipe", Vector3(-2, LOW, 34), Vector3(14, 4, 12), "{attack} Hook swipe  ·  armored crabs need a ground pound", &"", &""],
			["hint_ledge", Vector3(12, LOW, -25), Vector3(8, 4, 6), "Jump at a ledge to grab it  ·  {jump} to climb up", &"", &""],
			["hint_wall_kick", Vector3(6.1, SHELF, -52.5), Vector3(4, 4, 4), "Slide down a wall and press {jump} to wall-kick", &"", &""],
			["hint_long_jump", Vector3(119.5, 8.0, 98), Vector3(4, 3, 4), "Long jump: run, hold {crouch} and press {jump}", &"", &""],
			["hint_ground_pound", L.FORT_YARD, Vector3(14, 4, 14), "In the air, press {ground_pound} to ground pound", &"", &""],
			["hint_ring", Vector3(1, 4.5, 79), Vector3(7, 3, 7), "Jump at a golden ring and press {tool_primary} to swing", &"", &""],
			["hint_boat", Vector3(-100, QUAY, 84), Vector3(6, 3, 10), "{interact} Board the boat  ·  steer with the stick, {jump} to hop out", &"", DINGHY],
			["hint_tools", _c(Vector3(11, 7.0, -36)), Vector3(8, 4, 6), "Swap hand attachments with {tool_previous} / {tool_next}", &"shovel", &""]]:
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
	var k := 0
	# Palms along the beaches leaning seaward, round the village and on the
	# downs; broadleaf groves on the meadow and the terraces.
	for d: Array in [
			[Vector3(66, SAND, 80), 7.5, 18.0, 160.0], [Vector3(74, SAND, 108), 6.5, 22.0, 200.0], [Vector3(100, SAND, 112), 8.0, 14.0, 180.0],
			[Vector3(134, SAND, 84), 7.0, 20.0, 130.0], [Vector3(150, SAND, 60), 8.5, 16.0, 110.0], [Vector3(58, SAND, 96), 6.0, 12.0, 190.0],
			[Vector3(30, SAND, 84), 7.5, 18.0, 170.0], [Vector3(10, SAND, 70), 6.5, 20.0, 190.0], [Vector3(-12, SAND, 64), 7.0, 16.0, 200.0],
			[Vector3(-26, SAND, 72), 6.0, 22.0, 220.0], [Vector3(-48, SAND, 104), 7.0, 18.0, 180.0], [Vector3(-38, SAND, 66), 6.5, 14.0, 150.0],
			[Vector3(-150, SAND, 108), 7.0, 18.0, 200.0], [Vector3(-160, SAND, 90), 8.0, 14.0, 240.0], [Vector3(-186, SAND, 60), 7.0, 20.0, 260.0],
			[Vector3(-192, SAND, 36), 6.5, 16.0, 270.0], [Vector3(-186, SAND, -10), 7.5, 20.0, 280.0], [Vector3(-182, SAND, -42), 6.0, 18.0, 290.0],
			[Vector3(-60, SAND, -130), 7.0, 18.0, 0.0], [Vector3(-30, SAND, -134), 6.5, 20.0, 350.0], [Vector3(40, SAND, -132), 7.5, 16.0, 10.0],
			[Vector3(58, SAND, -128), 6.0, 22.0, 20.0], [Vector3(-140, LOW, 48), 7.0, 10.0, 30.0], [Vector3(-100, LOW, 52), 6.5, 12.0, -20.0],
			[Vector3(-160, MID, 4), 7.0, 8.0, 0.0], [Vector3(-82, MID, 14), 6.5, 10.0, 60.0], [Vector3(-160, TERRACE, -32), 6.5, 10.0, 90.0],
			[Vector3(-120, BLUFF, -54), 6.0, 10.0, 90.0], [Vector3(130, DOWNS, -20), 7.5, 12.0, 0.0], [Vector3(176, DOWNS, -30), 6.5, 16.0, -90.0],
			[Vector3(172, DOWNS, 20), 7.0, 14.0, -100.0], [Vector3(118, FORT, -136), 7.0, 16.0, 0.0], [Vector3(170, FORT, -80), 6.5, 18.0, -90.0],
			[Vector3(-30, LOW, 22), 7.5, 8.0, 30.0], [Vector3(100, LOW, 40), 7.0, 10.0, -60.0], [Vector3(54, LOW, -24), 6.5, 12.0, 0.0]]:
		k += 1
		palm(nature, d[0], d[1], d[2], d[3], k * 7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for grove: Array in [[Vector2(-44, 8), 4, LOW], [Vector2(-10, -10), 3, LOW], [Vector2(62, -14), 4, LOW], [Vector2(86, 30), 3, LOW],
			[Vector2(-64, -24), 3, LOW], [Vector2(-90, 0), 2, MID], [Vector2(-120, -24), 2, TERRACE],
			[Vector2(140, 20), 3, DOWNS], [Vector2(160, -50), 3, DOWNS], [Vector2(40, -40), 3, HIGH], [Vector2(-20, -42), 2, HIGH],
			[Vector2(30, -96), 3, SHELF], [Vector2(-20, -100), 2, SHELF], [Vector2(165, -100), 3, FORT], [Vector2(92, -120), 3, FORT]]:
		var center: Vector2 = grove[0]
		for i in int(grove[1]):
			var p := center + Vector2(rng.randf_range(-7, 7), rng.randf_range(-7, 7))
			k += 1
			tree(nature, Vector3(p.x, float(grove[2]), p.y), rng.randf_range(6.0, 9.5), rng.randf_range(2.4, 3.4), [0, 0, 1, 2][rng.randi() % 4], k * 13)
	# Rocks: cliff-foot clusters, beach boulders, a few in the shallows.
	var rk := 0
	for d: Array in [
			[Vector3(60, SAND, 70), Vector3(2.4, 1.6, 2.0), StylizedRock.Preset.SAND_ROCK], [Vector3(62, SAND, 72.5), Vector3(1.2, 0.8, 1.1), StylizedRock.Preset.SAND_ROCK],
			[Vector3(112, SAND, 64), Vector3(2.6, 1.8, 2.2), StylizedRock.Preset.CLIFF_ROCK], [Vector3(150, 0.2, 98), Vector3(2.0, 1.6, 1.8), StylizedRock.Preset.DARK_ROCK],
			[Vector3(158, 0.2, 90), Vector3(1.6, 1.2, 1.4), StylizedRock.Preset.DARK_ROCK], [Vector3(-196, 0.2, 70), Vector3(2.4, 1.8, 2.2), StylizedRock.Preset.DARK_ROCK],
			[Vector3(-20, LOW, 30), Vector3(1.0, 0.7, 0.9), StylizedRock.Preset.CLIFF_ROCK], [Vector3(-60, HIGH, -80), Vector3(1.6, 1.0, 1.4), StylizedRock.Preset.MOSSY],
			[Vector3(-170, HIGH, -80), Vector3(2.2, 1.4, 2.0), StylizedRock.Preset.MOSSY], [Vector3(182, DOWNS, -40), Vector3(2.2, 1.5, 2.0), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(-50, SAND, -128), Vector3(2.0, 1.4, 1.8), StylizedRock.Preset.SAND_ROCK], [Vector3(30, SAND, -136), Vector3(1.6, 1.1, 1.4), StylizedRock.Preset.DARK_ROCK],
			[Vector3(176, 0.2, 40), Vector3(2.4, 1.6, 2.2), StylizedRock.Preset.DARK_ROCK], [Vector3(186, 0.2, 30), Vector3(1.6, 1.2, 1.4), StylizedRock.Preset.DARK_ROCK],
			[Vector3(20, HIGH, -40), Vector3(1.4, 1.0, 1.2), StylizedRock.Preset.MOSSY], [Vector3(50, HIGH, -60), Vector3(2.0, 1.4, 1.8), StylizedRock.Preset.CLIFF_ROCK],
			[Vector3(-130, MID, 16), Vector3(1.2, 0.8, 1.0), StylizedRock.Preset.CLIFF_ROCK], [Vector3(-44, LOW, -36), Vector3(2.0, 1.2, 1.8), StylizedRock.Preset.MOSSY]]:
		rk += 1
		rock(nature, d[0], d[1], d[2], rk * 11, rk * 37.0)
	# Grass, flowers and bushes on every grassy top; ferns in the woods;
	# pebbles on the sand.
	var grass_only: Array[StringName] = [&"grass"]
	var sand_only: Array[StringName] = [&"sand"]
	for area: Array in [[Vector3(-30, 30, 0), Vector2(310, 140), 3], [Vector3(-60, 30, -82), Vector2(260, 90), 13], [Vector3(125, 30, -50), Vector2(140, 200), 23]]:
		var sc := scatter(nature, area[0], area[1], PropScatter.Kind.GRASS, 0.3, grass_only, area[2], 9000)
		sc.ray_height = 40.0
		sc.ray_depth = 40.0
		var fl := scatter(nature, area[0], area[1], PropScatter.Kind.FLOWERS, 0.025, grass_only, area[2] + 2, 900)
		fl.ray_height = 40.0
		fl.ray_depth = 40.0
		var bu := scatter(nature, area[0], area[1], PropScatter.Kind.BUSHES, 0.004, grass_only, area[2] + 4, 160)
		bu.ray_height = 40.0
		bu.ray_depth = 40.0
	var fe := scatter(nature, Vector3(-115, 30, -92), Vector2(140, 56), PropScatter.Kind.FERNS, 0.05, grass_only, 9, 500)
	fe.ray_height = 40.0
	fe.ray_depth = 40.0
	var pb := scatter(nature, Vector3(0, 30, 0), Vector2(400, 300), PropScatter.Kind.PEBBLES, 0.006, sand_only, 11, 900)
	pb.ray_height = 40.0
	pb.ray_depth = 40.0


func _opening() -> void:
	var seq := OpeningSequence.new()
	b.add(seq, null, "OpeningSequence")
	# Out to sea off Wreck Shore: the Jolly Patch sails in toward the island
	# and the storm catches her.
	var stage := Marker3D.new()
	stage.position = Vector3(232, 0, 212)
	stage.rotation.y = Player.yaw_of(Vector3(-132, 0, -102))
	b.add(stage, seq, "SeaStage")
	seq.sea_stage = stage
	# The crabs' road with Patchy's sea chest: up the beach, the meadow
	# ramp and off toward the old fort.
	seq.chest_route = PackedVector3Array([L.WASHED_UP + Vector3(3.0, -0.05, 1.8), Vector3(94.5, SAND, 73.5), Vector3(96, SAND - 0.05, 69.0),
		Vector3(96, LOW, 59.6), Vector3(99, LOW, 47), Vector3(106, LOW, 34)])
	var w := L.WASHED_UP
	seq.crab_dragging = crab(w + Vector3(5, 0, -1.5), CrabModel.Variant.NORMAL, "", gameplay.get_node("CoveBurrow"))
	seq.crab_noticing = crab(w + Vector3(-3.5, 0, -2.5), CrabModel.Variant.NORMAL, "", gameplay.get_node("CoveBurrow"))
	seq.crab_dragging.dormant = true
	seq.crab_noticing.dormant = true
