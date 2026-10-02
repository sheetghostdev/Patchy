class_name UITitleScreen
extends Control
## Title screen: animated seascape, wobbling PATCHY logo and the main menu
## (New Game / Continue / Settings / Quit). Continue is enabled only when
## save slot 0 exists and loads the island the player was on.

## First level for a new game; falls back to `fallback_scene` if missing.
@export_file("*.tscn") var start_scene: String = "res://world/islands/castaway_cay/castaway_cay.tscn"
@export_file("*.tscn") var fallback_scene: String = "res://tests/scenes/movement_test.tscn"
## Optional music track name from the audio manifest ("" = none).
@export var title_music: StringName = &""
@export var subtitle: String = "A Hook-Handed Island Adventure"

var _logo: UITitleLogo
var _ribbon: UIRibbon
var _ribbon_label: Label
var _menu: VBoxContainer
var _buttons: Dictionary = {}
var _settings_overlay: Control
var _settings: UISettingsPanel
var _confirm: UIConfirmDialog
var _busy := false


func _ready() -> void:
	add_to_group(&"no_pause")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UIStyle.get_theme()
	get_tree().paused = false
	Engine.time_scale = 1.0
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if UIRoot.instance == null:
		InputBindings.load_and_apply()
	_build()
	_intro()
	if title_music != &"":
		AudioManager.play_music(title_music)


