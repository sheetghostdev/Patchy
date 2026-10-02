class_name UIPauseMenu
extends Control
## Pause menu: a wooden plank list on the left, the focused entry's page on a
## parchment board on the right (focus previews, Accept enters the page, Back
## returns to the list). Pauses the SceneTree, frees the mouse, and emits
## Events.game_paused. Opened by the UI root on `pause` (or `map`, landing on
## the sea chart).

signal opened
signal closed
signal return_to_title_requested

const ENTRIES := [
	{"id": &"resume", "label": "Resume", "icon": &"play"},
	{"id": &"map", "label": "Map", "icon": &"compass"},
	{"id": &"collection", "label": "Treasure", "icon": &"chest"},
	{"id": &"attachments", "label": "Attachments", "icon": &"hook"},
	{"id": &"quests", "label": "Quests", "icon": &"quest"},
	{"id": &"settings", "label": "Settings", "icon": &"cog"},
	{"id": &"title", "label": "Return to Title", "icon": &"anchor"},
]

const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 2.2;
uniform vec4 tint : source_color = vec4(0.07, 0.1, 0.18, 0.5);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, lod).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
"""

## Save before returning to the title screen (progress + last checkpoint).
@export var save_on_return_to_title: bool = true

var is_open := false
var _backdrop: ColorRect
var _side: PanelContainer
var _board: PanelContainer
var _page_host: Control
var _entries: Dictionary = {}
var _pages: Dictionary = {}
var _current_page: StringName = &""
var _last_entry: StringName = &"resume"
var _island_label: Label
var _time_label: Label
var _hints: UIPromptRow
var confirm: UIConfirmDialog
## Unrolls a treasure map over the menu (opened from the Treasure page).
var map_viewer: UITreasureMapViewer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	InputGlyphs.notifier().device_changed.connect(func(_pad: bool) -> void:
		if is_open:
			_update_hints())


func _build() -> void:
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BLUR_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_backdrop.material = mat
	add_child(_backdrop)

	# Left: wooden board with the entries.
	_side = PanelContainer.new()
	_side.theme_type_variation = &"WoodPanel"
	_side.anchor_top = 0.0
	_side.anchor_bottom = 1.0
	_side.offset_left = 90.0
	_side.offset_right = 580.0
	_side.offset_top = 84.0
	_side.offset_bottom = -110.0
	add_child(_side)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 12)
	_side.add_child(col)
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"BrassPlate"
	col.add_child(plate)
	var plate_col := VBoxContainer.new()
	plate_col.add_theme_constant_override(&"separation", -4)
	plate.add_child(plate_col)
	var title := Label.new()
	title.text = "PAUSED"
	title.theme_type_variation = &"PlateLabel"
	title.add_theme_font_size_override(&"font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_col.add_child(title)
	_island_label = Label.new()
	_island_label.theme_type_variation = &"PlateLabel"
	_island_label.add_theme_font_size_override(&"font_size", 22)
	_island_label.add_theme_font_override(&"font", UIStyle.font(&"bold"))
	_island_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_col.add_child(_island_label)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	col.add_child(gap)
	var list := VBoxContainer.new()
	list.add_theme_constant_override(&"separation", 12)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(list)
	for e: Dictionary in ENTRIES:
		var b := UIMenuEntry.new()
		b.text = String(e["label"])
		b.icon_id = e["icon"]
		b.page_id = e["id"]
		var id: StringName = e["id"]
		b.focus_entered.connect(_on_entry_focused.bind(id))
		b.pressed.connect(_on_entry_pressed.bind(id))
		list.add_child(b)
		_entries[id] = b
	_time_label = Label.new()
	_time_label.theme_type_variation = &"CreamLabel"
	_time_label.add_theme_font_size_override(&"font_size", 22)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_time_label)

	# Right: parchment board hosting the pages.
	_board = PanelContainer.new()
	_board.theme_type_variation = &"ParchmentPanel"
	_board.anchor_left = 0.0
	_board.anchor_right = 1.0
	_board.anchor_bottom = 1.0
	_board.offset_left = 630.0
	_board.offset_right = -90.0
	_board.offset_top = 84.0
	_board.offset_bottom = -110.0
	add_child(_board)
	_page_host = Control.new()
	_page_host.clip_contents = false
	_board.add_child(_page_host)
	_add_page(&"overview", UIOverviewPage.new())
	_add_page(&"map", UIMapPage.new())
	_add_page(&"collection", UICollectionPage.new())
	_add_page(&"attachments", UIAttachmentsPage.new())
	_add_page(&"quests", UIQuestsPage.new())
	_add_page(&"settings", UISettingsPanel.new())

	# Bottom: button hints for the active device.
	var hint_row := HBoxContainer.new()
	hint_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hint_row.anchor_left = 0.0
	hint_row.anchor_right = 1.0
	hint_row.anchor_top = 1.0
	hint_row.anchor_bottom = 1.0
	hint_row.offset_top = -86.0
	hint_row.offset_bottom = -30.0
	hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_row)
	_hints = UIPromptRow.new()
	_hints.label_variation = &"HintText"
	_hints.glyph_height = 42.0
	_hints.add_theme_constant_override(&"separation", 12)
	hint_row.add_child(_hints)

	map_viewer = UITreasureMapViewer.new()
	add_child(map_viewer)
	# The viewer brings its own button hints.
	map_viewer.opened.connect(func() -> void: hint_row.visible = false)
	map_viewer.closed.connect(func() -> void: hint_row.visible = true)
	confirm = UIConfirmDialog.new()
	add_child(confirm)
	UIFx.prepare(_side)
	UIFx.prepare(_board)


func _add_page(id: StringName, page: UIPage) -> void:
	page.name = String(id).capitalize().replace(" ", "")
	page.visible = false
	_page_host.add_child(page)
	_pages[id] = page


func get_page(id: StringName) -> UIPage:
	return _pages.get(id, null)


# --- Open / close ---------------------------------------------------------------------

func open(entry: StringName = &"resume") -> void:
	if is_open:
		focus_entry(entry)
		return
	is_open = true
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Events.game_paused.emit(true)
	UIFx.sound(&"ui_map" if entry == &"map" else &"ui_pause")
	_island_label.text = UIChartData.display_name(GameManager.current_island) if GameManager.current_island != &"" else "Uncharted Waters"
	_time_label.text = "Play time  " + UIOverviewPage.format_time(GameManager.play_time)
	_current_page = &""
	for pid: StringName in _pages:
		(_pages[pid] as Control).visible = false
	modulate.a = 1.0
	_backdrop.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 1.0, 0.2)
	UIFx.slide_in(_side, Vector2(-70, 0), 0.32)
	UIFx.slide_in(_board, Vector2(70, 0), 0.36)
	_update_hints()
	focus_entry(entry)
	opened.emit()


func close() -> void:
	if map_viewer != null and map_viewer.is_open:
		map_viewer.close()
	if not is_open:
		return
	is_open = false
	get_tree().paused = false
	Events.game_paused.emit(false)
	UIFx.sound(&"ui_back")
	if GameManager.player != null and is_instance_valid(GameManager.player):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var f := get_viewport().gui_get_focus_owner()
	if f != null and is_ancestor_of(f):
		f.release_focus()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_backdrop, "modulate:a", 0.0, 0.16)
	UIFx.slide_out(_side, Vector2(-50, 0), 0.16)
	UIFx.slide_out(_board, Vector2(50, 0), 0.16)
	tw.chain().tween_callback(func() -> void:
		if not is_open:
			visible = false)
	closed.emit()


func focus_entry(id: StringName) -> void:
	if not _entries.has(id):
		id = &"resume"
	_last_entry = id
	(_entries[id] as Control).grab_focus()
	_show_page_for(id)


func current_page() -> StringName:
	return _current_page


# --- Entries and pages ------------------------------------------------------------------

func _page_for_entry(id: StringName) -> StringName:
	return id if _pages.has(id) else &"overview"


func _on_entry_focused(id: StringName) -> void:
	_last_entry = id
	_show_page_for(id)


func _show_page_for(id: StringName) -> void:
	var pid := _page_for_entry(id)
	if pid == _current_page:
		return
	var old: UIPage = _pages.get(_current_page, null)
	_current_page = pid
	var page: UIPage = _pages[pid]
	page.refresh()
	if old != null:
		old.visible = false
	page.visible = true
	UIFx.slide_in(page, Vector2(0, 14), 0.2)
	_update_hints()


func _on_entry_pressed(id: StringName) -> void:
	match id:
		&"resume":
			close()
		&"title":
			_ask_return_to_title()
		_:
			UIFx.sound(&"ui_select")
			var page: UIPage = _pages[_page_for_entry(id)]
			var f := page.get_first_focus()
			if f != null:
				f.grab_focus()
			else:
				UIFx.pop(_entries[id], 0.06, 0.2)
			_update_hints()


func _ask_return_to_title() -> void:
	UIFx.sound(&"ui_select")
	var body := "Your treasure, parrots and attachments are kept. You'll continue from your last checkpoint." \
		if save_on_return_to_title else "Any progress since your last save will be lost."
	var ok: bool = await confirm.ask("Return to Title?", body, "Return to Title", "Keep Playing")
	if ok:
		return_to_title_requested.emit()


func _in_page() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f != null and _board.is_ancestor_of(f)


func _update_hints() -> void:
	var text := "{ui_accept} Select    {ui_cancel} Back"
	if _current_page == &"settings" and InputGlyphs.using_gamepad:
		text += "    {pad_lb}{pad_rb} Tabs"
	if _current_page != &"map":
		text += "    {map} Map"
	_hints.prompt = text


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or confirm.is_open():
		return
	# Back (Esc / B) steps out of a page first; Pause (Start / P) closes.
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		var page: UIPage = _pages.get(_current_page, null)
		if page != null and page.handle_cancel():
			return
		if _in_page():
			UIFx.sound(&"ui_back")
			focus_entry(_last_entry)
		else:
			close()
	elif event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		var page: UIPage = _pages.get(_current_page, null)
		if page == null or not page.handle_cancel():
			close()
	elif event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		if _current_page == &"map":
			close()
		else:
			UIFx.sound(&"ui_map")
			focus_entry(&"map")


func _process(_delta: float) -> void:
	if is_open and Engine.get_process_frames() % 30 == 0:
		_time_label.text = "Play time  " + UIOverviewPage.format_time(GameManager.play_time)
