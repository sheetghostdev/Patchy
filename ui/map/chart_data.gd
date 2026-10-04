class_name UIChartData
## The archipelago as drawn on the pause-menu sea chart, plus the island id ->
## scene mapping the title screen uses for "Continue".
##
## The chart doesn't store positions: each island is drawn on its real
## bearing from Castaway Cay (Archipelago), with distances squeezed so the
## far isles still fit on the parchment (chart_offset()).
## size:   island radius as a fraction of the chart height
## motif:  little doodle drawn on the island (palm, crab, cannon, lantern,
##         skull, turtle, wreck, hat, bell, pinwheel, teacup, volcano,
##         storm, crown)
## seed:   coastline shape seed
## label:  &"above", &"left" or &"right" to move the name off a crowded spot
## scene:  level scene to load for this island
## totals: optional known collectible totals {treasure, maps, ship_parts};
##         leave a key out to show "?" in the collection screen. Levels can
##         also register totals at runtime with UI.set_island_totals().

const ISLANDS := [
	{"id": &"castaway_cay", "name": "Castaway Cay", "size": 0.08, "motif": &"palm", "seed": 3,
		"scene": "res://world/sea/world.tscn", "totals": {}},
	{"id": &"driftwood_key", "name": "Driftwood Key", "size": 0.034, "motif": &"palm", "seed": 5,
		"scene": "res://world/sea/world.tscn", "totals": {}},
	{"id": &"hat_rock", "name": "Hat Rock", "size": 0.034, "motif": &"hat", "seed": 91, "label": &"above",
		"scene": "res://world/sea/world.tscn", "totals": {}},
	{"id": &"bell_atoll", "name": "Bell Atoll", "size": 0.036, "motif": &"bell", "seed": 93,
		"scene": "res://world/sea/world.tscn", "totals": {}},
	{"id": &"pinwheel_isle", "name": "Pinwheel Isle", "size": 0.034, "motif": &"pinwheel", "seed": 95, "label": &"right",
		"scene": "res://world/sea/world.tscn", "totals": {}},
	{"id": &"teacup_isle", "name": "Teacup Isle", "size": 0.034, "motif": &"teacup", "seed": 97, "label": &"right",
		"scene": "res://world/sea/world.tscn", "totals": {}},
	{"id": &"crabby_coast", "name": "Crabby Coast", "size": 0.07, "motif": &"crab", "seed": 11, "label": &"left", "scene": "", "totals": {}},
	{"id": &"lantern_lagoon", "name": "Lantern Lagoon", "size": 0.066, "motif": &"lantern", "seed": 41, "scene": "", "totals": {}},
	{"id": &"shipwreck_shoals", "name": "Shipwreck Shoals", "size": 0.06, "motif": &"wreck", "seed": 79, "scene": "", "totals": {}},
	{"id": &"turtleback", "name": "Turtleback", "size": 0.058, "motif": &"turtle", "seed": 67, "scene": "", "totals": {}},
	{"id": &"skullcap_mountain", "name": "Skullcap Mountain", "size": 0.07, "motif": &"skull", "seed": 53, "scene": "", "totals": {}},
	{"id": &"cannonball_cliffs", "name": "Cannonball Cliffs", "size": 0.062, "motif": &"cannon", "seed": 27, "scene": "", "totals": {}},
	{"id": &"cinder_isle", "name": "Cinder Isle", "size": 0.07, "motif": &"volcano", "seed": 101, "scene": "", "totals": {}},
	{"id": &"stormpeak", "name": "Stormpeak", "size": 0.06, "motif": &"storm", "seed": 103, "scene": "", "totals": {}},
	{"id": &"crocodile_crown", "name": "Crocodile Crown", "size": 0.072, "motif": &"crown", "seed": 107, "scene": "", "totals": {}},
]

## How far the farthest isle sits from Castaway Cay (m), and how far that
## is drawn on the chart (fraction of its height).
const FAR := 1250.0
const FAR_ON_CHART := 0.43
## The chart is wider than tall: spread the islands out sideways a little.
const STRETCH_X := 1.9


## Where an island goes on the chart, relative to Castaway Cay, in chart
## heights: its true bearing, its distance squeezed (near isles keep their
## room, far ones still fit).
static func chart_offset(id: StringName) -> Vector2:
	var w := Archipelago.world_position(id)
	var flat := Vector2(w.x, w.z)
	var d := flat.length()
	if d < 0.001:
		return Vector2.ZERO
	var r := FAR_ON_CHART * pow(minf(d / FAR, 1.0), 0.55)
	var dir := flat / d
	return Vector2(dir.x * r * STRETCH_X, dir.y * r)


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
