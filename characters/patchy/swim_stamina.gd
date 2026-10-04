class_name SwimStamina
extends Node
## How far Patchy can swim (docs/ARCHIPELAGO.md, the open sea). In an
## island's own waters (a SeaRegion with an island) swimming is free; out
## past them, in the open sea, his breath runs down: `open_sea_time`
## seconds of swimming and he goes under, a heart down and back on the last
## safe ground (PlayerHealth.go_under). It comes back quickly once he's in
## island waters again, ashore or in his boat. The islands are a boat's
## sail apart, not a swim. The HUD draws it as a ring by Patchy
## (UISwimMeter) while it's anything but full.

signal went_under

## Seconds of open-sea swimming from full breath.
@export_range(1.0, 60.0, 0.5) var open_sea_time := 6.0
## Seconds to get it all back.
@export_range(0.2, 10.0, 0.1) var refill_time := 1.5

## Breath left, 0..1.
var value := 1.0
## Running down right now (out at sea, swimming).
var draining := false

var _p: Player


func _ready() -> void:
	_p = get_parent() as Player


func _physics_process(delta: float) -> void:
	if _p == null or _p.health == null or _p.health.is_respawning():
		draining = false
		return
	draining = _p.state_id == &"swim" and not in_island_waters(_p.global_position)
	if not draining:
		value = minf(value + delta / refill_time, 1.0)
		return
	value = maxf(value - delta / open_sea_time, 0.0)
	if value <= 0.0:
		draining = false
		went_under.emit()
		await _p.health.go_under()
		value = 1.0


## Inside some island's own waters (or anywhere, where there are none: the
## labs and test arenas).
static func in_island_waters_of(tree: SceneTree, pos: Vector3) -> bool:
	var any := false
	for n in tree.get_nodes_in_group(&"sea_region"):
		var r := n as SeaRegion
		if r == null:
			continue
		any = true
		if r.island_id != &"" and r.contains(pos):
			return true
	return not any


func in_island_waters(pos: Vector3) -> bool:
	return in_island_waters_of(get_tree(), pos)
