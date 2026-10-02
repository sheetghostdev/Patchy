@tool
class_name MovingPlatform
extends AnimatableBody3D
## Code-driven moving platform (spec §31). Patchy inherits its velocity
## through CharacterBody3D platform handling; motion is evaluated from time so
## it is deterministic and never drifts.

enum Mode { PING_PONG, LOOP, ROTATE }

@export var mode := Mode.PING_PONG
## Offsets from the start position visited in order (PING_PONG / LOOP).
@export var waypoints: PackedVector3Array = PackedVector3Array([Vector3(0, 0, 0), Vector3(6, 0, 0)])
@export_range(0.1, 30.0, 0.1) var speed := 3.0
## Pause at each waypoint (s).
@export_range(0.0, 10.0, 0.05) var wait_time := 0.6
## ROTATE: degrees per second around `rotate_axis`.
@export var rotate_axis := Vector3.UP
@export_range(-360.0, 360.0, 1.0) var rotate_speed := 30.0
@export var active := true
## Start offset in seconds, so neighboring platforms don't move in lockstep.
@export var time_offset := 0.0

var _origin := Transform3D.IDENTITY
var _t := 0.0
var _segments: Array[float] = []
var _total := 0.0


func _ready() -> void:
	sync_to_physics = true
	_origin = global_transform
	_t = time_offset
	_build_timeline()


func _build_timeline() -> void:
	_segments.clear()
	_total = 0.0
	var pts := _route()
	for i in pts.size() - 1:
		var d := (pts[i + 1] - pts[i]).length() / maxf(speed, 0.01)
		_segments.append(d)
		_total += d + wait_time


func _route() -> PackedVector3Array:
	var pts := waypoints.duplicate()
	if mode == Mode.PING_PONG and pts.size() > 1:
		for i in range(pts.size() - 2, -1, -1):
			pts.append(pts[i])
	elif mode == Mode.LOOP and pts.size() > 1:
		pts.append(pts[0])
	return pts


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not active:
		return
	_t += delta
	if mode == Mode.ROTATE:
		var angle := deg_to_rad(rotate_speed) * _t
		global_transform = Transform3D(Basis(rotate_axis.normalized(), angle) * _origin.basis, _origin.origin)
		return
	global_transform = Transform3D(_origin.basis, _origin.origin + _origin.basis * _offset_at(_t))


func _offset_at(t: float) -> Vector3:
	var pts := _route()
	if pts.size() < 2 or _total <= 0.0:
		return pts[0] if pts.size() > 0 else Vector3.ZERO
	t = fmod(t, _total)
	for i in _segments.size():
		if t < wait_time:
			return pts[i]
		t -= wait_time
		var seg := _segments[i]
		if t < seg:
			var k := smoothstep(0.0, 1.0, t / seg) if wait_time > 0.0 else t / seg
			return pts[i].lerp(pts[i + 1], k)
		t -= seg
	return pts[pts.size() - 1]
