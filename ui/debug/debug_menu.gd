class_name UIDebugMenu
extends Control
## F1 developer menu (debug builds only). Pauses the game while open.
## Progress cheats, player tools, teleports to nodes in group
## &"debug_teleport", world-space visualizers, time scale and quick save/load.

signal toast_requested(text: String, icon: StringName)
signal opened
signal closed

const ATTACHMENTS_TO_UNLOCK: Array[StringName] = [&"hook", &"grapple", &"shovel", &"cannon", &"lantern"]

var is_open := false
var world_draw: UIDebugWorldDraw
var _panel: PanelContainer
var _teleports: VBoxContainer
var _toggles: Dictionary = {}
var _time_label: Label
var _time_slider: HSlider
var _first: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func _btn_style(bg: Color) -> StyleBoxFlat:
	var sb := UIStyle.box(bg, 8, 2, Color(0.5, 0.65, 0.9, 0.45), 12, 6)
	return sb


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 44)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override(&"font_size", 20)
	b.add_theme_constant_override(&"outline_size", 0)
	b.add_theme_stylebox_override(&"normal", _btn_style(Color(0.16, 0.2, 0.3)))
	b.add_theme_stylebox_override(&"hover", _btn_style(Color(0.22, 0.28, 0.42)))
	b.add_theme_stylebox_override(&"pressed", _btn_style(Color(0.1, 0.13, 0.2)))
	b.add_theme_stylebox_override(&"hover_pressed", _btn_style(Color(0.1, 0.13, 0.2)))
	b.add_theme_stylebox_override(&"focus", UIStyle.focus_ring(10, 3))
	b.add_theme_color_override(&"font_color", Color("e6eefc"))
	b.add_theme_color_override(&"font_hover_color", Color.WHITE)
	b.add_theme_color_override(&"font_focus_color", Color.WHITE)
	b.add_theme_color_override(&"font_pressed_color", Color("bcd0f0"))
	b.pressed.connect(func() -> void:
		UIFx.sound(&"ui_select")
		cb.call())
	b.mouse_entered.connect(b.grab_focus)
	if _first == null:
		_first = b
	return b


