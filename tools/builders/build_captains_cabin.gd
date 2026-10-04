extends RefCounted
## Generates res://world/hub/captains_cabin.tscn: the captain's cabin aboard
## the wreck of the Patchy, the hub where progress is on display.
##   tools/builders/build.sh captains_cabin

const PLAYER := "res://characters/patchy/player.tscn"
const RIG := "res://systems/camera/camera_rig.tscn"
const WORLD := "res://world/sea/world.tscn"

var b: SceneBuilder


func build() -> void:
	b = SceneBuilder.new("CaptainsCabin")
	var info := IslandInfo.new()
	info.island_id = &"captains_cabin"
	info.display_name = "Captain's Cabin"
	info.music = &"cave_explore"
	info.announce = false
	b.add(info, null, "IslandInfo")
	var env := SkyEnvironment.new()
	env.preset = SkyEnvironment.Preset.INTERIOR
	b.add(env, null, "SkyEnvironment")
	var room := b.group("Room")
	# 13 x 9 m, 3.4 m high, slightly tilted floor boards (the wreck lists).
	b.block(room, Vector3(0, -0.4, 0), Vector3(13, 0.4, 9), "wood", "", LevelBlock.Shape.BOX, 0.0, "Floor")
	b.block(room, Vector3(0, 3.4, 0), Vector3(13.6, 0.4, 9.6), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "Ceiling")
	b.block(room, Vector3(0, -0.4, -4.75), Vector3(13.6, 4.2, 0.5), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "WallBack")
	b.block(room, Vector3(-6.75, -0.4, 0), Vector3(0.5, 4.2, 9.0), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "WallLeft")
	b.block(room, Vector3(6.75, -0.4, 0), Vector3(0.5, 4.2, 9.0), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "WallRight")
	b.block(room, Vector3(-3.84, -0.4, 4.75), Vector3(5.92, 4.2, 0.5), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "WallFrontL")
	b.block(room, Vector3(3.84, -0.4, 4.75), Vector3(5.92, 4.2, 0.5), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "WallFrontR")
	b.block(room, Vector3(0, 2.45, 4.75), Vector3(1.8, 1.35, 0.5), "wood_dark", "", LevelBlock.Shape.BOX, 0.0, "WallFrontTop")
	# Beams across the ceiling, a big stern window of light at the back.
	for x: float in [-4.5, -1.5, 1.5, 4.5]:
		b.block(room, Vector3(x, 3.0, 0), Vector3(0.35, 0.4, 9.0), "wood", "", LevelBlock.Shape.BOX, 0.0, "Beam")
	var window := OmniLight3D.new()
	window.light_color = Color(0.8, 0.9, 1.0)
	window.light_energy = 0.9
	window.light_specular = 0.0
	window.omni_range = 9.0
	window.position = Vector3(0, 1.8, -2.2)
	b.add(window, room, "WindowLight")
	for p: Vector3 in [Vector3(-3.6, 1.9, 1.2), Vector3(3.6, 1.9, 1.2), Vector3(0, 1.9, 2.0)]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.84, 0.64)
		lamp.light_energy = 0.9
		lamp.light_specular = 0.0
		lamp.omni_range = 7.5
		lamp.position = p
		b.add(lamp, room, "Lamp")
	# The chart table (the sea chart is opened from the pause menu's map).
	b.block(room, Vector3(0, 0, -0.5), Vector3(2.6, 0.9, 1.6), "wood", "", LevelBlock.Shape.BOX, 0.0, "ChartTable")
	b.block(room, Vector3(0, 0.9, -0.5), Vector3(2.3, 0.04, 1.3), "sand", "", LevelBlock.Shape.BOX, 0.0, "Chart")
	# Display anchors (filled at runtime by CaptainsCabin).
	var cabin := CaptainsCabin.new()
	b.add(cabin, null, "Displays")
	cabin.pile_spot = _marker(cabin, "PileSpot", Vector3(-4.6, 0, -3.2))
	cabin.pedestal_row = _marker(cabin, "Pedestals", Vector3(-5.6, 0, 3.0))
	cabin.perch = _marker(cabin, "Perch", Vector3(1.2, 2.2, -4.2))
	b.block(room, Vector3(3.1, 2.15, -4.25), Vector3(5.2, 0.12, 0.12), "wood", "", LevelBlock.Shape.BOX, 0.0, "PerchBar")
	cabin.parts_shelf = _marker(cabin, "PartsShelf", Vector3(6.2, 1.3, -2.6))
	cabin.parts_shelf.rotation_degrees.y = -90.0
	b.block(room, Vector3(6.3, 1.25, 0), Vector3(0.6, 0.1, 7.0), "wood", "", LevelBlock.Shape.BOX, 0.0, "Shelf")
	cabin.rack = _marker(cabin, "AttachmentRack", Vector3(-6.3, 2.0, -2.0))
	cabin.rack.rotation_degrees.y = 90.0
	# Way out: back on deck by the wreck.
	var door := SceneDoor.new()
	door.target_scene = WORLD
	door.spawn_id = &"cabin_door"
	door.label = "Go on deck"
	door.position = Vector3(0, 0, 4.55)
	door.rotation_degrees.y = 180.0
	b.add(door, null, "DeckDoor")
	var spawn := Marker3D.new()
	spawn.position = Vector3(0, 0.05, 3.2)
	spawn.set_meta(&"spawn_id", &"door")
	b.add(spawn, null, "SpawnDoor")
	spawn.add_to_group(&"spawn_point", true)
	var zone := CameraZone.new()
	zone.distance_scale = 0.62
	zone.pitch_offset = -10.0
	zone.blend_time = 0.05
	b.add(zone, null, "CabinCameraZone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(13, 4, 9)
	cs.shape = box
	cs.position = Vector3(0, 1.7, 0)
	b.add(cs, zone, "Shape")
	var player := b.instance(PLAYER, null, Vector3(0, 0.05, 3.2), 0.0, "Player")
	var rig := b.instance(RIG, null, Vector3(0, 2, 6), 0.0, "CameraRig")
	rig.set(&"target", player)
	b.save("res://world/hub/captains_cabin.tscn")


func _marker(parent: Node, node_name: String, pos: Vector3) -> Marker3D:
	var m := Marker3D.new()
	m.position = pos
	b.add(m, parent, node_name)
	return m
