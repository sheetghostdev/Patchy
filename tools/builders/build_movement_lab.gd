extends RefCounted
## Generates res://tests/scenes/movement_test.tscn (spec §46): a tuning lab
## with measured gaps, ledge heights, curbs, stairs, slopes, moving platforms,
## wall kicks, low ceilings, hook rings, water and long-jump / dive
## challenges. Every element is labelled with its dimensions.
##   tools/builders/build.sh movement_lab

const PLAYER := "res://characters/patchy/player.tscn"
const RIG := "res://systems/camera/camera_rig.tscn"
const H := 2.0  # runway height for jump rows


func build() -> void:
	var b := SceneBuilder.new("MovementLab")
	var env := SkyEnvironment.new()
	env.preset = SkyEnvironment.Preset.LAB
	b.add(env, null, "SkyEnvironment")

	var floor_root := b.group("Floor")
	# Main floor 120 x 120, with the hook pit carved out north of it.
	b.block(floor_root, Vector3(0, -1, 0), Vector3(120, 1, 120), "lab", "", LevelBlock.Shape.BOX, 0, "MainFloor")
	b.block(floor_root, Vector3(0, -1, -70), Vector3(24, 1, 20), "lab", "", LevelBlock.Shape.BOX, 0, "PitApproach")
	b.block(floor_root, Vector3(0, -1, -106), Vector3(24, 1, 16), "lab", "", LevelBlock.Shape.BOX, 0, "PitFarSide")
	var kz := KillZone.new()
	kz.size = Vector3(60, 2, 40)
	kz.position = Vector3(0, -14, -88)
	b.add(kz, floor_root, "PitKillZone")

	b.label(b.root, Vector3(0, 3.2, -3), "PATCHY MOVEMENT LAB", 110, Color(1, 0.86, 0.4))

	_gap_row(b)
	_long_jump_row(b)
	_ledge_wall(b)
	_curbs(b)
	_slopes(b)
	_movers(b)
	_wall_kicks(b)
	_ceilings(b)
	_hook_pit(b)
	_pool(b)
	_dive_challenge(b)

	var player := b.instance(PLAYER, null, Vector3(0, 0.05, 0), 0.0, "Player")
	var rig := b.instance(RIG, null, Vector3(0, 1.5, 6), 0.0, "CameraRig")
	rig.set(&"target", player)
	b.save("res://tests/scenes/movement_test.tscn")


func _gap_row(b: SceneBuilder) -> void:
	var g := b.group("GapRow")
	var x := -7.0
	b.label(g, Vector3(x, H + 3.2, -8), "RUNNING JUMP GAPS", 80, Color(0.6, 1.0, 0.85))
	b.block(g, Vector3(x, 0, -6), Vector3(3, H, 4), "lab_teal", "", LevelBlock.Shape.STAIRS, 0, "Stairs")
	var z := -8.0
	var run := 8.0
	b.block(g, Vector3(x, 0, z - run * 0.5), Vector3(3, H, run), "lab_teal", "", LevelBlock.Shape.BOX, 0, "Start")
	z -= run
	for gap: float in [2.0, 3.0, 4.0, 5.0, 6.0]:
		b.label(g, Vector3(x, H + 1.0, z - gap * 0.5), "%d m" % int(gap), 90)
		z -= gap
		var plat := 4.0 + gap * 0.5
		b.block(g, Vector3(x, 0, z - plat * 0.5), Vector3(3, H, plat), "lab_teal")
		z -= plat


func _long_jump_row(b: SceneBuilder) -> void:
	var g := b.group("LongJumpRow")
	var x := 7.0
	b.label(g, Vector3(x, H + 3.2, -8), "LONG JUMP (run + crouch + jump)", 80, Color(1.0, 0.8, 0.5))
	b.block(g, Vector3(x, 0, -6), Vector3(3, H, 4), "lab_orange", "", LevelBlock.Shape.STAIRS, 0, "Stairs")
	var z := -8.0
	var run := 14.0
	b.block(g, Vector3(x, 0, z - run * 0.5), Vector3(3, H, run), "lab_orange", "", LevelBlock.Shape.BOX, 0, "Runway")
	z -= run
	for gap: float in [7.0, 8.0, 9.0, 10.0]:
		b.label(g, Vector3(x, H + 1.0, z - gap * 0.5), "%d m" % int(gap), 90)
		z -= gap
		var plat := 8.0
		b.block(g, Vector3(x, 0, z - plat * 0.5), Vector3(3, H, plat), "lab_orange")
		z -= plat


