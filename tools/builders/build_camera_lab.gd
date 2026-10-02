extends RefCounted
## Generates res://tests/scenes/camera_test.tscn (spec §45): the places
## cameras fail. Narrow and bending corridors, low ceilings, a tree grove
## (thin obstructions), a tall cliff, a spiral ramp tower, small rooms, a
## winding cave, a hill, a tall tower with ledges, a moving platform through a
## tight gap and a pool for swim/underwater camera checks.
##   tools/builders/build.sh camera_lab

const PLAYER := "res://characters/patchy/player.tscn"
const RIG := "res://systems/camera/camera_rig.tscn"


func build() -> void:
	var b := SceneBuilder.new("CameraLab")
	var env := SkyEnvironment.new()
	b.add(env, null, "SkyEnvironment")
	var base := b.group("Ground")
	b.block(base, Vector3(0, -1, 0), Vector3(140, 1, 140), "grass", "", LevelBlock.Shape.BOX, 0, "Floor")
	b.label(b.root, Vector3(0, 3.5, -4), "CAMERA LAB", 110, Color(1, 0.86, 0.4))

	_corridors(b)
	_low_ceilings(b)
	_grove(b)
	_cliff(b)
	_spiral(b)
	_rooms(b)
	_cave(b)
	_hill(b)
	_tower(b)
	_gap_mover(b)
	_pool(b)

	for spot: Array in [["Spawn", Vector3(0, 0.1, 0)], ["Corridor", Vector3(-12, 0.1, -10)], ["Grove", Vector3(14, 0.1, -14)],
			["Spiral", Vector3(-30, 0.1, 18)], ["Cave", Vector3(30, 0.1, 22)], ["Tower", Vector3(0, 0.1, 40)], ["Pool", Vector3(44, 0.1, -36)]]:
		var m := Marker3D.new()
		m.position = spot[1]
		b.add(m, null, "Teleport" + String(spot[0]))
		m.add_to_group(&"debug_teleport", true)

	var player := b.instance(PLAYER, null, Vector3(0, 0.05, 0), 0.0, "Player")
	var rig := b.instance(RIG, null, Vector3(0, 1.5, 6), 0.0, "CameraRig")
	rig.set(&"target", player)
	b.save("res://tests/scenes/camera_test.tscn")


func _corridors(b: SceneBuilder) -> void:
	var g := b.group("Corridors")
	b.label(g, Vector3(-12, 5.2, -4), "NARROW CORRIDOR (1.6 m) + BEND", 70, Color(0.8, 0.95, 1))
	# Straight section along -Z, then a 90° bend toward -X.
	b.block(g, Vector3(-13.15, 0, -14), Vector3(0.7, 4, 20), "stone")
	b.block(g, Vector3(-10.85, 0, -12.2), Vector3(0.7, 4, 16.4), "stone")
	b.block(g, Vector3(-17.5, 0, -24.35), Vector3(9.4, 4, 0.7), "stone")
	b.block(g, Vector3(-16.4, 0, -20.75), Vector3(11.2, 4, 0.7), "stone")
	# Zig-zag alley with 1.2 m pinch points.
	b.label(g, Vector3(-30, 5.2, -6), "PINCH POINTS (1.2 m)", 60)
	for k in 4:
		var z := -8.0 - k * 4.0
		var x := -30.0 + (1.2 if k % 2 == 0 else -1.2)
		b.block(g, Vector3(x - 2.0, 0, z), Vector3(2.6, 4, 1.2), "stone")
		b.block(g, Vector3(x + 2.2, 0, z), Vector3(2.6, 4, 1.2), "stone")


