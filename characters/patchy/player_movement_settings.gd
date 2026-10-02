@tool
class_name PlayerMovementSettings
extends Resource
## Every movement tuning value for Patchy (spec §161). Edit the .tres in the
## inspector while the game runs; nothing in the controller hard-codes feel.
## Jumps are authored as height + time-to-apex; velocities and gravities are
## derived so designers think in meters and seconds.

@export_group("Ground")
## Top speed with the stick fully deflected (m/s).
@export_range(1.0, 20.0, 0.1) var run_speed: float = 8.5
## Speed at the walk threshold of the stick (m/s).
@export_range(0.5, 10.0, 0.1) var walk_speed: float = 3.2
## Stick magnitude at which walking becomes running.
@export_range(0.1, 0.95, 0.01) var walk_stick_threshold: float = 0.55
## Acceleration toward target speed (m/s²).
@export_range(1.0, 200.0, 0.5) var ground_accel: float = 40.0
## Extra acceleration multiplier while slower than walk speed (snappy starts).
@export_range(1.0, 4.0, 0.05) var start_accel_boost: float = 1.8
## Deceleration when the stick is released (m/s²). Short, never a dead stop.
@export_range(1.0, 300.0, 0.5) var ground_decel: float = 62.0
## Deceleration when above target speed while still steering (m/s²).
@export_range(1.0, 200.0, 0.5) var over_speed_decel: float = 16.0
## Heading turn rate when slow / at full speed (rad/s).
@export_range(1.0, 60.0, 0.5) var turn_rate_slow: float = 20.0
@export_range(1.0, 60.0, 0.5) var turn_rate_fast: float = 10.0
## Below this speed the heading snaps straight to the stick direction.
@export_range(0.0, 5.0, 0.05) var instant_turn_speed: float = 1.2

@export_group("Skid")
## Reversal angle (degrees) that triggers a skid at speed.
@export_range(90.0, 180.0, 1.0) var skid_angle: float = 135.0
@export_range(0.0, 20.0, 0.1) var skid_min_speed: float = 5.5
@export_range(1.0, 200.0, 0.5) var skid_decel: float = 55.0
## Speed Patchy launches into the new direction after a skid.
@export_range(0.0, 10.0, 0.1) var skid_exit_speed: float = 3.0

@export_group("Slopes")
## Slopes steeper than this make Patchy slide (degrees).
@export_range(10.0, 60.0, 0.5) var slide_angle: float = 38.0
## Anything steeper than this is a wall (degrees).
@export_range(30.0, 80.0, 0.5) var floor_max_angle: float = 60.0
## Speed multiplier walking straight up the steepest walkable slope.
@export_range(0.3, 1.0, 0.01) var uphill_speed_scale: float = 0.8
## Speed multiplier walking straight down the steepest walkable slope.
@export_range(1.0, 1.6, 0.01) var downhill_speed_scale: float = 1.12
## Ground snapping distance to stay glued over crests and down stairs.
@export_range(0.0, 1.0, 0.01) var floor_snap: float = 0.45
## Max height of a curb/step Patchy walks up without jumping.
@export_range(0.0, 0.8, 0.01) var step_height: float = 0.38

@export_group("Slide")
@export_range(1.0, 80.0, 0.5) var slide_gravity: float = 26.0
@export_range(1.0, 40.0, 0.5) var slide_max_speed: float = 16.0
@export_range(0.0, 60.0, 0.5) var slide_steer_accel: float = 14.0
@export_range(0.0, 20.0, 0.1) var slide_friction: float = 1.5
## Seconds on gentle ground before a slide ends.
@export_range(0.0, 1.0, 0.01) var slide_exit_delay: float = 0.12