func _ledge_wall(b: SceneBuilder) -> void:
	var g := b.group("LedgeHeights")
	b.label(g, Vector3(19, 6.5, -12), "LEDGE HEIGHTS", 80, Color(0.85, 0.75, 1.0))
	var z := 4.0
	var notes := {0.5: "walk/step", 1.0: "hop", 1.5: "jump", 2.0: "jump", 2.5: "full jump",
		3.0: "ledge grab", 3.5: "ledge grab", 4.0: "flip / GP jump", 4.5: "wall kick"}
	for h: float in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0, 4.5]:
		b.block(g, Vector3(19, 0, z), Vector3(4, h, 3.5), "lab_purple", "%.1f m — %s" % [h, notes[h]])
		z -= 5.0


func _curbs(b: SceneBuilder) -> void:
	var g := b.group("Curbs")
	b.label(g, Vector3(30, 2.4, 2), "STEP-UP CURBS", 70, Color(0.8, 1, 0.7))
	var z := 0.0
	for h: float in [0.15, 0.25, 0.35, 0.45]:
		b.block(g, Vector3(30, 0, z), Vector3(4, h, 3), "lab_blue", "%.2f m" % h)
		z -= 6.0
	var real := b.block(g, Vector3(36, 0, -6), Vector3(4, 2.0, 6), "lab_blue", "real steps", LevelBlock.Shape.STAIRS, 0, "RealStairs")
	real.smooth_stair_collision = false
	b.block(g, Vector3(36, 0, -12), Vector3(4, 2.0, 6), "lab_blue", "")
	b.block(g, Vector3(42, 0, -6), Vector3(4, 2.0, 6), "lab_blue", "smooth stairs", LevelBlock.Shape.STAIRS)
	b.block(g, Vector3(42, 0, -12), Vector3(4, 2.0, 6), "lab_blue", "")


func _slopes(b: SceneBuilder) -> void:
	var g := b.group("Slopes")
	b.label(g, Vector3(-22, 7, 4), "SLOPES (slide > 38°)", 80, Color(1, 0.75, 0.85))
	var z := 0.0
	for deg: float in [15.0, 25.0, 35.0, 42.0, 52.0]:
		var depth := 8.0
		var rise := depth * tan(deg_to_rad(deg))
		b.block(g, Vector3(-22, 0, z), Vector3(6, rise, depth), "lab_pink", "%d°" % int(deg), LevelBlock.Shape.RAMP)
		b.block(g, Vector3(-22, 0, z - depth * 0.5 - 2.0), Vector3(6, rise, 4), "lab_pink")
		z -= 16.0
	# Long sandy slide chute (slide surface) down from a tower; stairs behind.
	b.block(g, Vector3(-50, 0, -60), Vector3(8, 14, 8), "lab_pink", "slide tower 14 m", LevelBlock.Shape.BOX, 0, "Tower")
	b.block(g, Vector3(-50, 0, -74), Vector3(4, 14, 20), "lab_pink", "", LevelBlock.Shape.STAIRS, 180, "TowerStairs")
	var chute := b.block(g, Vector3(-50, 0, -40), Vector3(6, 14, 32), "sand", "slide chute", LevelBlock.Shape.RAMP, 0, "Chute")
	chute.slide_surface = true


func _movers(b: SceneBuilder) -> void:
	var g := b.group("MovingPlatforms")
	b.label(g, Vector3(-24, 6, 26), "MOVING PLATFORMS", 80, Color(0.7, 0.9, 1))
	var mover := _platform(b, g, Vector3(-30, 1.6, 22), Vector3(4, 0.6, 4), "Mover")
	mover.waypoints = PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0)])
	mover.speed = 3.0
	var lift := _platform(b, g, Vector3(-16, 0.4, 30), Vector3(4, 0.6, 4), "Elevator")
	lift.waypoints = PackedVector3Array([Vector3.ZERO, Vector3(0, 6, 0)])
	lift.speed = 2.5
	lift.wait_time = 1.2
	b.block(g, Vector3(-16, 0, 36.5), Vector3(6, 6.4, 5), "lab_blue", "6.4 m")
	var spin := _platform(b, g, Vector3(-30, 1.2, 36), Vector3(10, 0.6, 2.5), "Spinner")
	spin.mode = MovingPlatform.Mode.ROTATE
	spin.rotate_speed = 35.0
	var loop := _platform(b, g, Vector3(-42, 2.2, 22), Vector3(3.5, 0.6, 3.5), "Loop")
	loop.mode = MovingPlatform.Mode.LOOP
	loop.waypoints = PackedVector3Array([Vector3.ZERO, Vector3(0, 0, 10), Vector3(-8, 2, 10), Vector3(-8, 2, 0)])
	loop.speed = 3.5
	loop.wait_time = 0.3


