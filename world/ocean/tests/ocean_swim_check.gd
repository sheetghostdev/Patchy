extends Node3D
## Integration check: Patchy swims on the Ocean's SwimVolume and floats on the
## moving waves, and UnderwaterEffect detects the camera under the surface.
##   godot --headless --path . --fixed-fps 60 res://world/ocean/tests/ocean_swim_check.tscn

const PLAYER_SCENE := preload("res://characters/patchy/player.tscn")
const RIG_SCENE := preload("res://systems/camera/camera_rig.tscn")

var _failed := false


func _ready() -> void:
	Settings.auto_camera = false
	var ocean := Ocean.new()
	ocean.name = "Ocean"
	add_child(ocean)
	var floor_block := LevelBlock.new()
	floor_block.size = Vector3(200, 1, 200)
	floor_block.surface = "sand"
	add_child(floor_block)
	floor_block.global_position = Vector3(0, -21, 0)
	var beach := LevelBlock.new()
	beach.shape = LevelBlock.Shape.RAMP
	beach.size = Vector3(12, 4, 24)
	beach.surface = "sand"
	add_child(beach)
	beach.global_position = Vector3(30, -3, 0)
	var effect := UnderwaterEffect.new()
	add_child(effect)
	var player: Player = PLAYER_SCENE.instantiate()
	add_child(player)
	var rig: CameraRig = RIG_SCENE.instantiate()
	rig.target = player
	add_child(rig)
	player.input.virtual_mode = true
	player.input.virtual_reset()
	await _frames(5)

	# 1. Dropped into open water: swims and rides the waves.
	player.teleport(Vector3(0, -0.6, 0), Vector3.FORWARD)
	var swam := false
	for i in 120:
		await _frames(1)
		if player.state_id == &"swim":
			swam = true
			break
	_check("enters swim state in the ocean", swam, String(player.state_id))
	await _frames(90)
	var worst := 0.0
	var lo := INF
	var hi := -INF
	for i in 240:
		await _frames(1)
		var target := ocean.get_surface_height(player.global_position) - player.settings.float_depth
		worst = maxf(worst, absf(player.global_position.y - target))
		lo = minf(lo, player.global_position.y)
		hi = maxf(hi, player.global_position.y)
	_check("floats on the waves (|err| < 0.15 m)", worst < 0.15, "max err=%.3f m" % worst)
	_check("bobs with the swell (> 5 cm)", hi - lo > 0.05, "range=%.3f m" % (hi - lo))
	_check("swim volume reports the ocean surface",
			is_equal_approx(player.water_surface, ocean.get_surface_height(player.global_position)) or absf(player.water_surface - ocean.get_surface_height(player.global_position)) < 0.05,
			"vol=%.3f ocean=%.3f" % [player.water_surface, ocean.get_surface_height(player.global_position)])

	# 2. Underwater effect follows the camera across the surface.
	var cam := Camera3D.new()
	add_child(cam)
	cam.global_position = Vector3(5, -3.0, 5)
	cam.make_current()
	await _frames(20)
	_check("underwater effect on below the surface", effect.amount > 0.99, "amount=%.2f depth=%.2f" % [effect.amount, effect.camera_depth])
	# Rise through the surface in small steps (big jumps count as camera cuts).
	cam.global_position = Vector3(5, -0.8, 5)
	await _frames(2)
	cam.global_position = Vector3(5, 1.5, 5)
	await _frames(4)
	var mid := effect.amount
	await _frames(20)
	_check("blends out smoothly (not instant, then off)", mid > 0.05 and mid < 0.95 and effect.amount < 0.01, "after 4f=%.2f after 24f=%.2f" % [mid, effect.amount])

	print("[ocean swim check] %s" % ("FAIL" if _failed else "PASS"))
	get_tree().quit(1 if _failed else 0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(what: String, ok: bool, detail: String) -> void:
	print("[ocean swim check] %s %s (%s)" % ["ok  " if ok else "FAIL", what, detail])
	if not ok:
		_failed = true
