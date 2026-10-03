extends Node
## Patchy's recovered belongings: treasure, hand attachments, ship parts and
## treasure maps. Three progression tracks (spec §82) live here and in
## ParrotManager; each emits its own Events signal.

signal gold_changed(total_value: int)
signal attachments_changed

## Default unlocks: the hook is Patchy's own hand and is always available.
const STARTING_ATTACHMENTS: Array[StringName] = [&"hook"]

var gold_value: int = 0
var _treasures: Dictionary = {}      # treasure_id -> {kind, value, island}
var _attachments: Array[StringName] = []
var equipped_attachment: StringName = &"hook"
var _ship_parts: Array[StringName] = []
var _maps: Dictionary = {}           # map_id -> {"solved": bool}
## Key items: tools that aren't hook attachments (the Spyglass, the Conch
## Shell, a sheet of sea shanty...).
var _key_items: Array[StringName] = []
## Heart Pieces found (ids); every four make a new heart container.
var _heart_pieces: Array[StringName] = []
var max_health: int = 4
## Unique treasures per island, registered by islands as they load.
var _island_treasure_totals: Dictionary = {}


func _ready() -> void:
	reset()


# --- Treasure ---------------------------------------------------------------

## Unique treasures (gems, chests, relics) pass an id so they never respawn.
## Loose coins pass an empty id and are only counted by value.
func collect_treasure(treasure_id: StringName, kind: StringName, value: int, island_id: StringName = &"", color: Color = Color.WHITE) -> bool:
	if treasure_id != &"":
		if _treasures.has(treasure_id):
			return false
		_treasures[treasure_id] = {"kind": String(kind), "value": value, "island": String(island_id), "color": color.to_html(false)}
	gold_value += value
	gold_changed.emit(gold_value)
	Events.treasure_collected.emit(treasure_id, kind, value)
	return true


func has_treasure(treasure_id: StringName) -> bool:
	return _treasures.has(treasure_id)


## Unique treasures as [{id, kind, value, island, color}], in pickup order.
func get_treasures() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _treasures:
		var t: Dictionary = (_treasures[id] as Dictionary).duplicate()
		t["id"] = String(id)
		out.append(t)
	return out


func count_treasures(kind: StringName = &"", island_id: StringName = &"") -> int:
	var n := 0
	for id in _treasures:
		var t: Dictionary = _treasures[id]
		if kind != &"" and StringName(t.kind) != kind:
			continue
		if island_id != &"" and StringName(t.island) != island_id:
			continue
		n += 1
	return n


func register_island_treasure_total(island_id: StringName, total: int) -> void:
	_island_treasure_totals[island_id] = total


func get_island_treasure_total(island_id: StringName) -> int:
	return int(_island_treasure_totals.get(island_id, 0))


## Gold can be lost on a fall if a design ever wants it (spec §97); keep it
## modest and never below zero.
func lose_gold(amount: int) -> void:
	gold_value = maxi(0, gold_value - amount)
	gold_changed.emit(gold_value)


# --- Attachments --------------------------------------------------------------

func unlock_attachment(id: StringName) -> void:
	if id in _attachments:
		return
	_attachments.append(id)
	attachments_changed.emit()
	Events.attachment_unlocked.emit(id)


func has_attachment(id: StringName) -> bool:
	return id in _attachments


func get_attachments() -> Array[StringName]:
	return _attachments.duplicate()


# --- Ship parts & maps --------------------------------------------------------

func add_ship_part(part_id: StringName) -> void:
	if part_id in _ship_parts:
		return
	_ship_parts.append(part_id)
	Events.ship_part_recovered.emit(part_id)


func has_ship_part(part_id: StringName) -> bool:
	return part_id in _ship_parts


func get_ship_parts() -> Array[StringName]:
	return _ship_parts.duplicate()


func add_treasure_map(map_id: StringName) -> void:
	if _maps.has(map_id):
		return
	_maps[map_id] = {"solved": false}
	Events.treasure_map_found.emit(map_id)


func has_treasure_map(map_id: StringName) -> bool:
	return _maps.has(map_id)


func mark_map_solved(map_id: StringName) -> void:
	if _maps.has(map_id):
		_maps[map_id]["solved"] = true


func get_treasure_maps() -> Dictionary:
	return _maps.duplicate(true)


func add_key_item(item_id: StringName) -> void:
	if item_id in _key_items:
		return
	_key_items.append(item_id)
	Events.key_item_found.emit(item_id)


func has_key_item(item_id: StringName) -> bool:
	return item_id in _key_items


const PIECES_PER_HEART := 4


## Adds a Heart Piece. Returns true when it completes a new heart container
## (max_health goes up by one).
func add_heart_piece(piece_id: StringName) -> bool:
	if piece_id in _heart_pieces:
		return false
	_heart_pieces.append(piece_id)
	if _heart_pieces.size() % PIECES_PER_HEART == 0:
		max_health += 1
		return true
	return false


func has_heart_piece(piece_id: StringName) -> bool:
	return piece_id in _heart_pieces


## Pieces toward the next heart container (0..3).
func heart_pieces_held() -> int:
	return _heart_pieces.size() % PIECES_PER_HEART


func get_key_items() -> Array[StringName]:
	return _key_items.duplicate()


# --- Persistence --------------------------------------------------------------

func serialize() -> Dictionary:
	return {
		"gold_value": gold_value,
		"treasures": _treasures.duplicate(true),
		"attachments": _attachments.map(func(a: StringName) -> String: return String(a)),
		"equipped": String(equipped_attachment),
		"ship_parts": _ship_parts.map(func(a: StringName) -> String: return String(a)),
		"maps": _maps.duplicate(true),
		"key_items": _key_items.map(func(a: StringName) -> String: return String(a)),
		"heart_pieces": _heart_pieces.map(func(a: StringName) -> String: return String(a)),
		"max_health": max_health,
	}


func deserialize(data: Dictionary) -> void:
	reset()
	gold_value = int(data.get("gold_value", 0))
	_treasures = data.get("treasures", {}).duplicate(true)
	for a in data.get("attachments", []):
		if not StringName(a) in _attachments:
			_attachments.append(StringName(a))
	equipped_attachment = StringName(data.get("equipped", "hook"))
	for p in data.get("ship_parts", []):
		_ship_parts.append(StringName(p))
	_maps = data.get("maps", {}).duplicate(true)
	for k in data.get("key_items", []):
		_key_items.append(StringName(k))
	for k in data.get("heart_pieces", []):
		_heart_pieces.append(StringName(k))
	max_health = int(data.get("max_health", 4))
	gold_changed.emit(gold_value)
	attachments_changed.emit()


func reset() -> void:
	gold_value = 0
	_treasures.clear()
	_attachments.clear()
	_attachments.append_array(STARTING_ATTACHMENTS)
	equipped_attachment = &"hook"
	_ship_parts.clear()
	_maps.clear()
	_key_items.clear()
	_heart_pieces.clear()
	max_health = 4
	gold_changed.emit(0)
	attachments_changed.emit()
