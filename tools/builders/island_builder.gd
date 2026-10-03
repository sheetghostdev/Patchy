class_name IslandBuilder
extends RefCounted
## Shared kit for the island scene builders (tools/builders/build_*.gd):
## terrain plateaus and level blocks, coins, gems, hearts, crabs, cages and
## props, plus the scaffolding every island scene in the archipelago needs
## (docs/ARCHIPELAGO.md): sky and weather, the ocean, its waters and the
## voyage out, the boat, the horizon, Patchy and his camera.

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

## Starts an island scene: its IslandInfo, sky, ambience, weather, and the
## usual groups, all under `root` (the island's own frame: Archipelago
## position, facing Castaway Cay) when given.
func begin(scene_name: String, id: StringName, display: String, music: StringName, root: Node3D = null) -> IslandInfo:
	island_id = id
	b = SceneBuilder.new(scene_name)
	var info := IslandInfo.new()
	info.island_id = id
	info.display_name = display
	info.music = music
	b.add(info, null, "IslandInfo")
	var env := SkyEnvironment.new()
	env.preset = SkyEnvironment.Preset.CASTAWAY_DAY
	env.shadow_distance = 160.0
	b.add(env, null, "SkyEnvironment")
	b.add(Ambience.new(), null, "Ambience")
	b.add(Weather.new(), null, "Weather")
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


## The sea round the island: swimmable ocean, sandy seabed, the open-sea
## current beyond its waters, and the voyage out to the other islands.
func open_sea(center: Vector3, size: float = 380.0) -> void:
	var ocean := Ocean.new()
	ocean.position = Vector3(center.x, 0.0, center.z)
	ocean.swim_area_size = Vector2(size, size)
	ocean.swim_depth = 14.0
	ocean.gameplay_wave_scale = 0.6
	b.add(ocean, null, "Ocean")
	b.add(UnderwaterEffect.new(), null, "UnderwaterEffect")
	var bed := LevelBlock.new()
	bed.size = Vector3(size, 1, size)
	bed.surface = "sand"
	bed.position = Vector3(center.x, -11.0, center.z)
	b.add(bed, null, "Seabed")
	b.add(OpenSea.new(), null, "OpenSea")
	var voyage := Voyage.new()
	voyage.home = island_id
	b.add(voyage, null, "Voyage")


## The island's waters (where Patchy can hop out of the boat and the
## open-sea current doesn't reach), its mooring and landing point.
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


## Patchy's boat moored at `dock`, kept within `limit` m of the island.
func boat(parent: Node, dock: Marker3D, limit: float) -> TinyBoat:
	var boat := TinyBoat.new()
	boat.home_island = island_id
	boat.limit_center = Archipelago.world_position(island_id)
	boat.world_limit = limit
	boat.position = dock.position
	boat.rotation = dock.rotation
	b.add(boat, parent, "TinyBoat")
	return boat


## Every other island's silhouette, in its place on the horizon.
func horizon(skip: Array[StringName]) -> void:
	var g := b.group("Horizon")
	for id in Archipelago.ids():
		if id in skip:
			continue
		var isl := Archipelago.make_horizon(id)
		if isl != null:
			b.add(isl, g, isl.name)


## Patchy and his camera at `pos` (world), facing `face`, plus a "dock"
## spawn point there for scene changes that ask for one.
func spawn(pos: Vector3, face: Vector3) -> Node3D:
	var yaw := rad_to_deg(Player.yaw_of(face))
	var player := b.instance(PLAYER, null, pos, yaw, "Player")
	var rig := b.instance(RIG, null, pos + Vector3(0, 3, 0) - face.normalized() * 7.0, yaw, "CameraRig")
	rig.set(&"target", player)
	var dock := Marker3D.new()
	dock.position = pos
	dock.rotation.y = Player.yaw_of(face)
	dock.set_meta(&"spawn_id", &"dock")
	b.add(dock, null, "SpawnDock")
	dock.add_to_group(&"spawn_point", true)
	return player


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
