class_name PlayerHealth
extends Node
## Forgiving health (spec §95–97): a few hearts, knockback with brief
## invulnerability, falls respawn at the last safe spot for one heart, and
## running out of hearts returns Patchy to the last checkpoint.

signal health_changed(health: int, max_health: int)
signal died

var health := 4
var max_health := 4
var invulnerable_timer := 0.0
## Debug toggle (spec §140).
var invincible := false

var _p: Player
var _respawning := false


func _ready() -> void:
	_p = get_parent() as Player
	max_health = InventoryManager.max_health
	health = max_health


func _physics_process(delta: float) -> void:
	invulnerable_timer = maxf(invulnerable_timer - delta, 0.0)


func is_flashing() -> bool:
	return invulnerable_timer > 0.0 and not _respawning


func is_respawning() -> bool:
	return _respawning


## Returns true if the hit was taken.
func take_damage(amount: int, from_position: Vector3) -> bool:
	if invincible or invulnerable_timer > 0.0 or _respawning:
		return false
	if not _p.state.can_be_hurt():
		return false
	health = maxi(health - amount, 0)
	invulnerable_timer = _p.settings.invulnerable_time
	health_changed.emit(health, max_health)
	Events.player_damaged.emit(amount, health)
	Events.camera_impulse.emit(0.35)
	AudioManager.play(&"hurt", _p.global_position)
	if health <= 0:
		die()
		return true
	_p.change_state(&"hurt", {"direction": Player.flat(_p.global_position - from_position)})
	return true


func heal(amount: int) -> void:
	var before := health
	health = mini(health + amount, max_health)
	if health != before:
		health_changed.emit(health, max_health)
		Events.player_healed.emit(health - before, health)


func refill() -> void:
	max_health = InventoryManager.max_health
	health = max_health
	health_changed.emit(health, max_health)


## Fell into a pit / kill volume: quick wipe, back to the last safe ground.
func fall_out() -> void:
	if _respawning:
		return
	if not invincible:
		health = maxi(health - 1, 0)
		health_changed.emit(health, max_health)
		Events.player_damaged.emit(1, health)
	if health <= 0:
		die()
		return
	_respawning = true
	AudioManager.play(&"fall_whoosh")
	_p.set_locked(true, {"anim": &"fall"})
	await SceneTransition.fade_out(0.3)
	_p.teleport(_p.safe_position, _p.safe_facing)
	await get_tree().create_timer(0.12).timeout
	AudioManager.play(&"respawn_poof", _p.global_position)
	await SceneTransition.fade_in(0.35)
	invulnerable_timer = 1.0
	_respawning = false
	Events.player_respawned.emit(_p.global_position)


func die() -> void:
	if _respawning and health > 0:
		return
	_respawning = true
	died.emit()
	Events.player_died.emit()
	_p.set_locked(true, {"anim": &"hurt"})
	await get_tree().create_timer(0.7).timeout
	await SceneTransition.fade_out(0.45)
	var xf := GameManager.get_checkpoint_transform()
	_p.teleport(xf.origin, -xf.basis.z)
	refill()
	await get_tree().create_timer(0.15).timeout
	AudioManager.play(&"respawn_poof", _p.global_position)
	await SceneTransition.fade_in(0.45)
	invulnerable_timer = 1.5
	_respawning = false
	Events.player_respawned.emit(_p.global_position)