@export_group("Jump")
## Apex height of a full (held) standing jump (m).
@export_range(0.5, 6.0, 0.05) var jump_height: float = 2.45
## Seconds from takeoff to apex for a full jump.
@export_range(0.15, 1.0, 0.01) var jump_time_to_apex: float = 0.37
## Extra apex height at full run speed (m).
@export_range(0.0, 2.0, 0.05) var jump_speed_bonus_height: float = 0.3
## Gravity multiplier when falling (heavier fall = snappier arc).
@export_range(1.0, 4.0, 0.05) var fall_gravity_scale: float = 1.55
## Gravity multiplier while rising with jump released (variable height).
@export_range(1.0, 8.0, 0.05) var release_gravity_scale: float = 2.9
## |vy| below which the apex softening applies (m/s).
@export_range(0.0, 6.0, 0.1) var apex_threshold: float = 2.2
## Gravity multiplier at the apex while jump is held.
@export_range(0.1, 1.0, 0.01) var apex_gravity_scale: float = 0.55
## Air-steering multiplier at the apex (subtle landing assist).
@export_range(1.0, 3.0, 0.05) var apex_steer_boost: float = 1.45
## Maximum falling speed (m/s).
@export_range(5.0, 80.0, 0.5) var terminal_velocity: float = 27.0
## Grace period to still jump after walking off a ledge (s).
@export_range(0.0, 0.4, 0.005) var coyote_time: float = 0.12
## Jump presses this early before landing still fire on touchdown (s).
@export_range(0.0, 0.4, 0.005) var jump_buffer_time: float = 0.13

@export_group("Air Control")
@export_range(0.0, 100.0, 0.5) var air_accel: float = 22.0
## Deceleration with no stick input in the air (keeps momentum).
@export_range(0.0, 50.0, 0.5) var air_drag: float = 2.5
## Steering cap; existing faster momentum is preserved, not clamped.
@export_range(1.0, 20.0, 0.1) var air_max_speed: float = 8.5
## Extra deceleration when pulling against momentum in the air.
@export_range(0.0, 100.0, 0.5) var air_brake: float = 26.0
## Facing turn rate in the air (rad/s).
@export_range(0.0, 40.0, 0.5) var air_turn_rate: float = 9.0

@export_group("Long Jump")
@export_range(0.0, 20.0, 0.1) var long_jump_min_speed: float = 4.0
@export_range(1.0, 30.0, 0.1) var long_jump_speed: float = 12.8
@export_range(1.0, 30.0, 0.1) var long_jump_max_speed: float = 15.0
@export_range(0.5, 5.0, 0.05) var long_jump_height: float = 1.75
@export_range(0.15, 1.0, 0.01) var long_jump_time_to_apex: float = 0.37
@export_range(0.0, 60.0, 0.5) var long_jump_air_accel: float = 7.0
## How long crouch counts as "pressed" for run + crouch + jump (s).
@export_range(0.0, 0.5, 0.01) var long_jump_crouch_window: float = 0.18

@export_group("High Jump")
## Crouch + jump while standing: a tall backward flip.
@export_range(0.5, 8.0, 0.05) var high_jump_height: float = 3.5
@export_range(0.0, 10.0, 0.1) var high_jump_back_speed: float = 2.8
## Skid + jump: a tall flip into the new direction.
@export_range(0.5, 8.0, 0.05) var side_flip_height: float = 3.2
@export_range(0.0, 10.0, 0.1) var side_flip_speed: float = 3.6
@export_range(0.0, 60.0, 0.5) var flip_air_accel: float = 10.0

@export_group("Dive")
@export_range(1.0, 30.0, 0.1) var dive_min_speed: float = 10.5
@export_range(0.0, 10.0, 0.1) var dive_speed_bonus: float = 2.5
@export_range(1.0, 30.0, 0.1) var dive_max_speed: float = 14.5
## Upward pop when diving while not already rising (m/s).
@export_range(0.0, 15.0, 0.1) var dive_pop: float = 4.0
@export_range(0.0, 40.0, 0.5) var dive_turn_rate: float = 2.5
@export_range(0.0, 60.0, 0.5) var dive_air_accel: float = 5.0
## Belly-slide friction after landing a dive (m/s²).
@export_range(0.0, 100.0, 0.5) var belly_slide_friction: float = 15.0
@export_range(0.05, 2.0, 0.01) var belly_slide_max_time: float = 0.5
## Jump out of a belly slide (rollout).
@export_range(0.5, 5.0, 0.05) var rollout_height: float = 1.6
@export_range(0.0, 1.5, 0.01) var rollout_speed_keep: float = 0.9
## Bonk when diving into a wall.
@export_range(0.0, 1.0, 0.01) var bonk_time: float = 0.32

