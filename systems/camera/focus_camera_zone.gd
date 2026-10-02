class_name FocusCameraZone
extends CameraZone
## A camera zone that keeps a focus (a boss) in view: while Patchy leaves
## the stick alone, the camera eases around behind him to face the focus.
## Manual control always wins (spec §44: never fight the player).

@export var focus: Node3D
## Smoothing time of the swing toward the focus (s).
@export_range(0.1, 3.0, 0.05) var yaw_hint_time := 0.6


func get_params() -> Dictionary:
	var d := super.get_params()
	var p := GameManager.player
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree() and p != null:
		var to := Player.flat(focus.global_position - p.global_position)
		if to.length() > 1.5:
			d[&"yaw_hint"] = Player.yaw_of(to)
			d[&"yaw_hint_time"] = yaw_hint_time
	return d
