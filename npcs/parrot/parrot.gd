class_name Parrot
extends Node3D
## A parrot actor: perches and hops in cages, orbits Patchy when freed,
## flies to points, carries things for parrot tasks and flies away. Purely
## presentational; progression lives in ParrotManager.

signal arrived

enum Mode { PERCH, FLY_TO, ORBIT, FLY_AWAY, CARRY }

@export var plumage := ParrotModel.Plumage.SCARLET
@export var chirps := true

var mode := Mode.PERCH
var target := Vector3.ZERO
var speed := 8.0
var orbit_center: Node3D
var orbit_radius := 1.4
var orbit_height := 2.0
var velocity := Vector3.ZERO
var model: ParrotModel

var _t := 0.0
var _orbit_angle := 0.0
var _chirp_t := 2.0
var _arrived := false
var _away_t := 0.0
var _hop := 0.0
var _yaw := 0.0


func _ready() -> void:
	model = ParrotModel.new()
	model.plumage = plumage
	add_child(model)
	model.set_folded()
	_t = randf() * 10.0
	_orbit_angle = randf() * TAU


func fly_to(pos: Vector3, fly_speed: float = 8.0) -> void:
	target = pos
	speed = fly_speed
	_arrived = false
	mode = Mode.FLY_TO


func orbit(center: Node3D, radius: float = 1.4, height: float = 2.0) -> void:
	orbit_center = center
	orbit_radius = radius
	orbit_height = height
	mode = Mode.ORBIT


func fly_away(direction: Vector3 = Vector3.ZERO) -> void:
	if direction == Vector3.ZERO:
		direction = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
	velocity = velocity.lerp(direction * 4.0 + Vector3.UP * 6.0, 0.5)
	_away_t = 0.0
	mode = Mode.FLY_AWAY


func _process(delta: float) -> void:
	_t += delta
	match mode:
		Mode.PERCH:
			_hop = maxf(_hop - delta * 4.0, 0.0)
			if randf() < delta * 0.5:
				_hop = 1.0
			model.position.y = sin(_hop * PI) * 0.08
			model.head.rotation.y = sin(_t * 0.9) * 0.6
			model.head.rotation.x = sin(_t * 1.7) * 0.15
			if randf() < delta * 0.25:
				model.set_flap(1.0)
			else:
				model.set_folded()
			_maybe_chirp(delta, 4.0)
			return
		Mode.FLY_TO, Mode.CARRY:
			var to := target - global_position
			var d := to.length()
			var desired := to.normalized() * speed * clampf(d / 1.5, 0.15, 1.0) if d > 0.01 else Vector3.ZERO
			velocity = velocity.lerp(desired, 1.0 - exp(-delta * 5.0))
			global_position += velocity * delta
			if d < 0.25 and not _arrived:
				_arrived = true
				arrived.emit()
		Mode.ORBIT:
			if orbit_center == null or not is_instance_valid(orbit_center):
				fly_away()
				return
			_orbit_angle += delta * 3.2
			var goal := orbit_center.global_position + Vector3(cos(_orbit_angle) * orbit_radius, orbit_height + sin(_t * 4.0) * 0.2, sin(_orbit_angle) * orbit_radius)
			velocity = (goal - global_position) / maxf(delta, 0.001) * 0.15
			global_position = global_position.lerp(goal, 1.0 - exp(-delta * 8.0))
			_maybe_chirp(delta, 1.2)
		Mode.FLY_AWAY:
			_away_t += delta
			velocity += (Vector3.UP * 4.0 + Player.flat(velocity).normalized() * 3.0) * delta
			global_position += velocity * delta
			if _away_t > 4.0:
				queue_free()
				return
	# Flight presentation: fast flaps, face travel direction, bank into turns.
	var flap_rate := 30.0 if mode == Mode.CARRY else 22.0
	model.set_flap(sin(_t * flap_rate))
	var hv := Player.flat(velocity)
	if hv.length() > 0.3:
		var goal_yaw := Player.yaw_of(hv.normalized())
		var turn := angle_difference(_yaw, goal_yaw)
		_yaw = lerp_angle(_yaw, goal_yaw, 1.0 - exp(-delta * 6.0))
		model.rotation = Vector3(clampf(-velocity.y * 0.06, -0.5, 0.5), _yaw, clampf(-turn * 1.5, -0.7, 0.7))
	if mode == Mode.CARRY:
		model.position.y = sin(_t * 9.0) * 0.06


func _maybe_chirp(delta: float, interval: float) -> void:
	if not chirps:
		return
	_chirp_t -= delta
	if _chirp_t <= 0.0:
		_chirp_t = interval * randf_range(0.7, 1.6)
		AudioManager.play(&"parrot_chirp", global_position, -4.0, randf_range(0.9, 1.25), 0.0)