@export_group("Roll")
@export_range(1.0, 30.0, 0.1) var roll_speed: float = 10.5
@export_range(0.05, 1.0, 0.01) var roll_time: float = 0.34
@export_range(0.0, 1.0, 0.01) var roll_cooldown: float = 0.22
@export_range(0.0, 40.0, 0.5) var roll_turn_rate: float = 5.0

@export_group("Ground Pound")
## Anticipation hang before the drop (s).
@export_range(0.0, 0.6, 0.01) var ground_pound_hang: float = 0.2
@export_range(5.0, 80.0, 0.5) var ground_pound_speed: float = 32.0
@export_range(0.0, 1.0, 0.01) var ground_pound_recovery: float = 0.2
@export_range(0.1, 6.0, 0.05) var ground_pound_radius: float = 1.7
## Jumping right out of a ground pound landing goes extra high.
@export_range(0.5, 8.0, 0.05) var ground_pound_jump_height: float = 3.9
@export_range(0.0, 1.0, 0.01) var ground_pound_jump_window: float = 0.3

@export_group("Ledge Grab")
## Patchy may grab ledges while rising slower than this (m/s).
@export_range(-5.0, 20.0, 0.1) var ledge_grab_max_rise: float = 4.0
## Ledge height range above the feet that can be grabbed (m).
@export_range(0.0, 3.0, 0.01) var ledge_min_height: float = 0.85
@export_range(0.0, 3.5, 0.01) var ledge_max_height: float = 2.1
## Forward probe reach beyond the capsule radius (m).
@export_range(0.05, 1.5, 0.01) var ledge_reach: float = 0.5
## Feet sit this far below the ledge top while hanging (m).
@export_range(0.5, 2.5, 0.01) var hang_depth: float = 1.55
@export_range(0.05, 1.0, 0.01) var ledge_climb_time: float = 0.3
@export_range(0.0, 8.0, 0.05) var ledge_shimmy_speed: float = 2.2
## Jump straight up out of a hang (m above hang point).
@export_range(0.5, 6.0, 0.05) var ledge_jump_height: float = 2.6
@export_range(0.0, 1.0, 0.01) var ledge_regrab_delay: float = 0.35

@export_group("Wall Kick")
@export_range(0.0, 15.0, 0.1) var wall_slide_speed: float = 4.5
@export_range(0.0, 20.0, 0.1) var wall_kick_away_speed: float = 7.2
@export_range(0.5, 6.0, 0.05) var wall_kick_height: float = 2.2
## Grace window to kick after leaving a wall (s).
@export_range(0.0, 0.4, 0.005) var wall_kick_grace: float = 0.12
## Steering is suppressed this long after a kick so it isn't undone (s).
@export_range(0.0, 0.6, 0.01) var wall_kick_steer_lock: float = 0.16
## Consecutive kicks allowed before touching ground.
@export_range(0, 20) var wall_kick_max_chain: int = 6
## Kicking off a wall facing within this angle (deg) of the previous kick's
## wall is refused, which prevents climbing a single wall forever.
@export_range(0.0, 90.0, 1.0) var wall_kick_same_wall_angle: float = 50.0

@export_group("Landing")
@export_range(0.0, 60.0, 0.5) var landing_normal_speed: float = 10.0
@export_range(0.0, 80.0, 0.5) var landing_heavy_speed: float = 21.0
## Brief speed damping after a heavy landing (never a control lock).
@export_range(0.0, 1.0, 0.01) var heavy_landing_slow_time: float = 0.14
@export_range(0.0, 1.0, 0.01) var heavy_landing_speed_scale: float = 0.45

