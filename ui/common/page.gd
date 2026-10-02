class_name UIPage
extends Control
## Base for pause-menu pages (map, collection, attachments, quests,
## settings, overview). The menu calls `refresh()` before showing a page,
## focuses `get_first_focus()` when the player enters it, and offers
## `handle_cancel()` first refusal on Back (return true to consume it).

var title_label: Label
var subtitle_label: Label
var header: HBoxContainer
var body: VBoxContainer


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func refresh() -> void:
	pass


func get_first_focus() -> Control:
	return null


func handle_cancel() -> bool:
	return false


## Standard layout: header row (title left, extra info right) + body column.
func build_frame(title: String, icon: StringName = &"") -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override(&"separation", 16)
	add_child(col)
	header = HBoxContainer.new()
	header.add_theme_constant_override(&"separation", 14)
	col.add_child(header)
	if icon != &"":
		var ic := UIIconView.make(icon, 60)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		header.add_child(ic)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override(&"separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	title_label = Label.new()
	title_label.theme_type_variation = &"HeaderLabel"
	title_label.text = title
	titles.add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.theme_type_variation = &"SmallLabel"
	subtitle_label.visible = false
	titles.add_child(subtitle_label)
	col.add_child(make_divider())
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 12)
	col.add_child(body)


func set_subtitle(t: String) -> void:
	subtitle_label.text = t
	subtitle_label.visible = t != ""


## A thin rope-like divider line.
static func make_divider() -> Control:
	var d := Control.new()
	d.custom_minimum_size = Vector2(0, 10)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.draw.connect(func() -> void:
		var y := d.size.y * 0.5
		var col := Color(UIPalette.PARCHMENT_EDGE, 0.9)
		d.draw_line(Vector2(0, y), Vector2(d.size.x, y), col, 3.0, true)
		var step := 18.0
		var x := 6.0
		while x < d.size.x - 6.0:
			d.draw_line(Vector2(x, y - 3), Vector2(x + 6, y + 3), Color(UIPalette.WOOD_DARK, 0.35), 2.0, true)
			x += step)
	return d


## Scroll area that keeps the focused child visible (controller friendly).
static func make_scroll() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	return sc


## Icon + text chip (used for stats).
static func make_stat(icon: StringName, text: String, icon_px: float = 40.0, complete: bool = false) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIIconView.make(icon, icon_px)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Label.new()
	l.text = text
	l.theme_type_variation = &"SubheaderLabel"
	l.add_theme_font_size_override(&"font_size", 28)
	if complete:
		l.add_theme_color_override(&"font_color", UIPalette.GREEN_DARK)
	h.add_child(l)
	if complete:
		var ck := UIIconView.make(&"check", 26)
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ck)
	return h
