extends Node
## Persistent state for world objects, keyed by stable string IDs such as
## "castaway_bridge_01" (never node paths). Objects read their state on load
## through a PersistentState component and write back when they change.

signal state_changed(id: StringName, state: Dictionary)

var _states: Dictionary = {}  # StringName -> Dictionary


func has_state(id: StringName) -> bool:
	return _states.has(id)


func get_state(id: StringName) -> Dictionary:
	return _states.get(id, {})


func set_state(id: StringName, state: Dictionary) -> void:
	if id == &"":
		push_error("WorldState: refusing to store state with an empty id")
		return
	_states[id] = state.duplicate(true)
	state_changed.emit(id, _states[id])


func set_flag(id: StringName, key: String, value: Variant) -> void:
	var s: Dictionary = get_state(id).duplicate(true)
	s[key] = value
	set_state(id, s)


func get_flag(id: StringName, key: String, default: Variant = null) -> Variant:
	return get_state(id).get(key, default)


func is_completed(id: StringName) -> bool:
	return bool(get_flag(id, "completed", false))


func mark_completed(id: StringName) -> void:
	set_flag(id, "completed", true)


func serialize() -> Dictionary:
	var out := {}
	for k in _states:
		out[String(k)] = _states[k]
	return out


func deserialize(data: Dictionary) -> void:
	_states.clear()
	for k in data:
		if data[k] is Dictionary:
			_states[StringName(k)] = data[k]


func reset() -> void:
	_states.clear()
