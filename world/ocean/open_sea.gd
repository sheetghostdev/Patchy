class_name OpenSea
extends Node
## The open sea between islands (spec §75): a current pushes swimmers back
## toward the nearest island's SeaRegion, with a hint that Patchy needs a
## boat. The push grows with distance so it reads as a current, not a wall.

@export_range(0.0, 20.0, 0.1) var base_push := 2.2
@export_range(0.0, 5.0, 0.05) var push_per_meter := 0.8
@export_range(0.0, 30.0, 0.1) var max_push := 7.5
@export var hint := "The current's too strong to swim out here... Patchy needs a boat!"

var _hint_cooldown := 0.0


func _physics_process(delta: float) -> void:
	_hint_cooldown = maxf(_hint_cooldown - delta, 0.0)
	var p := GameManager.player as Player
	if p == null or p.state_id != &"swim":
		return
	var nearest: SeaRegion = null
	var best := INF
	for n in get_tree().get_nodes_in_group(&"sea_region"):
		var r := n as SeaRegion
		var e := r.excess(p.global_position)
		if e <= 0.0:
			return
		if e < best:
			best = e
			nearest = r
	if nearest == null:
		return
	var to := Player.flat(nearest.global_position - p.global_position).normalized()
	var push := minf(base_push + best * push_per_meter, max_push)
	p.global_position += to * push * delta
	if _hint_cooldown <= 0.0:
		_hint_cooldown = 10.0
		Events.hud_message.emit(hint, 3.0)
