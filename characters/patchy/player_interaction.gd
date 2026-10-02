class_name PlayerInteraction
extends Node
## Chooses which Interactable Patchy would use right now (closest, roughly in
## front, highest priority), keeps the HUD prompt in sync through Events, and
## triggers it when its action is pressed. Interactions never require pixel
## precision (spec §134).

@export var sensor: Area3D

var current: Interactable = null
var _p: Player
var _last_prompt := ""


func _ready() -> void:
	_p = get_parent() as Player
	if sensor != null:
		sensor.collision_layer = 0
		sensor.collision_mask = Layers.INTERACTABLE
		sensor.monitorable = false


func update(_delta: float) -> void:
	if current != null and not is_instance_valid(current):
		current = null
	var best := _pick()
	if best != current:
		if current != null and is_instance_valid(current):
			current.on_unfocus()
		current = best
		if current != null:
			current.on_focus(_p)
		_last_prompt = "~"
	# Prompts can change while focused (e.g. "Open" -> "Take").
	var text := current.get_prompt() if current != null else ""
	if text != _last_prompt:
		_last_prompt = text
		Events.interaction_prompt_changed.emit(text, current != null)
	if current != null and _p.input.is_buffered(current.action, 0.12):
		_p.input.consume(current.action)
		current.interact(_p)


func _allowed() -> bool:
	return _p.state_id in [&"ground", &"swim"] and not _p.combat.is_swiping()


func _pick() -> Interactable:
	if sensor == null or not _allowed():
		return null
	var best: Interactable = null
	var best_score := INF
	for area in sensor.get_overlapping_areas():
		var it := area as Interactable
		if it == null or not it.can_interact(_p):
			continue
		var to := Player.flat(it.get_focus_point() - _p.global_position)
		var dist := to.length()
		var facing_dot := _p.facing.dot(to.normalized()) if dist > 0.05 else 1.0
		if facing_dot < it.min_facing:
			continue
		var score := dist * (1.6 - facing_dot * 0.6) - it.interact_priority * 10.0
		if score < best_score:
			best_score = score
			best = it
	return best


## Clears focus (used when Patchy is locked by a cutscene).
func clear() -> void:
	if current != null and is_instance_valid(current):
		current.on_unfocus()
	current = null
	_last_prompt = ""
	Events.interaction_prompt_changed.emit("", false)
