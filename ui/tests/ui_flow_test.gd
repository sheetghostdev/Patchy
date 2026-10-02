extends Node
## Headless UI flow checks driven by real input events:
##   godot --headless --path . --fixed-fps 60 res://ui/tests/ui_flow_test.tscn
## Exits with code 1 if any check fails.

const LAB := "res://tests/scenes/movement_test.tscn"
const UI_SCENE := "res://ui/ui_root.tscn"

var ui: UIRoot
var _fails := 0
var _checks := 0
var _events: Array[String] = []


func _ready() -> void:
	# Behave like the real game: the UI root lives under /root (as the "UI"
	# autoload would) and the lab is the current scene, so scene changes
	# replace the lab but keep this test node and the UI alive.
	var existing := get_node_or_null(^"/root/UI")
	print("UI root: ", "autoload /root/UI" if existing is UIRoot else "instanced by the test")
	if existing is UIRoot:
		ui = existing
	else:
		ui = load(UI_SCENE).instantiate()
		ui.name = "UI"
		get_tree().root.add_child.call_deferred(ui)
	var lab: Node = load(LAB).instantiate()
	get_tree().root.add_child.call_deferred(lab)
	await get_tree().process_frame
	get_tree().current_scene = lab
	Events.game_paused.connect(func(p: bool) -> void: _events.append("paused:%s" % p))
	Events.dialogue_started.connect(func(s: String) -> void: _events.append("dialogue_started:" + s))
	Events.dialogue_finished.connect(func() -> void: _events.append("dialogue_finished"))
	await _frames(6)
	await _test_pause_cycle()
	await _test_map_action()
	await _test_menu_navigation()
	await _test_settings_toggle()
	await _test_dialogue()
	await _test_prompt_and_devices()
	await _test_requirement_and_counters()
	await _test_subtitles_setting()
	await _test_rebinding()
	await _test_debug_tools()
	await _test_title_screen()
	await _test_scene_round_trip()
	print("ui_flow_test: %d checks, %d failed" % [_checks, _fails])
	get_tree().quit(1 if _fails > 0 else 0)


# --- Helpers ------------------------------------------------------------------------

