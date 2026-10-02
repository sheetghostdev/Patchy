extends Node
## Tracks rescued parrots. Parrots are never consumed: every rescue
## permanently raises flock strength, which ParrotTasks compare against.

signal flock_changed(total: int)

var _rescued: Dictionary = {}  # parrot_id (StringName) -> island_id (StringName)
## Known parrot counts per island, registered by levels so the collection
## screen can show "4 / 5" without loading every island.
var _island_totals: Dictionary = {}


func rescue(parrot_id: StringName, island_id: StringName = &"") -> bool:
	if _rescued.has(parrot_id):
		return false
	_rescued[parrot_id] = island_id
	var total := get_total()
	flock_changed.emit(total)
	Events.parrot_rescued.emit(parrot_id, total)
	return true


func is_rescued(parrot_id: StringName) -> bool:
	return _rescued.has(parrot_id)


func get_total() -> int:
	return _rescued.size()


## Flock strength is what parrot tasks check. Currently 1:1 with rescues,
## kept separate so later upgrades (e.g. a parrot whistle) can boost it.
func get_flock_strength() -> int:
	return get_total()


func count_for_island(island_id: StringName) -> int:
	var n := 0
	for id in _rescued:
		if _rescued[id] == island_id:
			n += 1
	return n


func register_island_total(island_id: StringName, total: int) -> void:
	_island_totals[island_id] = total


func get_island_total(island_id: StringName) -> int:
	return int(_island_totals.get(island_id, 0))


## Debug helpers (spec §140).
func debug_add(count: int) -> void:
	var added := 0
	var k := 0
	while added < count:
		if rescue(StringName("debug_parrot_%d" % k), &"debug"):
			added += 1
		k += 1


func debug_remove(count: int) -> void:
	var keys := _rescued.keys()
	keys.reverse()
	for i in mini(count, keys.size()):
		_rescued.erase(keys[i])
	flock_changed.emit(get_total())


func serialize() -> Dictionary:
	var out := {}
	for k in _rescued:
		out[String(k)] = String(_rescued[k])
	return {"rescued": out}


func deserialize(data: Dictionary) -> void:
	_rescued.clear()
	var r: Dictionary = data.get("rescued", {})
	for k in r:
		_rescued[StringName(k)] = StringName(str(r[k]))
	flock_changed.emit(get_total())


func reset() -> void:
	_rescued.clear()
	flock_changed.emit(0)