@export_group("Swimming")
@export_range(0.5, 15.0, 0.1) var swim_speed: float = 4.6
@export_range(0.5, 15.0, 0.1) var underwater_speed: float = 5.2
@export_range(0.5, 60.0, 0.5) var swim_accel: float = 11.0
@export_range(0.0, 60.0, 0.5) var swim_drag: float = 6.0
@export_range(0.0, 20.0, 0.1) var swim_turn_rate: float = 7.0
@export_range(0.0, 10.0, 0.1) var swim_vertical_speed: float = 4.0
## Feet depth below the surface while floating (m).
@export_range(0.2, 2.0, 0.01) var float_depth: float = 1.15
## Water deeper than this at the chest switches to swimming (m).
@export_range(0.2, 2.5, 0.01) var swim_enter_depth: float = 1.05
@export_range(0.5, 6.0, 0.05) var water_jump_height: float = 1.9
## Ground speed multiplier when wading in shallow water.
@export_range(0.2, 1.0, 0.01) var wade_speed_scale: float = 0.72

@export_group("Hook Swing")
@export_range(0.5, 10.0, 0.1) var swing_attach_range: float = 4.6
@export_range(0.5, 10.0, 0.1) var swing_min_rope: float = 1.8
@export_range(0.5, 12.0, 0.1) var swing_max_rope: float = 4.4
@export_range(1.0, 80.0, 0.5) var swing_gravity: float = 30.0
## Tangential pumping acceleration from the stick (m/s²).
@export_range(0.0, 40.0, 0.5) var swing_pump_accel: float = 9.0
@export_range(0.0, 5.0, 0.01) var swing_damping: float = 0.12
@export_range(1.0, 40.0, 0.5) var swing_max_speed: float = 15.0
## Upward kick added when releasing with jump (m/s).
@export_range(0.0, 20.0, 0.1) var swing_release_boost: float = 5.5
## Multiplier on tangential speed at release.
@export_range(0.5, 2.0, 0.01) var swing_release_speed_scale: float = 1.08

@export_group("Attack")
@export_range(0.05, 1.0, 0.01) var swipe_time: float = 0.3
@export_range(0.0, 1.0, 0.01) var swipe_cooldown: float = 0.08
## Small lift the first air swipe gives (m/s, only if falling).
@export_range(0.0, 15.0, 0.1) var air_swipe_lift: float = 3.0
@export_range(0.1, 1.0, 0.01) var swipe_move_scale: float = 0.75

@export_group("Damage")
@export_range(0.0, 3.0, 0.01) var hurt_time: float = 0.42
@export_range(0.0, 5.0, 0.01) var invulnerable_time: float = 1.4
@export_range(0.0, 20.0, 0.1) var knockback_speed: float = 6.5
@export_range(0.0, 20.0, 0.1) var knockback_up: float = 6.0
## Below this world height Patchy is considered lost and respawns.
@export var kill_height: float = -60.0


# --- Derived physics ---------------------------------------------------------

## Rising gravity for a jump of `height` meters reaching apex in `time` s.
static func gravity_for(height: float, time: float) -> float:
	return 2.0 * height / (time * time)


## Launch speed to reach `height` under constant `gravity`.
static func velocity_for(height: float, gravity: float) -> float:
	return sqrt(2.0 * gravity * maxf(height, 0.0))


func get_jump_gravity() -> float:
	return gravity_for(jump_height, jump_time_to_apex)


func get_fall_gravity() -> float:
	return get_jump_gravity() * fall_gravity_scale


func get_jump_velocity(speed_ratio: float = 0.0) -> float:
	return velocity_for(jump_height + jump_speed_bonus_height * clampf(speed_ratio, 0.0, 1.0), get_jump_gravity())


func get_long_jump_gravity() -> float:
	return gravity_for(long_jump_height, long_jump_time_to_apex)
