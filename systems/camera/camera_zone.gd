class_name CameraZone
extends Area3D
## Volume that adjusts the camera while Patchy is inside (spec §35):
## pull in for tight interiors, widen for spectacle, hint a viewing angle.
## Values blend smoothly; the highest priority overlapping zone wins.

@export var priority := 0
@export_range(0.3, 3.0, 0.05) var distance_scale := 1.0
## Added to the default pitch (degrees; negative looks further down).
@export_range(-45.0, 45.0, 0.5) var pitch_offset := 0.0
@export_range(-2.0, 3.0, 0.05) var height_offset := 0.0
@export_range(-20.0, 20.0, 0.5) var fov_offset := 0.0
## Scales the automatic yaw alignment (0 disables it inside the zone).
@export_range(0.0, 2.0, 0.05) var auto_align_scale := 1.0
## Optionally steer the camera toward a world yaw when idle.
@export var use_yaw_hint := false
@export_range(-180.0, 180.0, 1.0) var yaw_hint_degrees := 0.0
@export_range(0.05, 3.0, 0.05) var blend_time := 0.6


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var rig := _rig_for(body)
	if rig != null:
		rig.register_zone(self)


func _on_body_exited(body: Node3D) -> void:
	var rig := _rig_for(body)
	if rig != null:
		rig.unregister_zone(self)


func _rig_for(body: Node3D) -> CameraRig:
	if body is Player and (body as Player).camera_rig is CameraRig:
		return (body as Player).camera_rig as CameraRig
	return null


func get_params() -> Dictionary:
	var d := {
		&"distance_scale": distance_scale,
		&"pitch_offset": pitch_offset,
		&"height_offset": height_offset,
		&"fov_offset": fov_offset,
		&"auto_align_scale": auto_align_scale,
		&"blend_time": blend_time,
	}
	if use_yaw_hint:
		d[&"yaw_hint"] = deg_to_rad(yaw_hint_degrees)
	return d