func _build() -> void:
	var bg := UITitleBackground.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_logo = UITitleLogo.new()
	_logo.anchor_left = 0.5
	_logo.anchor_right = 0.5
	_logo.offset_left = -560.0
	_logo.offset_right = 560.0
	_logo.offset_top = 70.0
	_logo.offset_bottom = 330.0
	add_child(_logo)
	UIFx.prepare(_logo)

	_ribbon = UIRibbon.new()
	_ribbon.anchor_left = 0.5
	_ribbon.anchor_right = 0.5
	_ribbon.offset_left = -390.0
	_ribbon.offset_right = 390.0
	_ribbon.offset_top = 322.0
	_ribbon.offset_bottom = 418.0
	_ribbon.tail = 58.0
	_ribbon.drop = 16.0
	_ribbon.sag = 6.0
	_ribbon.studs = false
	add_child(_ribbon)
	UIFx.prepare(_ribbon)
	_ribbon_label = Label.new()
	_ribbon_label.text = subtitle
	_ribbon_label.theme_type_variation = &"SubheaderLabel"
	_ribbon_label.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	_ribbon_label.add_theme_font_size_override(&"font_size", 31)
	_ribbon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ribbon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_ribbon_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ribbon_label.offset_bottom = -22.0
	_ribbon.add_child(_ribbon_label)

	_menu = VBoxContainer.new()
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_top = 1.0
	_menu.anchor_bottom = 1.0
	_menu.offset_left = -230.0
	_menu.offset_right = 230.0
	_menu.offset_top = -560.0
	_menu.offset_bottom = -110.0
	_menu.add_theme_constant_override(&"separation", 18)
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_menu)
	_add_button(&"new", "New Game", _on_new_game)
	_add_button(&"continue", "Continue", _on_continue)
	_add_button(&"settings", "Settings", _open_settings)
	_add_button(&"quit", "Quit", _on_quit)
	(_buttons[&"continue"] as Button).disabled = not SaveManager.slot_exists(0)
	if OS.has_feature("web"):
		(_buttons[&"quit"] as Button).visible = false

	var hints := UIPromptRow.new()
	hints.prompt = "{ui_accept} Select"
	hints.label_variation = &"HintText"
	hints.glyph_height = 40.0
	hints.alignment = BoxContainer.ALIGNMENT_BEGIN
	hints.anchor_top = 1.0
	hints.anchor_bottom = 1.0
	hints.offset_left = 40.0
	hints.offset_top = -78.0
	hints.offset_bottom = -30.0
	hints.offset_right = 600.0
	add_child(hints)
	var version := Label.new()
	version.theme_type_variation = &"HintText"
	version.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "0.1"))
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -300.0
	version.offset_right = -40.0
	version.offset_top = -70.0
	version.offset_bottom = -34.0
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(version)

	# Settings overlay (same panel as the pause menu).
	_settings_overlay = Control.new()
	_settings_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.visible = false
	add_child(_settings_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.08, 0.16, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_overlay.add_child(dim)
	var board := PanelContainer.new()
	board.theme_type_variation = &"ParchmentPanel"
	board.anchor_left = 0.5
	board.anchor_right = 0.5
	board.anchor_top = 0.5
	board.anchor_bottom = 0.5
	board.offset_left = -680.0
	board.offset_right = 680.0
	board.offset_top = -450.0
	board.offset_bottom = 450.0
	_settings_overlay.add_child(board)
	_settings = UISettingsPanel.new()
	_settings.show_back_button = true
	_settings.back_requested.connect(_close_settings)
	var host := Control.new()
	board.add_child(host)
	host.add_child(_settings)

	_confirm = UIConfirmDialog.new()
	add_child(_confirm)


func _add_button(id: StringName, text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = &"TitleButton"
	b.custom_minimum_size = Vector2(460, 84)
	b.pressed.connect(func() -> void:
		if _busy:
			return
		UIFx.sound(&"ui_select")
		UIFx.pop(b, 0.08, 0.2)
		cb.call())
	b.focus_entered.connect(func() -> void:
		UIFx.sound(&"ui_move", -4.0)
		UIFx.pop(b, 0.05, 0.18))
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	_menu.add_child(b)
	UIFx.prepare(b)
	_buttons[id] = b


func _intro() -> void:
	_logo.modulate.a = 0.0
	_logo.offset_transform_scale = Vector2(0.6, 0.6)
	_ribbon.modulate.a = 0.0
	_ribbon.offset_transform_scale = Vector2(0.2, 1.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_logo, "modulate:a", 1.0, 0.35)
	tw.tween_property(_logo, "offset_transform_scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_ribbon, "modulate:a", 1.0, 0.25).set_delay(0.3)
	tw.tween_property(_ribbon, "offset_transform_scale", Vector2.ONE, 0.5).set_delay(0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var i := 0
	for id: StringName in _buttons:
		var b: Button = _buttons[id]
		if not b.visible:
			continue
		b.modulate.a = 0.0
		var t2 := b.create_tween()
		t2.tween_interval(0.45 + i * 0.08)
		t2.tween_callback(func() -> void: UIFx.slide_in(b, Vector2(0, 40), 0.35))
		i += 1
	var first: Button = _buttons[&"continue"] if not (_buttons[&"continue"] as Button).disabled else _buttons[&"new"]
	first.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if UIRoot.instance == null:
		InputGlyphs.observe(event)


func _unhandled_input(event: InputEvent) -> void:
	if _settings_overlay.visible and event.is_action_pressed(&"ui_cancel"):
		if not _settings.handle_cancel():
			get_viewport().set_input_as_handled()
			_close_settings()


# --- Actions -------------------------------------------------------------------------------

func _resolve_start() -> String:
	if start_scene != "" and ResourceLoader.exists(start_scene):
		return start_scene
	return fallback_scene


func _on_new_game() -> void:
	if SaveManager.slot_exists(0):
		var ok: bool = await _confirm.ask("Start a New Voyage?", "Your saved game will be replaced when you next save.", "New Game", "Cancel")
		if not ok:
			return
	_busy = true
	SaveManager.new_game(0)
	_start(_resolve_start())


func _on_continue() -> void:
	if not SaveManager.load_game(0):
		(_buttons[&"continue"] as Button).disabled = true
		_buttons[&"new"].grab_focus()
		return
	_busy = true
	var scene := UIChartData.scene_for(GameManager.current_island)
	_start(scene if scene != "" else _resolve_start())


func _start(path: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if title_music != &"":
		AudioManager.stop_music(0.6)
	SceneTransition.change_scene(path)


func _open_settings() -> void:
	_settings_overlay.visible = true
	_settings.refresh()
	UIFx.fade(_settings_overlay, 1.0, 0.15)
	_set_menu_focusable(false)
	_settings.get_first_focus().grab_focus()


func _close_settings() -> void:
	if not _settings_overlay.visible:
		return
	UIFx.sound(&"ui_back")
	UIFx.fade(_settings_overlay, 0.0, 0.12)
	_set_menu_focusable(true)
	(_buttons[&"settings"] as Button).grab_focus()


## Keeps focus inside the settings overlay while it is open.
func _set_menu_focusable(on: bool) -> void:
	for id: StringName in _buttons:
		(_buttons[id] as Button).focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE


func _on_quit() -> void:
	get_tree().quit()
