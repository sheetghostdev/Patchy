extends IslandBuilder
## Generates res://world/sea/world.tscn: the one sea (docs/ARCHIPELAGO.md).
## Every island of the archipelago in its place, joined by open water you
## can sail (or swim) across, no walls and no scene changes:
##  - The sky, the weather, and one ocean over the whole chart, with a deep
##    sea floor under it (each island brings its own sandy shelf).
##  - Every built island as a chunk (its own scene, instanced in place),
##    and every island's silhouette for when it's far off (WorldDirector
##    swaps between them and keeps the far islands asleep).
##  - Sea mist round the islands still to be built, and the fog at the edge
##    of the chart that turns a boat round.
##  - Patchy washed up on Castaway Cay's beach, his camera, and the boat at
##    Barnacle Bay's pier (his once Gus has fixed it up).
##   tools/builders/build.sh castaway_cay hat_rock ... world  (islands first)

const OUT := "res://world/sea/world.tscn"
## The islands built so far, by Archipelago id.
const CHUNKS := {
	&"castaway_cay": "res://world/islands/castaway_cay/castaway_cay.tscn",
	&"hat_rock": "res://world/islands/hat_rock/hat_rock.tscn",
	&"bell_atoll": "res://world/islands/bell_atoll/bell_atoll.tscn",
	&"pinwheel_isle": "res://world/islands/pinwheel_isle/pinwheel_isle.tscn",
	&"teacup_isle": "res://world/islands/teacup_isle/teacup_isle.tscn",
}
## Islands that live inside another's chunk (no silhouette, no mist).
const PART_OF := {&"driftwood_key": &"castaway_cay"}
## The middle of the archipelago, and how far from it the chart ends.
const CENTER := Vector3(116, 0, -143)
const EDGE := 1500.0
## Where Patchy wakes up on Castaway Cay's beach, and the boat's mooring
## at the end of Barnacle Bay's pier (build_castaway_cay.gd). The boat is
## Gus's old dinghy: not Patchy's until Gus has fixed it up.
const WASHED_UP := Vector3(0, 1.25, 33)
const BOAT_AT := Vector3(-44.6, 0, 58)


func build() -> void:
	seed(20261007)
	b = SceneBuilder.new("World")
	b.add(WorldDirector.new(), null, "WorldDirector")
	_sky()
	_sea()
	_islands()
	_horizon()
	_mist()
	_patchy()
	b.save(OUT)


func _sky() -> void:
	var env := SkyEnvironment.new()
	env.preset = SkyEnvironment.Preset.CASTAWAY_DAY
	env.shadow_distance = 160.0
	b.add(env, null, "SkyEnvironment")
	b.add(Ambience.new(), null, "Ambience")
	b.add(Weather.new(), null, "Weather")


## One ocean over the whole chart: swimmable everywhere, deep between the
## islands, and the fog at its edge.
func _sea() -> void:
	var size := (EDGE + 250.0) * 2.0
	var ocean := Ocean.new()
	ocean.position = CENTER
	ocean.swim_area_size = Vector2(size, size)
	ocean.swim_depth = 60.0
	# Gentler bob for swimming than the drawn waves (readable platforming).
	ocean.gameplay_wave_scale = 0.6
	b.add(ocean, null, "Ocean")
	b.add(UnderwaterEffect.new(), null, "UnderwaterEffect")
	var floor_block := LevelBlock.new()
	floor_block.size = Vector3(size, 1, size)
	floor_block.surface = "sand"
	floor_block.position = CENTER + Vector3.DOWN * 45.0
	b.add(floor_block, null, "SeaFloor")
	var edge := SeaEdge.new()
	edge.position = CENTER
	edge.radius = EDGE
	b.add(edge, null, "SeaEdge")


func _islands() -> void:
	var g := b.group("Islands")
	for id: StringName in CHUNKS:
		b.instance(CHUNKS[id], g, Vector3.ZERO, 0.0, String(id).to_pascal_case())


## Every island's silhouette: the unbuilt ones always, the built ones for
## when they're far off and asleep.
func _horizon() -> void:
	var g := b.group("Horizon")
	for id in Archipelago.ids():
		var isl := Archipelago.make_horizon(id)
		if isl != null:
			b.add(isl, g, isl.name)


func _mist() -> void:
	var g := b.group("Mist")
	for id in Archipelago.ids():
		if CHUNKS.has(id) or PART_OF.has(id):
			continue
		var mist := MistBank.new()
		mist.island_id = id
		mist.position = Archipelago.world_position(id)
		b.add(mist, g, "Mist_%s" % String(id).to_pascal_case())


func _patchy() -> void:
	var player := b.instance(PLAYER, null, WASHED_UP, 0.0, "Player")
	var rig := b.instance(RIG, null, WASHED_UP + Vector3(0, 1.75, 7), 0.0, "CameraRig")
	rig.set(&"target", player)
	var boat := TinyBoat.new()
	boat.position = BOAT_AT
	boat.rotation.y = PI
	boat.unlock_flag = &"castaway_dinghy"
	b.add(boat, null, "TinyBoat")
