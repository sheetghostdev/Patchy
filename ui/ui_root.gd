class_name UIRoot
extends CanvasLayer
## Root of all in-game UI. Register ui/ui_root.tscn as the autoload "UI".
## Survives scene changes; hides the HUD whenever there is no player.
##
## Public API (call as UI.xxx once registered):
##   await UI.show_dialogue("Captain Gull", ["Ahoy!", "Fine hook ye got."])
##   UI.show_subtitle("Squawk! Pretty treasure!", 3.0, "Parrot")   # respects Settings.subtitles
##   UI.show_toast("Bridge repaired!", 2.5, &"check")
##   UI.show_island_title("Crabby Coast", "Welcome back")
##   UI.set_prompt("{interact} Pull", true)       # same as Events.interaction_prompt_changed
##   UI.set_quests([{title = "...", description = "...", done = false}])
##   UI.set_island_totals(&"crabby_coast", {treasure = 35, maps = 2, ship_parts = 1})
##   UI.open_pause_menu(&"map") / UI.close_pause_menu() / UI.is_menu_open()
##   UI.set_hud_hidden(true)   # cutscenes
##   UI.peek_hud(3.0)          # briefly show treasure + parrot counters
##   UI.is_using_gamepad()
## Signals: input_device_changed(gamepad), menu_toggled(open), quests_changed

signal input_device_changed(gamepad: bool)
signal menu_toggled(open: bool)
signal quests_changed

@export_file("*.tscn") var title_scene: String = "res://ui/title/title_screen.tscn"
## Debug menu (F1), quick save/load (F5/F9) only exist in debug builds.
@export var debug_tools_in_debug_builds: bool = true
## Smooth the procedural UI shapes with 2D MSAA on the root viewport.
@export var enable_msaa_2d: bool = true

static var instance: UIRoot

@onready var screen: Control = $Screen
@onready var hud: UIHud = $Screen/HUD
@onready var pause_menu: UIPauseMenu = $Screen/PauseMenu
@onready var debug_menu: UIDebugMenu = $Screen/DebugMenu
@onready var movement_hud: UIMovementHud = $Screen/MovementHUD

var world_draw: UIDebugWorldDraw
var _quests: Array = []
var _island_totals: Dictionary = {}
var _last_scene: Node = null
var _dialogue_busy := false


func _enter_tree() -> void:
	if instance == null:
		instance = self


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen.theme = UIStyle.get_theme()
	if enable_msaa_2d and get_viewport().msaa_2d == Viewport.MSAA_DISABLED:
		get_viewport().msaa_2d = Viewport.MSAA_4X
	InputBindings.load_and_apply()
	UIPrefs.ensure_loaded()
	InputGlyphs.notifier().device_changed.connect(func(pad: bool) -> void: input_device_changed.emit(pad))
	world_draw = UIDebugWorldDraw.new()
	world_draw.name = "DebugWorldDraw"
	add_child(world_draw)
	debug_menu.world_draw = world_draw
	debug_menu.toast_requested.connect(func(text: String, icon: StringName) -> void: show_toast(text, 2.2, icon))
	pause_menu.return_to_title_requested.connect(go_to_title)
	pause_menu.opened.connect(_on_menu_toggled.bind(true))
	pause_menu.closed.connect(_on_menu_toggled.bind(false))
	debug_menu.opened.connect(_on_menu_toggled.bind(true))
	debug_menu.closed.connect(_on_menu_toggled.bind(false))
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	Settings.changed.connect(_on_setting_changed)
	if SceneTransition.has_signal(&"scene_changed"):
		SceneTransition.scene_changed.connect(func(_p: String) -> void: _on_scene_changed())
	movement_hud.visible = Settings.show_movement_hud


# --- Input ---------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	InputGlyphs.observe(event)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed(&"pause"):
		if can_pause():
			get_viewport().set_input_as_handled()
			open_pause_menu()
	elif event.is_action_pressed(&"map"):
		if can_pause():
			get_viewport().set_input_as_handled()
			open_pause_menu(&"map")
	elif event.is_action_pressed(&"debug_hud"):
		get_viewport().set_input_as_handled()
		Settings.set_value(&"show_movement_hud", not Settings.show_movement_hud)
	elif _debug_enabled():
		if event.is_action_pressed(&"debug_menu"):
			if not pause_menu.is_open and (debug_menu.is_open or _has_player()):
				get_viewport().set_input_as_handled()
				debug_menu.toggle()
		elif event.is_action_pressed(&"quick_save") and _has_player():
			get_viewport().set_input_as_handled()
			debug_menu.quick_save()
		elif event.is_action_pressed(&"quick_load") and _has_player():
			get_viewport().set_input_as_handled()
			debug_menu.quick_load()


func _debug_enabled() -> bool:
	return debug_tools_in_debug_builds and OS.is_debug_build()


func _has_player() -> bool:
	return GameManager.player != null and is_instance_valid(GameManager.player)


