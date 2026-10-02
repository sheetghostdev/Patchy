@tool
class_name CameraSettings
extends Resource
## Every camera tuning value (spec §162). The rig never hard-codes feel.
## Angles are degrees, distances meters, times seconds (smoothing times are
## roughly "time to close ~63% of the gap").

@export_group("Framing")
@export_range(1.0, 20.0, 0.1) var distance: float = 5.9
@export_range(0.3, 5.0, 0.05) var min_distance: float = 0.9
## Height above Patchy's feet the camera looks at (upper torso).
@export_range(0.0, 3.0, 0.05) var target_height: float = 1.35
@export_range(-89.0, 0.0, 0.5) var default_pitch: float = -15.0
@export_range(-89.0, 0.0, 0.5) var pitch_min: float = -72.0
@export_range(-30.0, 89.0, 0.5) var pitch_max: float = 38.0
## Vertical field of view.
@export_range(30.0, 100.0, 0.5) var fov: float = 58.0

@export_group("Manual Control")
@export_range(10.0, 720.0, 1.0) var yaw_speed: float = 210.0
@export_range(10.0, 720.0, 1.0) var pitch_speed: float = 130.0
## How fast stick camera rotation ramps up/down (deg/s²).
@export_range(50.0, 6000.0, 10.0) var stick_acceleration: float = 1100.0
@export_range(1.0, 3.0, 0.05) var stick_response_exponent: float = 1.6
## Degrees per mouse pixel at sensitivity 1.0.
@export_range(0.01, 1.0, 0.005) var mouse_sensitivity: float = 0.13
@export_range(0.1, 3.0, 0.05) var controller_sensitivity: float = 1.0

@export_group("Follow")
@export_range(0.0, 0.5, 0.005) var horizontal_follow_time: float = 0.05
## While airborne, Patchy may rise this far above the tracked height before
## the camera starts to climb (reduces jump bounce; spec §39).
@export_range(0.0, 5.0, 0.05) var dead_zone_up: float = 1.6
## ...and drop this far below before the camera follows down.
@export_range(0.0, 5.0, 0.05) var dead_zone_down: float = 0.7
@export_range(0.0, 2.0, 0.01) var grounded_vertical_time: float = 0.14
@export_range(0.0, 2.0, 0.01) var airborne_vertical_time: float = 0.09

@export_group("Look Ahead")
## Max framing shift toward the movement direction at full speed (spec §41).
@export_range(0.0, 5.0, 0.05) var look_ahead_distance: float = 1.3
@export_range(0.0, 20.0, 0.1) var look_ahead_min_speed: float = 4.0
@export_range(0.01, 3.0, 0.01) var look_ahead_time: float = 0.55
## Fraction of look-ahead applied when running toward the camera.
@export_range(0.0, 1.0, 0.05) var look_ahead_toward_camera: float = 0.3

@export_group("Speed Response")
## Speed at which the speed-based distance/FOV bonuses are fully applied.
@export_range(1.0, 30.0, 0.1) var fast_speed: float = 12.0
@export_range(0.0, 5.0, 0.05) var speed_distance_bonus: float = 0.9
@export_range(0.0, 20.0, 0.5) var speed_fov_bonus: float = 4.0
## Extra FOV during long jumps, dives and grapples (spec §163).
@export_range(0.0, 20.0, 0.5) var action_fov_bonus: float = 4.0
@export_range(0.01, 3.0, 0.01) var distance_time: float = 0.6
@export_range(0.01, 3.0, 0.01) var fov_time: float = 0.45

@export_group("Collision")
@export_range(0.05, 1.0, 0.01) var probe_radius: float = 0.3
## Obstructions pull the camera in immediately; clearing them waits this
## long before easing back out (spec §36: never snap outward).
@export_range(0.0, 2.0, 0.01) var return_delay: float = 0.3
@export_range(0.01, 3.0, 0.01) var return_time: float = 0.45

@export_group("Auto Assist")
## Seconds after manual input before any automatic rotation resumes.
@export_range(0.0, 10.0, 0.05) var auto_align_delay: float = 1.1
## Yaw rate (deg/s) per m/s of sideways running: the camera gently swings
## behind Patchy when he runs across the screen (spec §37).
@export_range(0.0, 30.0, 0.1) var auto_align_strength: float = 5.0
@export_range(0.0, 360.0, 1.0) var auto_align_max_rate: float = 80.0
@export_range(0.0, 10.0, 0.05) var auto_pitch_delay: float = 1.5
@export_range(0.01, 5.0, 0.01) var auto_pitch_time: float = 1.1
## Extra downward pitch after falling for a while (see the landing).
@export_range(-45.0, 0.0, 0.5) var fall_pitch: float = -14.0
## Pitch change per degree of slope when walking up/down hills.
@export_range(0.0, 1.0, 0.01) var slope_pitch_scale: float = 0.35

@export_group("Recenter")
@export_range(0.05, 1.0, 0.01) var recenter_time: float = 0.22

@export_group("Swing")
@export_range(0.0, 5.0, 0.05) var swing_distance_bonus: float = 1.5
## How strongly the camera aligns behind the swing direction (1/s).
@export_range(0.0, 10.0, 0.05) var swing_yaw_follow: float = 1.8
## Vertical framing blend toward the anchor to calm pendulum bobbing.
@export_range(0.0, 1.0, 0.01) var swing_anchor_blend: float = 0.35

@export_group("Swimming")
@export_range(-89.0, 0.0, 0.5) var underwater_pitch_min: float = -80.0
@export_range(0.0, 89.0, 0.5) var underwater_pitch_max: float = 75.0
@export_range(0.0, 3.0, 0.05) var underwater_target_height: float = 0.7

@export_group("Shake")
@export_range(0.0, 15.0, 0.1) var shake_max_yaw: float = 2.2
@export_range(0.0, 15.0, 0.1) var shake_max_pitch: float = 2.2
@export_range(0.0, 15.0, 0.1) var shake_max_roll: float = 3.0
@export_range(0.1, 10.0, 0.05) var shake_decay: float = 1.8
@export_range(1.0, 60.0, 0.5) var shake_frequency: float = 24.0
