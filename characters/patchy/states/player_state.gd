class_name PlayerState
extends RefCounted
## Base class for Patchy's movement states. A state owns movement for the
## ticks it is active: it reads input through `p.input`, sets `p.velocity`,
## calls `p.move()` at most once per tick, and requests transitions with
## `p.change_state()`. Shared physics lives on Player so states stay small.

var p: Player
var s: PlayerMovementSettings
var id: StringName


func setup(player: Player, state_id: StringName) -> void:
	p = player
	s = player.settings
	id = state_id


func enter(_previous: StringName, _msg: Dictionary) -> void:
	pass


func exit(_next: StringName) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## Whether the swipe attack may start during this state.
func can_attack() -> bool:
	return false


## Whether taking damage may interrupt this state.
func can_be_hurt() -> bool:
	return true
