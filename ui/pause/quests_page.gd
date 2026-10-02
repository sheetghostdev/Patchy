class_name UIQuestsPage
extends UIPage
## Quest log fed by UI.set_quests([{title, description, done}, ...]).
## Active quests first, completed ones ticked and dimmed below.

var _list: VBoxContainer
var _first: Control


func _ready() -> void:
	build_frame("Quests", &"quest")
	var sc := UIPage.make_scroll()
	body.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 12)
	sc.add_child(_list)


func get_first_focus() -> Control:
	return _first


func refresh() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_first = null
	var quests: Array = UIRoot.instance.get_quests() if UIRoot.instance != null else []
	var active: Array = []
	var done: Array = []
	for q: Variant in quests:
		if q is Dictionary:
			(done if bool(q.get("done", false)) else active).append(q)
	set_subtitle("%d active  ·  %d complete" % [active.size(), done.size()] if not quests.is_empty() else "")
	if quests.is_empty():
		var empty := VBoxContainer.new()
		empty.alignment = BoxContainer.ALIGNMENT_CENTER
		empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var ic := UIIconView.make(&"quest", 120)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		ic.modulate.a = 0.5
		empty.add_child(ic)
		var l := Label.new()
		l.text = "No quests yet. Talk to the island folk!"
		l.theme_type_variation = &"SubheaderLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_color_override(&"font_color", UIPalette.INK_SOFT)
		empty.add_child(l)
		_list.add_child(empty)
		return
	for q: Dictionary in active + done:
		var card := _make_card(q)
		_list.add_child(card)
		if _first == null:
			_first = card


func _make_card(q: Dictionary) -> UIFocusCard:
	var is_done := bool(q.get("done", false))
	var card := UIFocusCard.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var box := Control.new()
	box.custom_minimum_size = Vector2(52, 52)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.draw.connect(func() -> void:
		var r := Rect2(Vector2(6, 6), box.size - Vector2(12, 12))
		var sb := UIStyle.box(UIPalette.PARCHMENT_LIGHT, 8, 3, UIPalette.WOOD_DARK, 0, 0)
		box.draw_style_box(sb, r)
		if is_done:
			UIIcons.draw_icon(box, &"check", Rect2(Vector2(2, -4), box.size)))
	row.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := Label.new()
	t.text = str(q.get("title", "Quest"))
	t.theme_type_variation = &"SubheaderLabel"
	t.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	col.add_child(t)
	var d := Label.new()
	d.text = str(q.get("description", ""))
	d.visible = d.text != ""
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override(&"font_size", 25)
	col.add_child(d)
	if is_done:
		t.add_theme_color_override(&"font_color", UIPalette.INK_SOFT)
		d.add_theme_color_override(&"font_color", UIPalette.INK_FAINT)
		card.self_modulate = Color(1, 1, 1, 0.7)
	return card
