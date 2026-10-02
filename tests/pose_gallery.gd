extends Node3D
## Lines up Patchys locked in each animation state for visual review.
## tools/photo/shoot.sh scene=res://tests/pose_gallery.tscn ...

const PLAYER := preload("res://characters/patchy/player.tscn")
const STATES: Array[StringName] = [
	&"idle", &"crouch", &"skid", &"jump_up", &"jump_apex", &"fall", &"long_jump",
	&"dive", &"belly_slide", &"ground_pound", &"ground_pound_land", &"ledge_hang",
	&"wall_slide", &"wall_kick", &"slide", &"swim", &"swim_idle", &"hook_swing", &"hurt",
]


func _ready() -> void:
	var env := SkyEnvironment.new()
	add_child(env)
	var floor_block := LevelBlock.new()
	floor_block.size = Vector3(80, 1, 20)
	floor_block.surface = "lab"
	floor_block.position = Vector3(0, -1, 0)
	add_child(floor_block)
	var cols := 7
	for i in STATES.size():
		var p: Player = PLAYER.instantiate()
		var x := (i % cols - (cols - 1) * 0.5) * 2.4
		var z := float(i / cols) * 4.0
		p.position = Vector3(x, 0.05, z)
		p.rotation.y = deg_to_rad(-60.0)
		add_child(p)
		p.input.virtual_mode = true
		p.set_locked(true, {"anim": STATES[i]})
		var l := Label3D.new()
		l.text = String(STATES[i])
		l.font_size = 48
		l.pixel_size = 0.005
		l.outline_size = 10
		l.position = Vector3(x, 0.05, z + 1.0)
		l.rotation.x = -PI * 0.35
		add_child(l)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 7.5, 16)
	cam.fov = 50
	add_child(cam)
	cam.look_at(Vector3(0, 0.5, 3.5))
	cam.make_current()
