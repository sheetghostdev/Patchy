extends Node
## Versioned JSON save slots (spec §127). Each subsystem serializes itself;
## this node only gathers, writes and distributes. Settings are stored
## separately by the Settings autoload.

signal saved(slot: int)
signal loaded(slot: int)
## Emitted when an autosave is about to be written (HUD shows a quiet icon).
signal autosaving

const SAVE_VERSION := 1
const SLOT_COUNT := 3
## Several progress events often land together (cage + stinger + treasure);
## they coalesce into one write.
const AUTOSAVE_DELAY := 0.8

var current_slot: int = 0
## Only a real play session (title screen -> New Game / Continue) autosaves;
## labs, tests and the photo tool never touch the player's slots.
var autosave_enabled := false
var _autosave_queued := false


func _ready() -> void:
	Events.checkpoint_reached.connect(func(_id: StringName) -> void: request_autosave())
	Events.parrot_rescued.connect(func(_id: StringName, _t: int) -> void: request_autosave())
	Events.ship_part_recovered.connect(func(_id: StringName) -> void: request_autosave())
	Events.treasure_map_found.connect(func(_id: StringName) -> void: request_autosave())
	Events.world_task_completed.connect(func(_id: StringName) -> void: request_autosave())
	Events.attachment_unlocked.connect(func(_id: StringName) -> void: request_autosave())
	Events.boss_defeated.connect(func(_id: StringName) -> void: request_autosave())
	Events.island_discovered.connect(func(_id: StringName, _n: String) -> void: request_autosave())
	Events.treasure_collected.connect(func(id: StringName, _k: StringName, _v: int) -> void:
		if id != &"":
			request_autosave())


func request_autosave() -> void:
	if not autosave_enabled or _autosave_queued:
		return
	_autosave_queued = true
	await get_tree().create_timer(AUTOSAVE_DELAY, true).timeout
	_autosave_queued = false
	if autosave_enabled:
		autosaving.emit()
		save_game(current_slot)


func get_slot_path(slot: int) -> String:
	return "user://save_slot_%d.json" % slot


func slot_exists(slot: int) -> bool:
	return FileAccess.file_exists(get_slot_path(slot))


func save_game(slot: int = current_slot) -> bool:
	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"game": GameManager.serialize(),
		"world": WorldState.serialize(),
		"parrots": ParrotManager.serialize(),
		"inventory": InventoryManager.serialize(),
	}
	var tmp_path := get_slot_path(slot) + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot write %s (%s)" % [tmp_path, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	# Write-then-rename so a crash mid-save never corrupts the previous save.
	var dir := DirAccess.open("user://")
	if dir.file_exists(get_slot_path(slot).get_file()):
		dir.remove(get_slot_path(slot).get_file())
	var err := dir.rename(tmp_path.get_file(), get_slot_path(slot).get_file())
	if err != OK:
		push_error("SaveManager: rename failed (%s)" % error_string(err))
		return false
	current_slot = slot
	saved.emit(slot)
	return true


func load_game(slot: int = current_slot) -> bool:
	var path := get_slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("SaveManager: slot %d is corrupt" % slot)
		return false
	var data: Dictionary = _migrate(parsed)
	WorldState.deserialize(data.get("world", {}))
	ParrotManager.deserialize(data.get("parrots", {}))
	InventoryManager.deserialize(data.get("inventory", {}))
	GameManager.deserialize(data.get("game", {}))
	current_slot = slot
	loaded.emit(slot)
	return true


func new_game(slot: int = 0) -> void:
	current_slot = slot
	delete_slot(slot)
	WorldState.reset()
	ParrotManager.reset()
	InventoryManager.reset()
	GameManager.reset()


func delete_slot(slot: int) -> void:
	if slot_exists(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(get_slot_path(slot)))


## Upgrade older save formats in place. Add a branch per version bump.
func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 0))
	if v > SAVE_VERSION:
		push_warning("SaveManager: save is from a newer version (%d)" % v)
	return data
