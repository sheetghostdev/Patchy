class_name UIAttachmentsPage
extends UIPage
## Patchy's hand attachments: unlocked ones with icon, name and a one-line
## description (the equipped one is tagged); undiscovered slots show a
## silhouette and "???" so nothing is spoiled.

var _grid: GridContainer
var _first: Control


func _ready() -> void:
	build_frame("Attachments", &"hook")
	var sc := UIPage.make_scroll()
	body.add_child(sc)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override(&"h_separation", 16)
	_grid.add_theme_constant_override(&"v_separation", 14)
	sc.add_child(_grid)


func get_first_focus() -> Control:
	return _first


func refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_first = null
	var unlocked := InventoryManager.get_attachments()
	var equipped := InventoryManager.equipped_attachment
	set_subtitle("%d of %d found  ·  Equipped: %s" % [unlocked.size(), maxi(UIAttachmentInfo.ORDER.size(), unlocked.size()), UIAttachmentInfo.display_name(equipped)])
	for id in UIAttachmentInfo.all_ids(unlocked):
		var have := id in unlocked
		var card := _make_card(id, have, have and id == equipped)
		_grid.add_child(card)
		if _first == null:
			_first = card


func _make_card(id: StringName, have: bool, equipped: bool) -> UIFocusCard:
	var card := UIFocusCard.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 132)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var medal := Control.new()
	medal.custom_minimum_size = Vector2(100, 100)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.draw.connect(func() -> void:
		var c := medal.size * 0.5
		var r := minf(c.x, c.y) - 3.0
		var rim := UIPalette.BRASS if have else Color(UIPalette.PARCHMENT_EDGE, 0.7)
		medal.draw_circle(c, r, rim, true, -1.0, true)
		medal.draw_circle(c, r - 7.0, UIPalette.WOOD_DARK if have else Color(UIPalette.PARCHMENT_DARK, 0.9), true, -1.0, true)
		medal.draw_circle(c, r, UIPalette.OUTLINE, false, 3.0, true))
	row.add_child(medal)
	var ic := UIIconView.new()
	ic.icon = UIAttachmentInfo.icon(id)
	ic.silhouette = not have
	ic.position = Vector2(18, 18)
	ic.size = Vector2(64, 64)
	medal.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_row)
	var n := Label.new()
	n.text = UIAttachmentInfo.display_name(id) if have else "???"
	n.theme_type_variation = &"SubheaderLabel"
	n.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not have:
		n.add_theme_color_override(&"font_color", UIPalette.INK_FAINT)
	name_row.add_child(n)
	if equipped:
		var tag := PanelContainer.new()
		var sb := UIStyle.box(UIPalette.GREEN, 10, 2, UIPalette.GREEN_DARK, 12, 2)
		tag.add_theme_stylebox_override(&"panel", sb)
		var tl := Label.new()
		tl.text = "EQUIPPED"
		tl.theme_type_variation = &"CreamLabel"
		tl.add_theme_font_size_override(&"font_size", 20)
		tl.add_theme_color_override(&"font_outline_color", UIPalette.GREEN_DARK)
		tag.add_child(tl)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(tag)
	var d := Label.new()
	d.text = UIAttachmentInfo.description(id) if have else "Not found yet. Keep exploring!"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.add_theme_font_size_override(&"font_size", 24)
	d.add_theme_color_override(&"font_color", UIPalette.INK if have else UIPalette.INK_FAINT)
	d.custom_minimum_size = Vector2(300, 0)
	col.add_child(d)
	return card