func _low_ceilings(b: SceneBuilder) -> void:
	var g := b.group("LowCeilings")
	b.label(g, Vector3(0, 4.6, -16), "LOW CEILING 2.2 m (no camera zone)", 60, Color(1, 0.9, 0.7))
	b.block(g, Vector3(-1.9, 0, -24), Vector3(0.8, 2.2, 14), "wood")
	b.block(g, Vector3(1.9, 0, -24), Vector3(0.8, 2.2, 14), "wood")
	b.block(g, Vector3(0, 2.2, -24), Vector3(4.6, 0.5, 14), "wood")
	b.label(g, Vector3(8, 4.6, -16), "LOW CEILING + ZONE", 60, Color(1, 0.9, 0.7))
	b.block(g, Vector3(6.1, 0, -24), Vector3(0.8, 2.2, 14), "wood")
	b.block(g, Vector3(9.9, 0, -24), Vector3(0.8, 2.2, 14), "wood")
	b.block(g, Vector3(8, 2.2, -24), Vector3(4.6, 0.5, 14), "wood")
	var zone := CameraZone.new()
	zone.distance_scale = 0.55
	zone.pitch_offset = 8.0
	zone.position = Vector3(8, 1.1, -24)
	b.add(zone, g, "TunnelZone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 2.2, 14)
	cs.shape = box
	b.add(cs, zone, "Shape")


func _grove(b: SceneBuilder) -> void:
	var g := b.group("Grove")
	b.label(g, Vector3(16, 7.5, -10), "TREE GROVE (thin obstructions)", 60, Color(0.8, 1, 0.8))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for k in 18:
		var p := Vector3(rng.randf_range(8.0, 24.0), 0, rng.randf_range(-24.0, -8.0))
		var h := rng.randf_range(4.5, 7.5)
		b.block(g, p, Vector3(0.7, h, 0.7), "wood", "", LevelBlock.Shape.CYLINDER)
		var canopy := b.block(g, p + Vector3(0, h, 0), Vector3(3.2, 1.6, 3.2), "grass", "", LevelBlock.Shape.CYLINDER)
		canopy.bevel = 0.3


func _cliff(b: SceneBuilder) -> void:
	var g := b.group("Cliff")
	b.label(g, Vector3(34, 22, -6), "VERTICAL CLIFF 20 m", 70)
	b.block(g, Vector3(40, 0, -6), Vector3(8, 20, 30), "cliff")
	for k in 4:
		b.block(g, Vector3(35.4, 3.0 + k * 4.0, -16.0 + k * 6.0), Vector3(1.4, 0.5, 3.0), "rock", "")


func _spiral(b: SceneBuilder) -> void:
	var g := b.group("Spiral")
	b.label(g, Vector3(-30, 17, 12), "SPIRAL RAMP TOWER", 70, Color(1, 0.8, 0.9))
	var c := Vector3(-30, 0, 18)
	b.block(g, c, Vector3(3.2, 15, 3.2), "stone", "", LevelBlock.Shape.CYLINDER, 0, "Core")
	var steps := 40
	for k in steps:
		var ang := deg_to_rad(k * 22.0)
		var y := k * 0.35
		var r := 3.4
		var pos := c + Vector3(cos(ang) * r, y, sin(ang) * r)
		var blk := b.block(g, pos, Vector3(3.2, 0.35, 1.6), "stone", "", LevelBlock.Shape.BOX, 0, "Step")
		blk.rotation.y = -ang + PI * 0.5
		blk.bevel = 0.05


func _rooms(b: SceneBuilder) -> void:
	var g := b.group("Rooms")
	b.label(g, Vector3(-12, 5.5, 18), "SMALL ROOMS", 70)
	for k in 2:
		var c := Vector3(-14.0 + k * 7.0, 0, 22)
		b.block(g, c + Vector3(-2.6, 0, 0), Vector3(0.6, 3, 5.8), "wood")
		b.block(g, c + Vector3(2.6, 0, 0), Vector3(0.6, 3, 5.8), "wood")
		b.block(g, c + Vector3(0, 0, 2.6), Vector3(5.8, 3, 0.6), "wood")
		b.block(g, c + Vector3(-1.75, 0, -2.6), Vector3(2.3, 3, 0.6), "wood")
		b.block(g, c + Vector3(1.75, 0, -2.6), Vector3(2.3, 3, 0.6), "wood")
		if k == 1:
			b.block(g, c + Vector3(0, 3, 0), Vector3(5.8, 0.4, 5.8), "wood", "roofed room")


func _cave(b: SceneBuilder) -> void:
	var g := b.group("Cave")
	b.label(g, Vector3(28, 7, 12), "WINDING CAVE", 70, Color(0.85, 0.85, 1))
	var path := [Vector3(26, 0, 14), Vector3(30, 0, 20), Vector3(28, 0, 27), Vector3(33, 0, 33), Vector3(38, 0, 30)]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in path.size() - 1:
		var a: Vector3 = path[k]
		var bb: Vector3 = path[k + 1]
		var dir := (bb - a)
		var len := dir.length()
		var yaw := atan2(-dir.x, -dir.z)
		var mid := (a + bb) * 0.5
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var w := 1.6 + rng.randf() * 0.6
		var ceil_h := 2.6 + rng.randf() * 0.8
		for side: float in [-1.0, 1.0]:
			var wall := b.block(g, mid + right * side * (w + 0.8), Vector3(1.6, ceil_h + 1.0, len + 1.4), "rock", "", LevelBlock.Shape.BOX, rad_to_deg(yaw))
			wall.bevel = 0.4
		var roof := b.block(g, mid + Vector3(0, ceil_h, 0), Vector3(w * 2.0 + 3.2, 1.4, len + 1.4), "rock", "", LevelBlock.Shape.BOX, rad_to_deg(yaw))
		roof.bevel = 0.5


func _hill(b: SceneBuilder) -> void:
	var g := b.group("Hill")
	b.label(g, Vector3(-44, 9, -30), "HILL 25°", 70)
	var c := Vector3(-44, 0, -30)
	for k in 4:
		var rot := k * 90.0
		var dir := Vector3(0, 0, 1).rotated(Vector3.UP, deg_to_rad(rot))
		b.block(g, c + dir * 9.0, Vector3(10, 10.0 * tan(deg_to_rad(25.0)) * 0.8, 10), "grass", "", LevelBlock.Shape.RAMP, rot)
	b.block(g, c, Vector3(8, 10.0 * tan(deg_to_rad(25.0)) * 0.8, 8), "grass", "summit")


func _tower(b: SceneBuilder) -> void:
	var g := b.group("Tower")
	b.label(g, Vector3(0, 28, 34), "TALL TOWER 25 m", 80, Color(1, 0.85, 0.6))
	var c := Vector3(0, 0, 40)
	b.block(g, c, Vector3(6, 25, 6), "stone", "", LevelBlock.Shape.BOX, 0, "Tower")
	for k in 8:
		var ang := deg_to_rad(k * 90.0 + 45.0)
		var y := 2.2 + k * 2.8
		var p := c + Vector3(cos(ang) * 4.2, y, sin(ang) * 4.2)
		b.block(g, p, Vector3(2.4, 0.4, 2.4), "wood")
	b.block(g, c + Vector3(0, 0, -5), Vector3(3, 2.2, 4), "stone", "", LevelBlock.Shape.STAIRS, 0, "TowerSteps")


func _gap_mover(b: SceneBuilder) -> void:
	var g := b.group("GapMover")
	b.label(g, Vector3(18, 6, 8), "MOVER THROUGH TIGHT GAP", 60, Color(0.7, 0.9, 1))
	b.block(g, Vector3(18, 0, 10), Vector3(1, 5, 6), "stone")
	b.block(g, Vector3(18, 0, 16.5), Vector3(1, 5, 6), "stone")
	b.block(g, Vector3(18, 2.6, 13.25), Vector3(1, 2.4, 1.5), "stone")
	var mp := MovingPlatform.new()
	mp.position = Vector3(12, 1.0, 13.25)
	mp.waypoints = PackedVector3Array([Vector3.ZERO, Vector3(12, 0, 0)])
	mp.speed = 2.5
	b.add(mp, g, "Mover")
	var vis := LevelBlock.new()
	vis.size = Vector3(3, 0.5, 1.2)
	vis.surface = "lab_orange"
	vis.position = Vector3(0, -0.5, 0)
	vis.collision_layer = 0
	b.add(vis, mp, "Visual")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 0.5, 1.2)
	cs.shape = box
	cs.position = Vector3(0, -0.25, 0)
	b.add(cs, mp, "Shape")


func _pool(b: SceneBuilder) -> void:
	var g := b.group("Pool")
	var c := Vector3(44, 0, -36)
	b.label(g, c + Vector3(0, 6, 0), "SWIM / UNDERWATER", 70, Color(0.6, 0.95, 1))
	b.block(g, c + Vector3(0, 0, -9), Vector3(20, 5, 2), "stone")
	b.block(g, c + Vector3(0, 0, 9), Vector3(20, 5, 2), "stone")
	b.block(g, c + Vector3(-9, 0, 0), Vector3(2, 5, 16), "stone")
	b.block(g, c + Vector3(9, 0, 0), Vector3(2, 5, 16), "stone")
	b.block(g, c + Vector3(-12.5, 0, 0), Vector3(5, 5, 4), "stone", "", LevelBlock.Shape.STAIRS, -90, "Steps")
	b.block(g, c + Vector3(2, 0, 2), Vector3(3, 2.5, 3), "rock", "rock")
	var water := WaterVolume.new()
	water.size = Vector3(16, 4.6, 16)
	water.position = c + Vector3(0, 4.6, 0)
	b.add(water, g, "Water")
