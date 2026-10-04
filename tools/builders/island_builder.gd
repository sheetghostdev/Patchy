class_name IslandBuilder
extends RefCounted
## Shared kit for the island scene builders (tools/builders/build_*.gd):
## terrain plateaus and level blocks, coins, gems, hearts, crabs, cages and
## props, plus the scaffolding every island of the archipelago needs
## (docs/ARCHIPELAGO.md). An island scene is a chunk of the one sea
## (world/sea/world.tscn, tools/builders/build_world.gd): just the island,
## built in place at its Archipelago position, with its waters (SeaRegion),
## mooring and a sandy seabed round it. The sky, the ocean, the boat,
## Patchy and the other islands are the world's.

const PLAYER := "res://characters/patchy/player.tscn"
const RIG := "res://systems/camera/camera_rig.tscn"
const CRAB := "res://enemies/crab/crab.tscn"

var b: SceneBuilder
## The island the scene is built for: gems and cages count toward it.
var island_id: StringName = &""
var terrain: Node3D
var structures: Node3D
var gameplay: Node3D
var treasure: Node3D
var enemies: Node3D


# --- Scaffolding (islands of the archipelago) --------------------------------------

## Starts an island chunk: its IslandInfo and the usual groups, all under
## `root` (the island's own frame: Archipelago position, facing Castaway
## Cay) when given.
func begin(scene_name: String, id: StringName, display: String, music: StringName, root: Node3D = null) -> IslandInfo:
	island_id = id
	b = SceneBuilder.new(scene_name)
	var info := IslandInfo.new()
	info.island_id = id
	info.display_name = display
	info.music = music
	b.add(info, null, "IslandInfo")
	if root != null:
		b.add(root, null, root.name)
	terrain = b.group("Terrain", root)
	structures = b.group("Structures", root)
	gameplay = b.group("Gameplay", root)
	treasure = b.group("Treasure", root)
	enemies = b.group("Enemies", root)
	return info


## The island's frame: a node at its Archipelago position, turned to face
## Castaway Cay like its silhouette on every other horizon.
func island_root(id: StringName, node_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = Archipelago.world_position(id)
	root.rotation.y = Player.yaw_of(-root.position) if root.position.length() > 0.1 else 0.0
	return root


## Sandy seabed round the island (world `center`), 11 m down, shelving off
## to the deep sea floor beyond: the shallows shade consistently and
## there's a bottom to dive to.
func seabed(center: Vector3, size: float = 380.0) -> void:
	var bed := LevelBlock.new()
	bed.size = Vector3(size, 1, size)
	bed.surface = "sand"
	bed.position = Vector3(center.x, -11.0, center.z)
	b.add(bed, null, "Seabed")


## The island's waters (where it's the current island and Patchy can hop
## out of the boat), its mooring and landing point.
func waters(parent: Node, center: Vector3, radius: float, dock: Marker3D, arrival: Marker3D, region_name: String) -> SeaRegion:
	var region := SeaRegion.new()
	region.region_name = region_name
	region.island_id = island_id
	region.radius = radius
	region.position = center
	region.boat_dock = dock
	region.arrival = arrival
	b.add(region, parent, "SeaRegion")
	return region


# --- Pieces -------------------------------------------------------------------------

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
	c.island_id = island_id
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
	c.island_id = island_id
	c.plumage = plumage
	c.hanging = hanging
	c.position = pos
	b.add(c, gameplay, "ParrotCage_" + id)
	return c


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