func _section(parent: Container, title: String) -> GridContainer:
	var l := Label.new()
	l.text = title
	l.theme_type_variation = &"DebugValue"
	l.add_theme_color_override(&"font_color", UIPalette.BRASS_LIGHT)
	parent.add_child(l)
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override(&"h_separation", 8)
	g.add_theme_constant_override(&"v_separation", 6)
	parent.add_child(g)
	return g


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"DebugPanel"
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 36.0
	_panel.offset_right = 560.0
	_panel.offset_top = 36.0
	_panel.offset_bottom = -36.0
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	_panel.add_child(sc)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override(&"separation", 8)
	sc.add_child(col)
	var head := Label.new()
	head.text = "DEBUG MENU"
	head.theme_type_variation = &"DebugValue"
	head.add_theme_font_size_override(&"font_size", 28)
	col.add_child(head)
	var hint := Label.new()
	hint.text = "F1 close · F3 movement HUD · F4 camera debug · F5/F9 save/load"
	hint.theme_type_variation = &"DebugLabel"
	hint.add_theme_font_size_override(&"font_size", 16)
	col.add_child(hint)

	var g := _section(col, "PROGRESS")
	g.add_child(_button("Unlock all attachments", _unlock_all))
	g.add_child(_button("+100 treasure", func() -> void: InventoryManager.collect_treasure(&"", &"coin", 100)))
	g.add_child(_button("+1 parrot", func() -> void: ParrotManager.debug_add(1)))
	g.add_child(_button("+5 parrots", func() -> void: ParrotManager.debug_add(5)))
	g.add_child(_button("-1 parrot", func() -> void: ParrotManager.debug_remove(1)))
	g.add_child(_button("-5 parrots", func() -> void: ParrotManager.debug_remove(5)))
	g.add_child(_button("Fit every ship upgrade", func() -> void:
		WorldState.mark_completed(&"castaway_dinghy")
		for id: StringName in ShipUpgrades.UPGRADES:
			ShipUpgrades.grant(id)
		toast_requested.emit("Every ship upgrade fitted", &"ship_wheel")))

	g = _section(col, "PLAYER")
	_toggles[&"invincible"] = _button("Invincible: OFF", _toggle_invincible)
	g.add_child(_toggles[&"invincible"])
	g.add_child(_button("Refill health", func() -> void:
		var h := _health()
		if h != null:
			h.call(&"refill")))
	g.add_child(_button("Set checkpoint here", _set_checkpoint))
	g.add_child(_button("Go to checkpoint", func() -> void:
		var p := _player()
		if p != null:
			var xf := GameManager.get_checkpoint_transform()
			p.call(&"teleport", xf.origin, -xf.basis.z)))

	var tl := Label.new()
	tl.text = "TELEPORT  (group \"debug_teleport\")"
	tl.theme_type_variation = &"DebugValue"
	tl.add_theme_color_override(&"font_color", UIPalette.BRASS_LIGHT)
	col.add_child(tl)
	_teleports = VBoxContainer.new()
	_teleports.add_theme_constant_override(&"separation", 6)
	col.add_child(_teleports)

	g = _section(col, "VISUALIZE")
	_toggles[&"camera"] = _button("Camera debug: OFF", _toggle_camera_debug)
	g.add_child(_toggles[&"camera"])
	_toggles[&"vectors"] = _button("Movement vectors: OFF", func() -> void:
		world_draw.show_vectors = not world_draw.show_vectors
		_refresh_labels())
	g.add_child(_toggles[&"vectors"])
	_toggles[&"anchors"] = _button("Grapple anchors: OFF", func() -> void:
		world_draw.show_anchors = not world_draw.show_anchors
		_refresh_labels())
	g.add_child(_toggles[&"anchors"])
	_toggles[&"hud"] = _button("Movement HUD: OFF", func() -> void:
		Settings.set_value(&"show_movement_hud", not Settings.show_movement_hud)
		_refresh_labels())
	g.add_child(_toggles[&"hud"])

	var ts := Label.new()
	ts.text = "TIME SCALE"
	ts.theme_type_variation = &"DebugValue"
	ts.add_theme_color_override(&"font_color", UIPalette.BRASS_LIGHT)
	col.add_child(ts)
	var trow := HBoxContainer.new()
	col.add_child(trow)
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.25
	_time_slider.max_value = 1.0
	_time_slider.step = 0.05
	_time_slider.value = Engine.time_scale
	_time_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_slider.custom_minimum_size = Vector2(0, 40)
	_time_slider.value_changed.connect(func(v: float) -> void:
		Engine.time_scale = v
		_time_label.text = "%.2fx" % v)
	trow.add_child(_time_slider)
	_time_label = Label.new()
	_time_label.theme_type_variation = &"DebugValue"
	_time_label.custom_minimum_size = Vector2(70, 0)
	_time_label.text = "%.2fx" % Engine.time_scale
	trow.add_child(_time_label)

	g = _section(col, "SAVE")
	g.add_child(_button("Quick save (F5)", quick_save))
	g.add_child(_button("Quick load (F9)", quick_load))


func _player() -> Node3D:
	var p := GameManager.player
	return p if p != null and is_instance_valid(p) else null


func _health() -> Node:
	var p := _player()
	if p == null:
		return null
	var h: Variant = p.get(&"health")
	return h as Node


# --- Open / close ------------------------------------------------------------------------

func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Events.game_paused.emit(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_rebuild_teleports()
	_refresh_labels()
	_time_slider.set_value_no_signal(Engine.time_scale)
	UIFx.slide_in(_panel, Vector2(-40, 0), 0.22)
	if _first != null:
		_first.grab_focus()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	Events.game_paused.emit(false)
	if _player() != null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var f := get_viewport().gui_get_focus_owner()
	if f != null and is_ancestor_of(f):
		f.release_focus()
	UIFx.slide_out(_panel, Vector2(-40, 0), 0.15)
	var tw := create_tween()
	tw.tween_interval(0.16)
	tw.tween_callback(func() -> void:
		if not is_open:
			visible = false)
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"debug_menu"):
		get_viewport().set_input_as_handled()
		close()


