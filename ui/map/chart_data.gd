class_name UIChartData
## The archipelago as drawn on the pause-menu sea chart, plus the island id ->
## scene mapping the title screen uses for "Continue".
##
## pos:    chart position, normalized (0..1 on both axes of the chart area)
## size:   island radius as a fraction of the chart height
## motif:  little doodle drawn on the island (palm, crab, cannon, lantern,
##         skull, turtle, wreck)
## seed:   coastline shape seed
## scene:  level scene to load for this island
## totals: optional known collectible totals {treasure, maps, ship_parts};
##         leave a key out to show "?" in the collection screen. Levels can
##         also register totals at runtime with UI.set_island_totals().

const ISLANDS := [
	{
		"id": &"castaway_cay", "name": "Castaway Cay", "pos": Vector2(0.44, 0.47), "size": 0.085,
		"motif": &"palm", "seed": 3, "scene": "res://world/islands/castaway_cay/castaway_cay.tscn",
		"totals": {},
	},
	{
		"id": &"crabby_coast", "name": "Crabby Coast", "pos": Vector2(0.2, 0.76), "size": 0.09,
		"motif": &"crab", "seed": 11, "scene": "res://world/islands/crabby_coast/crabby_coast.tscn",
		"totals": {},
	},
	{
		"id": &"cannonball_cliffs", "name": "Cannonball Cliffs", "pos": Vector2(0.74, 0.33), "size": 0.09,
		"motif": &"cannon", "seed": 27, "scene": "res://world/islands/cannonball_cliffs/cannonball_cliffs.tscn",
		"totals": {},
	},
	{
		"id": &"lantern_lagoon", "name": "Lantern Lagoon", "pos": Vector2(0.16, 0.42), "size": 0.085,
		"motif": &"lantern", "seed": 41, "scene": "res://world/islands/lantern_lagoon/lantern_lagoon.tscn",
		"totals": {},
	},
	{
		"id": &"skullcap_mountain", "name": "Skullcap Mountain", "pos": Vector2(0.52, 0.13), "size": 0.09,
		"motif": &"skull", "seed": 53, "scene": "res://world/islands/skullcap_mountain/skullcap_mountain.tscn",
		"totals": {},
	},
	{
		"id": &"turtleback", "name": "Turtleback", "pos": Vector2(0.7, 0.7), "size": 0.075,
		"motif": &"turtle", "seed": 67, "scene": "res://world/islands/turtleback/turtleback.tscn",
		"totals": {},
	},
	{
		"id": &"shipwreck_shoals", "name": "Shipwreck Shoals", "pos": Vector2(0.45, 0.82), "size": 0.07,
		"motif": &"wreck", "seed": 79, "scene": "res://world/islands/shipwreck_shoals/shipwreck_shoals.tscn",
		"totals": {},
	},
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


static func display_name(id: StringName) -> String:
	var i := get_island(id)
	return String(i.get("name", String(id).capitalize()))


## Scene for an island, or "" when unknown / not built yet.
static func scene_for(id: StringName) -> String:
	var path := String(get_island(id).get("scene", ""))
	if path != "" and ResourceLoader.exists(path):
		return path
	return ""
