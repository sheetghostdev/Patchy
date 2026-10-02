extends SceneTree
## Writes the default InputMap into project.godot and the audio bus layout.
## Run from the project root:
##   godot --headless --path . -s tools/setup_project.gd
## Bindings follow spec §13: keyboard+mouse and gamepad for every action.

const MOVE_DZ := 0.2
const CAM_DZ := 0.15
const TRIGGER_DZ := 0.35


func _init() -> void:
	_define_inputs()
	var err := ProjectSettings.save()
	print("project.godot saved: ", error_string(err))
	_define_buses()
	quit()


func _key(physical: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = physical
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e


func _action(action_name: String, events: Array, deadzone: float = 0.5) -> void:
	ProjectSettings.set_setting("input/" + action_name, {"deadzone": deadzone, "events": events})


func _define_inputs() -> void:
	# Movement (analog magnitude: small deflection walks, full deflection runs)
	_action("move_left", [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)], MOVE_DZ)
	_action("move_right", [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)], MOVE_DZ)
	_action("move_forward", [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)], MOVE_DZ)
	_action("move_back", [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)], MOVE_DZ)
	_action("walk", [_key(KEY_ALT)])

	# Core moves
	_action("jump", [_key(KEY_SPACE), _joy(JOY_BUTTON_A)])
	_action("crouch", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)], TRIGGER_DZ)
	_action("ground_pound", [_key(KEY_SHIFT), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)], TRIGGER_DZ)
	_action("dive", [_key(KEY_CTRL), _key(KEY_F), _joy(JOY_BUTTON_B)])
	_action("attack", [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_X)])
	_action("interact", [_key(KEY_E), _joy(JOY_BUTTON_Y)])

	# Hand attachments
	_action("tool_primary", [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)], TRIGGER_DZ)
	_action("tool_secondary", [_key(KEY_R), _joy(JOY_BUTTON_DPAD_DOWN)])
	_action("tool_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_X), _joy(JOY_BUTTON_RIGHT_SHOULDER)])
	_action("tool_previous", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_Z), _joy(JOY_BUTTON_LEFT_SHOULDER)])

	# Camera (mouse look is handled directly by the camera rig)
	_action("camera_left", [_key(KEY_J), _axis(JOY_AXIS_RIGHT_X, -1.0)], CAM_DZ)
	_action("camera_right", [_key(KEY_L), _axis(JOY_AXIS_RIGHT_X, 1.0)], CAM_DZ)
	_action("camera_up", [_key(KEY_I), _axis(JOY_AXIS_RIGHT_Y, -1.0)], CAM_DZ)
	_action("camera_down", [_key(KEY_K), _axis(JOY_AXIS_RIGHT_Y, 1.0)], CAM_DZ)
	_action("camera_reset", [_key(KEY_C), _mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_RIGHT_STICK)])

	# Menus
	_action("pause", [_key(KEY_ESCAPE), _key(KEY_P), _joy(JOY_BUTTON_START)])
	_action("map", [_key(KEY_M), _joy(JOY_BUTTON_BACK)])

	# Development
	_action("debug_menu", [_key(KEY_F1)])
	_action("debug_hud", [_key(KEY_F3)])
	_action("debug_camera", [_key(KEY_F4)])
	_action("quick_save", [_key(KEY_F5)])
	_action("quick_load", [_key(KEY_F9)])


func _define_buses() -> void:
	var names := ["Music", "SFX", "UI", "Ambience"]
	for n in names:
		if AudioServer.get_bus_index(n) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, n)
			AudioServer.set_bus_send(idx, "Master")
	# A gentle limiter keeps stacked impacts from clipping.
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(master, lim)
	var layout := AudioServer.generate_bus_layout()
	var err := ResourceSaver.save(layout, "res://default_bus_layout.tres")
	print("default_bus_layout.tres saved: ", error_string(err))
