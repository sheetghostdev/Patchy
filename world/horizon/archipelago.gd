class_name Archipelago
## Where every island of Patchy's sea lies (docs/ARCHIPELAGO.md). World x/z
## in meters, with Castaway Cay at the origin and north toward -Z. Every
## island sits in the one world (world/sea/world.tscn): the built ones as
## chunks the WorldDirector wakes as Patchy nears them, and every island as
## a silhouette (HorizonIsland) for when it's far off, turned to face
## Castaway Cay (plus "turn" degrees for the ones that read best side-on)
## and drawn up to "scale" times life size far out at sea, where a small
## island would otherwise vanish (Wind Waker's trick). "waters" is how far
## an island's own sea reaches (when its chunk wakes). "gate" names what
## keeps the boat out of an island's waters until the ship's ready (sea
## hazards, still to come). The sea chart (UIChartData) draws them on the
## same bearings.

const ISLANDS := [
	{"id": &"castaway_cay", "at": Vector2(0, 0), "waters": 250.0, "horizon": "res://world/horizon/horizon_castaway.gd"},
	{"id": &"driftwood_key", "at": Vector2(-130, 140), "horizon": ""},
	{"id": &"skullcap_mountain", "gate": &"jolly_patch", "at": Vector2(113, -640), "horizon": "res://world/horizon/horizon_skullcap.gd"},
	{"id": &"cinder_isle", "gate": &"ship_cannons", "at": Vector2(643, -766), "horizon": "res://world/horizon/horizon_cinder_isle.gd"},
	{"id": &"cannonball_cliffs", "gate": &"jolly_patch", "at": Vector2(545, -198), "horizon": "res://world/horizon/horizon_cannon_cliffs.gd"},
	{"id": &"teacup_isle", "at": Vector2(436, 176), "scale": 1.6, "horizon": "res://world/horizon/horizon_teacup_isle.gd"},
	{"id": &"stormpeak", "gate": &"iron_hull", "at": Vector2(1067, 266), "horizon": "res://world/horizon/horizon_stormpeak.gd"},
	{"id": &"turtleback", "at": Vector2(416, 375), "turn": 55.0, "scale": 1.35, "horizon": "res://world/horizon/horizon_turtleback.gd"},
	{"id": &"bell_atoll", "at": Vector2(171, 470), "scale": 2.0, "horizon": "res://world/horizon/horizon_bell_atoll.gd"},
	{"id": &"shipwreck_shoals", "at": Vector2(-61, 577), "scale": 1.3, "horizon": "res://world/horizon/horizon_wreck_shoals.gd"},
	{"id": &"crabby_coast", "at": Vector2(-367, 524), "horizon": "res://world/horizon/horizon_crabby_coast.gd"},
	{"id": &"lantern_lagoon", "at": Vector2(-560, -20), "horizon": "res://world/horizon/horizon_lantern_lagoon.gd"},
	{"id": &"pinwheel_isle", "at": Vector2(-433, -250), "scale": 1.7, "horizon": "res://world/horizon/horizon_pinwheel_isle.gd"},
	{"id": &"crocodile_crown", "gate": &"full_ship", "at": Vector2(-834, -863), "turn": -65.0, "scale": 1.25, "horizon": "res://world/horizon/horizon_croc_crown.gd"},
	{"id": &"hat_rock", "at": Vector2(-124, -464), "horizon": "res://world/horizon/horizon_hat_rock.gd"},
]


static func ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for i: Dictionary in ISLANDS:
		out.append(i["id"])
	return out


static func get_island(id: StringName) -> Dictionary:
	for i: Dictionary in ISLANDS:
		if i["id"] == id:
			return i
	return {}


## The island's center at sea level.
static func world_position(id: StringName) -> Vector3:
	var at: Vector2 = get_island(id).get("at", Vector2.ZERO)
	return Vector3(at.x, 0.0, at.y)


## How far an island's own waters reach (m).
static func waters(id: StringName) -> float:
	return float(get_island(id).get("waters", 140.0))


## Compass bearing from `from` (degrees clockwise from north, 0..360).
static func bearing(from: Vector3, to: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(to.x - from.x, -(to.z - from.z))), 360.0)


## A silhouette of the island, placed and turned to face Castaway Cay, or
## null if it has none (the islands built for real, like Castaway Cay).
static func make_horizon(id: StringName) -> HorizonIsland:
	var path := String(get_island(id).get("horizon", ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var isl := (load(path) as GDScript).new() as HorizonIsland
	isl.name = "Horizon_%s" % String(id).to_pascal_case()
	isl.position = world_position(id)
	isl.rotation.y = Player.yaw_of(-isl.position) + deg_to_rad(float(get_island(id).get("turn", 0.0)))
	isl.scale = Vector3.ONE * float(get_island(id).get("scale", 1.0))
	isl.set_meta(&"island_id", id)
	isl.add_to_group(&"horizon_island", true)
	return isl


## Adds every island's silhouette under `parent`, except those in `skip`
## (the ones the scene builds for real).
static func add_horizon(parent: Node, skip: Array[StringName] = []) -> Array[HorizonIsland]:
	var out: Array[HorizonIsland] = []
	for id in ids():
		if id in skip:
			continue
		var isl := make_horizon(id)
		if isl != null:
			parent.add_child(isl)
			out.append(isl)
	return out
