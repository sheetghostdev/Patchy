class_name Tide
extends Node
## A tide that raises and lowers the sea (the scene's Ocean, sea_level) a
## couple of meters, slowly coming in and quickly going out. Everything that
## floats or swims reads the Ocean, so boats rise with it and the low reef
## goes under. Bell Atoll's song brings it in; Crabby Coast's Tide Bell
## will swap it (docs/ARCHIPELAGO.md). The sea is one sea, so when its
## island goes to sleep (Patchy sails off: WorldDirector) the tide drops
## straight back out rather than leave every other shore flooded.

signal peaked
signal ebbed

@export var low := 0.0
@export var high := 1.9
## Seconds to come all the way in / go all the way out.
@export var rise_time := 60.0
@export var fall_time := 5.0

## How far in the tide is, 0 (low) to 1 (high).
var level := 0.0
var _dir := 0
var _ocean: Ocean


func _ready() -> void:
	_apply.call_deferred()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED and (level > 0.0 or _dir != 0):
		level = 0.0
		_dir = 0
		_apply()
		ebbed.emit()


## The scene's Ocean (one on its way out after a scene change doesn't count).
func ocean() -> Ocean:
	if _ocean != null and is_instance_valid(_ocean) and not _ocean.is_queued_for_deletion():
		return _ocean
	_ocean = null
	for n in get_tree().get_nodes_in_group(&"ocean"):
		if n is Ocean and not n.is_queued_for_deletion():
			_ocean = n
			break
	return _ocean


func rise() -> void:
	_dir = 1


func fall() -> void:
	_dir = -1


func is_rising() -> bool:
	return _dir > 0


func is_high() -> bool:
	return level >= 1.0


## The sea's height now.
func sea_level() -> float:
	return lerpf(low, high, smoothstep(0.0, 1.0, level))


func _physics_process(delta: float) -> void:
	if _dir == 0:
		return
	var was := level
	level = clampf(level + delta / (rise_time if _dir > 0 else fall_time) * _dir, 0.0, 1.0)
	_apply()
	if level >= 1.0 and was < 1.0:
		_dir = 0
		peaked.emit()
	elif level <= 0.0 and was > 0.0:
		_dir = 0
		ebbed.emit()


func _apply() -> void:
	var o := ocean()
	if o != null:
		o.sea_level = sea_level()