func check(cond: bool, what: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  ", what)
	else:
		_fails += 1
		print("  FAIL  ", what)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func focus_owner() -> Control:
	return get_viewport().gui_get_focus_owner()


# --- Tests ----------------------------------------------------------------------------

func _test_pause_cycle() -> void:
	print("pause cycle")
	check(ui.can_pause(), "can pause with a player in the scene")
	_events.clear()
	await press(&"pause")
	check(ui.pause_menu.is_open and get_tree().paused, "pause action opens the menu and pauses the tree")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse released while paused")
	check(_events.has("paused:true"), "Events.game_paused(true) emitted")
	check(not ui.hud.is_gameplay_visible(), "HUD hidden behind the pause menu")
	var f := focus_owner()
	check(f is UIMenuEntry and (f as UIMenuEntry).page_id == &"resume", "Resume is focused on open")
	await press(&"ui_cancel")
	await _frames(12)
	check(not ui.pause_menu.is_open and not get_tree().paused, "Back closes the menu and unpauses")
	check(_events.has("paused:false"), "Events.game_paused(false) emitted")
	check(ui.hud.is_gameplay_visible(), "HUD visible again after resume")


func _test_map_action() -> void:
	print("map action")
	await press(&"map")
	check(ui.pause_menu.is_open and ui.pause_menu.current_page() == &"map", "map action opens the sea chart page")
	await press(&"map")
	await _frames(12)
	check(not ui.pause_menu.is_open, "map action again closes the chart")


func _test_menu_navigation() -> void:
	print("menu navigation")
	ui.open_pause_menu()
	await _frames(4)
	var shown := 0
	for pid: StringName in [&"overview", &"map", &"collection", &"attachments", &"quests", &"settings"]:
		if ui.pause_menu.get_page(pid).visible:
			shown += 1
	check(shown == 1 and ui.pause_menu.get_page(&"overview").visible, "reopening shows exactly one page (no leftovers)")
	await press(&"ui_down")
	var f := focus_owner()
	check(f is UIMenuEntry and (f as UIMenuEntry).page_id == &"map", "ui_down moves to Map")
	check(ui.pause_menu.current_page() == &"map", "focusing an entry previews its page")
	for i in 4:
		await press(&"ui_down")
	f = focus_owner()
	check(f is UIMenuEntry and (f as UIMenuEntry).page_id == &"settings", "reached Settings entry")
	await press(&"ui_accept")
	f = focus_owner()
	var settings := ui.pause_menu.get_page(&"settings")
	check(f != null and settings.is_ancestor_of(f), "Accept enters the settings page")
	await press(&"ui_cancel")
	f = focus_owner()
	check(f is UIMenuEntry and (f as UIMenuEntry).page_id == &"settings", "Back returns focus to the entry list")
	check(ui.pause_menu.is_open, "menu still open after stepping back")
	await press(&"pause")
	await _frames(12)
	check(not ui.pause_menu.is_open, "Pause closes the menu from anywhere")
	# Controller: Start opens, A confirms, B backs out.
	check(InputGlyphs.find_event(&"ui_accept", true) != null and InputGlyphs.find_event(&"ui_cancel", true) != null,
		"ui_accept / ui_cancel have gamepad buttons")
	await _pad(JOY_BUTTON_START)
	check(ui.pause_menu.is_open, "Start opens the pause menu")
	await press(&"ui_down")
	await _pad(JOY_BUTTON_A)
	var f2 := focus_owner()
	check(ui.pause_menu.current_page() == &"map" and f2 is UIMenuEntry, "A on Map keeps the chart (no focusables) open")
	await _pad(JOY_BUTTON_B)
	await _frames(12)
	check(not ui.pause_menu.is_open, "B from the entry list closes the menu")


func _pad(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	var up := InputEventJoypadButton.new()
	up.button_index = button
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _test_settings_toggle() -> void:
	print("settings toggle")
	var before: bool = Settings.invert_y
	ui.open_pause_menu(&"settings")
	await _frames(4)
	var panel := ui.pause_menu.get_page(&"settings") as UISettingsPanel
	panel.show_tab(&"camera")
	panel.focus_first_row()
	await _frames(2)
	# Rows: mouse, stick, invert x, invert y...
	for i in 3:
		await press(&"ui_down")
	var f := focus_owner()
	check(f is UIToggleSwitch, "ui_down reaches a toggle row")
	await press(&"ui_right" if not before else &"ui_left")
	check(Settings.invert_y != before, "toggle applies live through Settings")
	Settings.set_value(&"invert_y", before)
	await _frames(2)
	check((f as UIToggleSwitch).button_pressed == before, "row re-syncs when Settings change elsewhere")
	ui.close_pause_menu()
	await _frames(12)


func _test_dialogue() -> void:
	print("dialogue")
	_events.clear()
	var lines: Array[String] = ["First line of chatter.", "Second line!"]
	var done := [false]
	var run := func() -> void:
		await ui.show_dialogue("Tester", lines)
		done[0] = true
	run.call()
	await _frames(20)
	check(ui.is_dialogue_active(), "dialogue box active")
	check(_events.has("dialogue_started:Tester"), "Events.dialogue_started emitted with speaker")
	var p := GameManager.player
	check(p != null and not bool(p.get(&"input").get(&"enabled")), "player input locked during dialogue")
	# Press 1 completes line 1, press 2 shows line 2, press 3 completes it,
	# press 4 closes. Alternate actions to cover interact and jump.
	var presses := 0
	while ui.is_dialogue_active() and presses < 8:
		await press(&"interact" if presses % 2 == 0 else &"jump")
		presses += 1
	await _frames(6)
	check(presses == 4, "four presses: complete, next, complete, close (took %d)" % presses)
	check(done[0] and not ui.is_dialogue_active(), "interact/jump advance through every line and finish")
	check(_events.has("dialogue_finished"), "Events.dialogue_finished emitted")
	await _frames(6)
	check(bool(p.get(&"input").get(&"enabled")), "player input restored after dialogue")
	# Holding the button that started a conversation must not skip it...
	_action(&"interact", true)
	ui.show_dialogue("Tester", ["Held-over press.", "Still here."])
	await _frames(80)
	check(ui.is_dialogue_active(), "a press held from before the dialogue doesn't skip it")
	_action(&"interact", false)
	await _frames(4)
	# ...but a fresh press held inside the dialogue skips the rest.
	_action(&"interact", true)
	await _frames(70)
	_action(&"interact", false)
	await _frames(4)
	check(not ui.is_dialogue_active(), "holding a fresh press skips the conversation")


func _action(action: StringName, pressed: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _test_prompt_and_devices() -> void:
	print("prompt + device glyphs")
	await _key(KEY_W, true)
	await _key(KEY_W, false)
	Events.interaction_prompt_changed.emit("{interact} Pull", true)
	await _frames(3)
	check(ui.hud.prompt.get_current() == "{interact} Pull", "prompt shown")
	var glyph := _first_glyph(ui.hud.prompt)
	check(glyph != null and String(glyph.get_description().get("text", "")) == "E", "keyboard glyph is [E]")
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	Input.parse_input_event(jb)
	await _frames(2)
	var jr := InputEventJoypadButton.new()
	jr.button_index = JOY_BUTTON_A
	jr.pressed = false
	Input.parse_input_event(jr)
	await _frames(2)
	check(InputGlyphs.using_gamepad, "a pad button switches to gamepad glyphs")
	check(glyph != null and glyph.get_description().get("kind") == &"face" and String(glyph.get_description().get("text")) == "Y", "interact shows the (Y) face button")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	var key_up := InputEventKey.new()
	key_up.physical_keycode = KEY_W
	Input.parse_input_event(key_up)
	await _frames(2)
	check(not InputGlyphs.using_gamepad, "a key press switches back to keyboard glyphs")
	Events.interaction_prompt_changed.emit("{tool_primary} Dig", true)
	await _frames(2)
	check(ui.hud.prompt.get_current() == "{tool_primary} Dig", "newest prompt wins")
	Events.interaction_prompt_changed.emit("{tool_primary} Dig", false)
	await _frames(2)
	check(ui.hud.prompt.get_current() == "{interact} Pull", "disabling it reveals the previous prompt")
	Events.interaction_prompt_changed.emit("", false)
	await _frames(2)
	check(ui.hud.prompt.get_current() == "", "empty disable clears all prompts")


func _first_glyph(n: Node) -> UIGlyphView:
	for c in n.get_children():
		if c is UIGlyphView:
			return c
		var g := _first_glyph(c)
		if g != null:
			return g
	return null


func _test_requirement_and_counters() -> void:
	print("requirement + counters")
	var need := ParrotManager.get_total() + 2
	Events.parrot_requirement_shown.emit(need, ParrotManager.get_total(), true)
	await _frames(2)
	check(ui.hud.requirement.shown and not ui.hud.requirement.met, "requirement shows unmet")
	ParrotManager.debug_add(2)
	Events.parrot_requirement_shown.emit(need, ParrotManager.get_total(), true)
	await _frames(2)
	check(ui.hud.requirement.met, "requirement turns active when have >= required")
	check(ui.hud.parrots.visible, "parrot counter appears on flock change")
	Events.parrot_requirement_shown.emit(3, 3, false)
	var gold := InventoryManager.gold_value
	InventoryManager.collect_treasure(&"", &"coin", 100)
	await _frames(70)
	check(ui.hud.treasure.label.text == UITreasureCounter.format_number(gold + 100), "treasure counter ticks up to the new total")
	ParrotManager.debug_remove(2)


func _test_subtitles_setting() -> void:
	print("subtitles")
	var before: bool = Settings.subtitles
	Settings.subtitles = false
	ui.show_subtitle("hidden bark", 1.0)
	await _frames(2)
	check(ui.hud.subtitles.get_child_count() == 0, "subtitles respect Settings.subtitles = false")
	Settings.subtitles = true
	ui.show_subtitle("visible bark", 1.0, "Parrot")
	await _frames(2)
	check(ui.hud.subtitles.get_child_count() == 1, "subtitle shown when enabled")
	Settings.subtitles = before


func _key(code: Key, pressed: bool) -> void:
	var k := InputEventKey.new()
	k.physical_keycode = code
	k.keycode = code
	k.pressed = pressed
	Input.parse_input_event(k)
	await _frames(2)


func _test_rebinding() -> void:
	print("rebinding")
	var cfg_path := InputBindings.PATH
	var had_cfg := FileAccess.file_exists(cfg_path)
	var backup := FileAccess.get_file_as_string(cfg_path) if had_cfg else ""
	ui.open_pause_menu(&"settings")
	await _frames(4)
	var panel := ui.pause_menu.get_page(&"settings") as UISettingsPanel
	panel.show_tab(&"controls")
	panel.focus_first_row()
	await _frames(2)
	await press(&"ui_accept")
	check(panel.handle_cancel(), "binding button starts listening (Back is held back)")
	await _key(KEY_K, true)
	await _key(KEY_K, false)
	var ev := InputGlyphs.find_event(&"jump", false) as InputEventKey
	check(ev != null and ev.physical_keycode == KEY_K, "pressing K rebinds Jump's keyboard key")
	check(FileAccess.file_exists(cfg_path), "override saved to user://input_bindings.cfg")
	var pad_ev := InputGlyphs.find_event(&"jump", true) as InputEventJoypadButton
	check(pad_ev != null and pad_ev.button_index == JOY_BUTTON_A, "gamepad binding untouched")
	# Applying the saved file again must be stable.
	InputMap.load_from_project_settings()
	InputBindings.load_and_apply()
	ev = InputGlyphs.find_event(&"jump", false) as InputEventKey
	check(ev != null and ev.physical_keycode == KEY_K, "saved bindings re-apply at startup")
	InputBindings.reset_all()
	ev = InputGlyphs.find_event(&"jump", false) as InputEventKey
	check(ev != null and ev.physical_keycode == KEY_SPACE, "Reset to Defaults restores Space")
	ui.close_pause_menu()
	await _frames(12)
	if had_cfg:
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
		InputBindings.load_and_apply()


func _test_debug_tools() -> void:
	print("debug tools")
	var had_save := SaveManager.slot_exists(0)
	var backup := FileAccess.get_file_as_string(SaveManager.get_slot_path(0)) if had_save else ""
	await press(&"debug_menu")
	check(ui.debug_menu.is_open and get_tree().paused, "F1 opens the debug menu (paused)")
	ui.debug_menu.call(&"_unlock_all")
	var all_unlocked := true
	for id: StringName in [&"hook", &"grapple", &"shovel", &"cannon", &"lantern"]:
		all_unlocked = all_unlocked and InventoryManager.has_attachment(id)
	check(all_unlocked, "unlock all attachments")
	var parrots := ParrotManager.get_total()
	ParrotManager.debug_add(5)
	check(ParrotManager.get_total() == parrots + 5, "+5 parrots")
	ParrotManager.debug_remove(5)
	var p := GameManager.player
	var h: Node = p.get(&"health")
	ui.debug_menu.call(&"_toggle_invincible")
	check(bool(h.get(&"invincible")), "invincibility toggles on")
	ui.debug_menu.call(&"_toggle_invincible")
	ui.world_draw.show_vectors = true
	ui.world_draw.show_anchors = true
	await press(&"debug_menu")
	await _frames(10)
	check(not ui.debug_menu.is_open and not get_tree().paused, "F1 closes it again")
	ui.world_draw.show_vectors = false
	ui.world_draw.show_anchors = false
	var gold := InventoryManager.gold_value
	await press(&"quick_save")
	check(SaveManager.slot_exists(0), "F5 quick save writes slot 0")
	InventoryManager.collect_treasure(&"", &"coin", 7)
	await press(&"quick_load")
	await _frames(4)
	check(InventoryManager.gold_value == gold, "F9 quick load restores the saved treasure")
	if had_save:
		var f := FileAccess.open(SaveManager.get_slot_path(0), FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		SaveManager.delete_slot(0)


func _test_title_screen() -> void:
	print("title screen")
	var title: UITitleScreen = load("res://ui/title/title_screen.tscn").instantiate()
	add_child(title)
	await _frames(40)
	var cont: Button = title.get(&"_buttons")[&"continue"]
	check(cont.disabled == not SaveManager.slot_exists(0), "Continue enabled only when slot 0 exists")
	check(title.is_in_group(&"no_pause"), "title screen is in the no_pause group")
	title.queue_free()
	await _frames(2)


func _wait_scene(pred: Callable, max_frames: int = 240) -> void:
	for i in max_frames:
		if pred.call():
			return
		await get_tree().process_frame


func _test_scene_round_trip() -> void:
	print("scene round trip")
	# Keep any real save in slot 0 intact.
	var had_save := SaveManager.slot_exists(0)
	var backup := FileAccess.get_file_as_string(SaveManager.get_slot_path(0)) if had_save else ""
	ui.open_pause_menu(&"title")
	await _frames(4)
	await press(&"ui_accept")
	check(ui.pause_menu.confirm.is_open(), "Return to Title asks for confirmation")
	await press(&"ui_right")
	await press(&"ui_accept")
	await _wait_scene(func() -> bool: return get_tree().current_scene is UITitleScreen)
	check(get_tree().current_scene is UITitleScreen, "confirming changes to the title scene")
	await _frames(30)
	check(not get_tree().paused and not ui.pause_menu.is_open, "menu closed and tree unpaused on the title")
	check(not ui.hud.is_gameplay_visible(), "HUD hidden on the title screen (no player)")
	await press(&"pause")
	check(not ui.pause_menu.is_open, "pause does nothing on the title screen")
	check(SaveManager.slot_exists(0), "progress saved when returning to title")
	var title := get_tree().current_scene as UITitleScreen
	title.call(&"_on_new_game")
	await _frames(4)
	var dlg := title.get(&"_confirm") as UIConfirmDialog
	check(dlg != null and dlg.is_open(), "New Game over an existing save asks first")
	await press(&"ui_right")
	await press(&"ui_accept")
	await _wait_scene(func() -> bool: return GameManager.player != null and is_instance_valid(GameManager.player))
	await _frames(30)
	check(GameManager.player != null, "New Game loads a level with a player (start or fallback scene)")
	check(ui.hud.is_gameplay_visible(), "HUD visible again in the level")
	check(InventoryManager.gold_value == 0 and ParrotManager.get_total() == 0, "New Game reset progress")
	if had_save:
		var f := FileAccess.open(SaveManager.get_slot_path(0), FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		SaveManager.delete_slot(0)