# --- Actions --------------------------------------------------------------------------------

func _unlock_all() -> void:
	for id in ATTACHMENTS_TO_UNLOCK:
		InventoryManager.unlock_attachment(id)
	toast_requested.emit("All attachments unlocked", &"hook")


func _toggle_invincible() -> void:
	var h := _health()
	if h != null:
		h.set(&"invincible", not bool(h.get(&"invincible")))
	_refresh_labels()


func _toggle_camera_debug() -> void:
	var p := _player()
	var rig: Variant = p.get(&"camera_rig") if p != null else null
	if rig is Object and is_instance_valid(rig):
		(rig as Object).set(&"debug_draw", not bool((rig as Object).get(&"debug_draw")))
	_refresh_labels()


func _set_checkpoint() -> void:
	var p := _player()
	if p == null:
		return
	GameManager.set_checkpoint(&"debug", p.global_transform)
	toast_requested.emit("Checkpoint set here", &"flag")


func _rebuild_teleports() -> void:
	for c in _teleports.get_children():
		c.queue_free()
	var nodes := get_tree().get_nodes_in_group(&"debug_teleport")
	var count := 0
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 8)
	grid.add_theme_constant_override(&"v_separation", 6)
	_teleports.add_child(grid)
	for n in nodes:
		var t := n as Node3D
		if t == null:
			continue
		count += 1
		grid.add_child(_button(String(t.name), func() -> void:
			var p := _player()
			if p != null and is_instance_valid(t):
				p.call(&"teleport", t.global_position, -t.global_basis.z)
				close()))
	if count == 0:
		var l := Label.new()
		l.text = "No Node3D in group \"debug_teleport\" in this scene."
		l.theme_type_variation = &"DebugLabel"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_teleports.add_child(l)


func _refresh_labels() -> void:
	var h := _health()
	(_toggles[&"invincible"] as Button).text = "Invincible: %s" % ("ON" if h != null and bool(h.get(&"invincible")) else "OFF")
	var p := _player()
	var rig: Variant = p.get(&"camera_rig") if p != null else null
	var cam_on := rig is Object and is_instance_valid(rig) and bool((rig as Object).get(&"debug_draw"))
	(_toggles[&"camera"] as Button).text = "Camera debug: %s" % ("ON" if cam_on else "OFF")
	(_toggles[&"vectors"] as Button).text = "Movement vectors: %s" % ("ON" if world_draw.show_vectors else "OFF")
	(_toggles[&"anchors"] as Button).text = "Grapple anchors: %s" % ("ON" if world_draw.show_anchors else "OFF")
	(_toggles[&"hud"] as Button).text = "Movement HUD: %s" % ("ON" if Settings.show_movement_hud else "OFF")


func quick_save() -> void:
	var ok := SaveManager.save_game(SaveManager.current_slot)
	toast_requested.emit("Quick saved (slot %d)" % SaveManager.current_slot if ok else "Quick save failed!", &"flag")


func quick_load() -> void:
	if not SaveManager.slot_exists(SaveManager.current_slot):
		toast_requested.emit("No save in slot %d" % SaveManager.current_slot, &"question")
		return
	if not SaveManager.load_game(SaveManager.current_slot):
		toast_requested.emit("Quick load failed!", &"question")
		return
	toast_requested.emit("Quick loaded (slot %d)" % SaveManager.current_slot, &"flag")
	var scene := UIChartData.scene_for(GameManager.current_island)
	var here := get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""
	if scene != "" and scene != here:
		close()
		GameManager.resume_pending = true
		SceneTransition.change_scene(scene)
		return
	var p := _player()
	if p != null:
		var xf := GameManager.get_checkpoint_transform()
		p.call(&"teleport", xf.origin, -xf.basis.z)
		var h := _health()
		if h != null:
			h.call(&"refill")
