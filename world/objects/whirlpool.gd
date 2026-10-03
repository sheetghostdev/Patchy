class_name Whirlpool
extends Node3D
## Teacup Isle's whirlpool (docs/ARCHIPELAGO.md): anyone swimming in the tea
## is carried round and drawn in toward the eye; reach it and the swirl
## spins Patchy down through the drain, out of the tea and into the grotto
## below. The node sits at the eye, on the tea's surface.

signal swallowed

## Radius of the tea (where the current reaches).
@export var radius := 20.0
## The eye: get this close and down you go.
@export var eye_radius := 2.4
## Where the drop ends (local y, below the drain, in the air).
@export var drop_to := -4.0
## Current round (m/s at the rim, faster further in) and in toward the eye.
@export var swirl := 2.6
@export var pull := 1.4
@export var spin_time := 1.3

var _sucking := 0.0
var _player: Player
var _from := Vector3.ZERO
var _from_angle := 0.0
var _from_r := 0.0


func _physics_process(delta: float) -> void:
	if _sucking > 0.0:
		_update_suck(delta)
		return
	var p := GameManager.player as Player
	if p == null or p.state_id != &"swim":
		return
	var rel := p.global_position - global_position
	var flat := Vector3(rel.x, 0, rel.z)
	var d := flat.length()
	if d > radius or absf(rel.y) > 3.0:
		return
	if d < eye_radius:
		_start_suck(p)
		return
	var inward := -flat / maxf(d, 0.01)
	var round := Vector3(-inward.z, 0, inward.x)
	var k := 1.0 - d / radius
	p.wind += round * swirl * (0.6 + 1.4 * k) + inward * pull * (1.0 + 2.0 * k)


func _start_suck(p: Player) -> void:
	_player = p
	_sucking = spin_time
	_from = p.global_position
	var rel := p.global_position - global_position
	_from_angle = atan2(rel.z, rel.x)
	_from_r = Vector2(rel.x, rel.z).length()
	p.set_locked(true, {"anim": &"fall"})
	AudioManager.play(&"splash_big", p.global_position)
	AudioManager.play(&"fall_whoosh", p.global_position, 0.0, 1.2)
	swallowed.emit()


func _update_suck(delta: float) -> void:
	_sucking -= delta
	if _player == null or not is_instance_valid(_player):
		_sucking = 0.0
		return
	var t := clampf(1.0 - _sucking / spin_time, 0.0, 1.0)
	# Round and round, in and down the drain.
	var a := _from_angle + t * TAU * 1.5
	var r := lerpf(_from_r, 0.0, t)
	var y := lerpf(0.0, drop_to, t * t)
	_player.global_position = global_position + Vector3(cos(a) * r, y, sin(a) * r)
	_player.velocity = Vector3.ZERO
	_player.facing = Vector3(-sin(a), 0, cos(a))
	if _sucking <= 0.0:
		_player.global_position = global_position + Vector3(0, drop_to, 0)
		_player.set_locked(false)
		_player.velocity = Vector3.DOWN * 2.0
		_player = null