## Pausing is allowed in gameplay only: a player exists, no transition is
## running, no other menu owns the screen, and the scene isn't in the
## &"no_pause" group (title screen, cutscene rooms).
func can_pause() -> bool:
	if not _has_player() or pause_menu.is_open or debug_menu.is_open:
		return false
	if SceneTransition.is_busy() or get_tree().paused:
		return false
	var cs := get_tree().current_scene
	if cs != null and cs.is_in_group(&"no_pause"):
		return false
	return true


func is_using_gamepad() -> bool:
	return InputGlyphs.using_gamepad


func _on_focus_changed(c: Control) -> void:
	if c != null and (pause_menu.is_open or debug_menu.is_open) and screen.is_ancestor_of(c):
		UIFx.sound(&"ui_move", -4.0)


# --- Menus ---------------------------------------------------------------------------------

func open_pause_menu(page: StringName = &"resume") -> void:
	if debug_menu.is_open:
		debug_menu.close()
	pause_menu.open(page)


func close_pause_menu() -> void:
	pause_menu.close()


func open_map() -> void:
	open_pause_menu(&"map")


func is_menu_open() -> bool:
	return pause_menu.is_open or debug_menu.is_open


func _on_menu_toggled(open: bool) -> void:
	hud.set_menu_open(open)
	menu_toggled.emit(open)


## Closes menus, saves (if configured) and goes back to the title screen.
func go_to_title() -> void:
	if pause_menu.save_on_return_to_title and _has_player():
		SaveManager.save_game()
	var p := GameManager.player
	if p != null and is_instance_valid(p):
		var input: Variant = p.get(&"input")
		if input is Object:
			(input as Object).set(&"enabled", false)
	pause_menu.close()
	debug_menu.close()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	SceneTransition.change_scene(title_scene)


# --- HUD API --------------------------------------------------------------------------------

## Plays a conversation and returns when it ends (awaitable). Emits
## Events.dialogue_started / dialogue_finished. While it runs the player's
## input is disabled (when lock_player) and the interaction prompt hides.
func show_dialogue(speaker: String, lines: Array, lock_player: bool = true) -> void:
	while _dialogue_busy:
		await hud.dialogue.finished
	_dialogue_busy = true
	var player := GameManager.player if _has_player() else null
	var input: Object = null
	if lock_player and player != null:
		input = player.get(&"input") as Object
		if input != null:
			input.set(&"enabled", false)
	hud.prompt.suppressed = true
	Events.dialogue_started.emit(speaker)
	hud.dialogue.start(speaker, lines)
	await hud.dialogue.finished
	hud.prompt.suppressed = false
	Events.dialogue_finished.emit()
	if input != null and is_instance_valid(input):
		# Let the closing press pass before gameplay reads input again.
		await get_tree().physics_frame
		await get_tree().physics_frame
		if is_instance_valid(input):
			input.set(&"enabled", true)
			if input.has_method(&"clear_buffers"):
				input.call(&"clear_buffers")
	_dialogue_busy = false


func is_dialogue_active() -> bool:
	return hud.dialogue.is_active()


## Ambient bark captions; ignored when Settings.subtitles is off.
func show_subtitle(text: String, duration: float = 3.0, speaker: String = "") -> void:
	hud.subtitles.show_subtitle(text, duration, speaker)


func show_toast(text: String, duration: float = 2.6, icon: StringName = &"") -> void:
	hud.toasts.show_toast(text, duration, icon)


func show_island_title(display_name: String, kicker: String = "Now Exploring") -> void:
	hud.banner.show_title(display_name, kicker)


func set_prompt(prompt: String, enabled: bool = true) -> void:
	hud.prompt.push(prompt, enabled)


func set_hud_hidden(hidden: bool) -> void:
	hud.set_forced_hidden(hidden)


func peek_hud(duration: float = 3.0) -> void:
	hud.peek(duration)


# --- Data for menus ----------------------------------------------------------------------------

## Quest log entries: Array of {title: String, description: String, done: bool}.
func set_quests(quests: Array) -> void:
	_quests = quests.duplicate(true)
	quests_changed.emit()


func get_quests() -> Array:
	return _quests.duplicate(true)


## Known collectible totals for an island (keys: parrots, treasure, maps,
## ship_parts). Unknown keys show "?" in the collection screen.
func set_island_totals(island_id: StringName, totals: Dictionary) -> void:
	_island_totals[island_id] = totals.duplicate()


func get_island_totals(island_id: StringName) -> Dictionary:
	return (_island_totals.get(island_id, {}) as Dictionary).duplicate()


# --- Housekeeping ------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var cs := get_tree().current_scene
	if cs != _last_scene:
		_last_scene = cs
		_on_scene_changed()


func _on_scene_changed() -> void:
	# Transient UI never leaks between scenes.
	hud.prompt.clear()
	hud.requirement.set_requirement(0, 0, false)
	hud.subtitles.clear()
	if hud.dialogue.is_active():
		hud.dialogue.skip_all()
	if pause_menu.is_open:
		pause_menu.close()
	if debug_menu.is_open:
		debug_menu.close()


func _on_setting_changed(key: StringName) -> void:
	if key == &"show_movement_hud":
		movement_hud.visible = Settings.show_movement_hud
