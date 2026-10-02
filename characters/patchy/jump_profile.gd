class_name JumpProfile
extends RefCounted
## How Patchy behaves in the air after a particular kind of takeoff. Built
## from PlayerMovementSettings by Player._build_profiles(); never hand-tuned
## here.

var kind: StringName
var gravity_up: float
var gravity_down: float
## Releasing jump early increases rising gravity (variable height).
var variable := false
## Soften gravity near the apex while jump is held.
var apex_soft := false
var air_accel: float
var air_drag: float
## Steering speed cap (existing faster momentum is preserved).
var max_speed: float
var turn_rate: float
## Seconds of no steering at takeoff (wall kicks).
var steer_lock := 0.0
## Facing follows the stick in the air.
var face_input := true
var allow_dive := true
var allow_ground_pound := true
var allow_ledge := true
var allow_wall_kick := true
var allow_hook := true
var terminal: float = 27.0


func _init(p_kind: StringName = &"fall") -> void:
	kind = p_kind