func _platform(b: SceneBuilder, parent: Node, pos: Vector3, size: Vector3, node_name: String) -> MovingPlatform:
	var mp := MovingPlatform.new()
	mp.position = pos
	b.add(mp, parent, node_name)
	var vis := LevelBlock.new()
	vis.size = size
	vis.surface = "lab_orange"
	vis.position = Vector3(0, -size.y, 0)
	vis.collision_layer = 0
	b.add(vis, mp, "Visual")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0, -size.y * 0.5, 0)
	b.add(cs, mp, "Shape")
	return mp


func _wall_kicks(b: SceneBuilder) -> void:
	var g := b.group("WallKicks")
	b.label(g, Vector3(-4, 13.5, 24), "WALL KICK CHIMNEY (3.4 m)", 80, Color(1, 0.9, 0.6))
	b.block(g, Vector3(-6.2, 0, 24), Vector3(1, 12, 8), "lab_purple")
	b.block(g, Vector3(-1.8, 0, 24), Vector3(1, 12, 8), "lab_purple")
	b.block(g, Vector3(-4, 12, 24), Vector3(6, 0.5, 8), "lab_purple", "top 12.5 m")
	b.label(g, Vector3(8, 13.5, 24), "SINGLE WALL: one kick only", 70, Color(1, 0.7, 0.6))
	b.block(g, Vector3(8, 0, 26), Vector3(8, 12, 1), "lab_purple")


func _ceilings(b: SceneBuilder) -> void:
	var g := b.group("LowCeilings")
	b.label(g, Vector3(20, 5, 22), "LOW CEILING TUNNEL (2.3 m)", 70, Color(0.8, 0.9, 1))
	b.block(g, Vector3(17.5, 0, 30), Vector3(1, 2.3, 14), "lab_blue")
	b.block(g, Vector3(22.5, 0, 30), Vector3(1, 2.3, 14), "lab_blue")
	b.block(g, Vector3(20, 2.3, 30), Vector3(6, 0.6, 14), "lab_blue")
	var zone := CameraZone.new()
	zone.distance_scale = 0.62
	zone.pitch_offset = 6.0
	zone.position = Vector3(20, 1.2, 30)
	b.add(zone, g, "TunnelCameraZone")
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 2.4, 14)
	cs.shape = box
	b.add(cs, zone, "Shape")
	# Overhang corner to test ceiling slip while jumping.
	b.block(g, Vector3(26, 2.6, 16), Vector3(3, 0.6, 3), "lab_blue", "overhang 2.6 m")


func _hook_pit(b: SceneBuilder) -> void:
	var g := b.group("HookPit")
	b.label(g, Vector3(0, 9, -78), "HOOK RINGS — jump, then tool_primary / interact", 70, Color(1, 0.86, 0.4))
	b.label(g, Vector3(0, 1.5, -88), "16 m pit", 90)
	for k in 3:
		var hp := HookPoint.new()
		hp.position = Vector3(0, 6.6, -83.0 - k * 5.0)
		hp.hang_length = 1.5
		b.add(hp, g, "HookRing%d" % (k + 1))


func _pool(b: SceneBuilder) -> void:
	var g := b.group("Pool")
	var c := Vector3(44, 0, 34)
	b.label(g, c + Vector3(0, 6, 0), "WATER (2.6 m deep)", 80, Color(0.6, 0.95, 1))
	b.block(g, c + Vector3(0, 0, -8), Vector3(18, 3, 2), "stone")
	b.block(g, c + Vector3(0, 0, 8), Vector3(18, 3, 2), "stone")
	b.block(g, c + Vector3(-8, 0, 0), Vector3(2, 3, 14), "stone")
	b.block(g, c + Vector3(8, 0, 0), Vector3(2, 3, 14), "stone")
	b.block(g, c + Vector3(-11, 0, 0), Vector3(4, 3, 4), "stone", "", LevelBlock.Shape.STAIRS, -90, "Steps")
	b.block(g, c + Vector3(3.5, 0, 3.5), Vector3(5, 2.1, 7), "sand", "shallow", LevelBlock.Shape.RAMP, -90, "Shallows")
	var water := WaterVolume.new()
	water.size = Vector3(14, 2.6, 14)
	water.position = c + Vector3(0, 2.6, 0)
	b.add(water, g, "Water")


func _dive_challenge(b: SceneBuilder) -> void:
	var g := b.group("DiveChallenge")
	b.label(g, Vector3(-40, 8.5, -12), "JUMP + DIVE: 10 m", 80, Color(1, 0.8, 0.95))
	b.block(g, Vector3(-40, 0, -6), Vector3(5, 4, 10), "lab_teal", "4 m")
	b.block(g, Vector3(-40, 0, 2), Vector3(3, 4, 6), "lab_teal", "", LevelBlock.Shape.STAIRS, 180, "Stairs")
	b.block(g, Vector3(-40, 0, -24), Vector3(5, 2.5, 6), "lab_teal", "2.5 m")
