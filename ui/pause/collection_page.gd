class_name UICollectionPage
extends UIPage
## Treasure & collectibles per discovered island:
##   Parrots 4 / 5 · Treasure 27 / 35 · Treasure Maps 1 / 2 · Ship Parts 1 / 1
## Totals come from ParrotManager.get_island_total(), UIChartData "totals",
## or UI.set_island_totals(); unknown totals show "?" instead of spoiling.
## Treasure maps and ship parts belong to islands through the TreasureMaps
## and ShipParts registries. Below the islands, every treasure map Patchy
## owns: choose one to unroll it (UITreasureMapViewer).

var _gold: Label
var _parrots: Label
var _list: VBoxContainer
var _scroll: ScrollContainer
var _first: Control


func _ready() -> void:
	build_frame("Treasure & Collectibles", &"chest")
	var totals := HBoxContainer.new()
	totals.add_theme_constant_override(&"separation", 26)
	totals.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(totals)
	var g := UIPage.make_stat(&"coin", "0", 52)
	_gold = g.get_child(1) as Label
	_gold.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	_gold.add_theme_font_size_override(&"font_size", 36)
	totals.add_child(g)
	var p := UIPage.make_stat(&"parrot", "0", 54)
	_parrots = p.get_child(1) as Label
	_parrots.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	_parrots.add_theme_font_size_override(&"font_size", 36)
	totals.add_child(p)
	_scroll = UIPage.make_scroll()
	body.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 14)
	_scroll.add_child(_list)


func get_first_focus() -> Control:
	return _first


func refresh() -> void:
	_gold.text = UITreasureCounter.format_number(InventoryManager.gold_value)
	_parrots.text = str(ParrotManager.get_total())
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_first = null
	var uncharted := 0
	for isl: Dictionary in UIChartData.ISLANDS:
		var id: StringName = isl["id"]
		if not GameManager.is_island_discovered(id):
			uncharted += 1
			continue
		var card := _make_card(isl)
		_list.add_child(card)
		if _first == null:
			_first = card
	# Progress from places that are not on the chart (test labs, debug).
	var known := UIChartData.ids()
	var stray_parrots := ParrotManager.get_total()
	for id in known:
		stray_parrots -= ParrotManager.count_for_island(id)
	if _first == null:
		var empty := Label.new()
		empty.text = "No islands charted yet. Set sail and explore!"
		empty.theme_type_variation = &"SubheaderLabel"
		empty.add_theme_color_override(&"font_color", UIPalette.INK_SOFT)
		_list.add_child(empty)
	_add_maps()
	if uncharted > 0:
		var more := Label.new()
		more.theme_type_variation = &"SmallLabel"
		more.text = "%d uncharted island%s still out there..." % [uncharted, "" if uncharted == 1 else "s"]
		more.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(more)
	if stray_parrots > 0:
		set_subtitle("Plus %d parrot%s found in uncharted waters" % [stray_parrots, "" if stray_parrots == 1 else "s"])
	else:
		set_subtitle("")


func _make_card(isl: Dictionary) -> UIFocusCard:
	var id: StringName = isl["id"]
	var card := UIFocusCard.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 22)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var emblem := UIIconView.make(&"island", 84)
	emblem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(emblem)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_row)
	var n := Label.new()
	n.text = String(isl["name"])
	n.theme_type_variation = &"SubheaderLabel"
	n.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	n.add_theme_font_size_override(&"font_size", 34)
	name_row.add_child(n)
	if id == GameManager.current_island:
		var here := Label.new()
		here.text = "  YOU ARE HERE"
		here.theme_type_variation = &"SmallLabel"
		here.add_theme_color_override(&"font_color", UIPalette.RED_DARK)
		here.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
		name_row.add_child(here)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override(&"separation", 34)
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stats)
	var totals := island_totals(id)
	var parrots_total := ParrotManager.get_island_total(id)
	if parrots_total <= 0:
		parrots_total = int(totals.get("parrots", 0))
	stats.add_child(_stat(&"parrot", "Parrots", ParrotManager.count_for_island(id), parrots_total))
	stats.add_child(_stat(&"coin", "Treasure", InventoryManager.count_treasures(&"", id), int(totals.get("treasure", 0))))
	var maps_have := 0
	for m: Variant in InventoryManager.get_treasure_maps().keys():
		if TreasureMaps.island_of(StringName(m)) == id or String(m).begins_with(String(id) + "_"):
			maps_have += 1
	var parts_have := 0
	for part in InventoryManager.get_ship_parts():
		if ShipParts.island_of(part) == id or String(part).begins_with(String(id) + "_"):
			parts_have += 1
	stats.add_child(_stat(&"treasure_map", "Treasure Maps", maps_have, int(totals.get("maps", TreasureMaps.for_island(id).size()))))
	stats.add_child(_stat(&"ship_wheel", "Ship Parts", parts_have, int(totals.get("ship_parts", ShipParts.for_island(id).size()))))
	return card


## The treasure maps Patchy owns, each one a card that unrolls the map.
func _add_maps() -> void:
	var owned: Array[StringName] = []
	for m: Variant in InventoryManager.get_treasure_maps().keys():
		if TreasureMaps.has_map(StringName(m)):
			owned.append(StringName(m))
	if owned.is_empty():
		return
	var head := Label.new()
	head.text = "Treasure Maps"
	head.theme_type_variation = &"SubheaderLabel"
	head.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	_list.add_child(head)
	for id in owned:
		var card := _make_map_card(id)
		_list.add_child(card)
		if _first == null:
			_first = card


func _make_map_card(id: StringName) -> UIFocusCard:
	var m := TreasureMaps.get_map(id)
	var solved := TreasureMaps.is_solved(id)
	var card := UIFocusCard.new()
	card.name = "MapCard_" + String(id)
	card.activated.connect(func() -> void:
		var menu := UIRoot.instance.pause_menu if UIRoot.instance != null else null
		if menu != null:
			menu.map_viewer.open(id))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	var ic := UIIconView.make(&"treasure_map", 60)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	var t := Label.new()
	t.text = String(m.get("title", id))
	t.theme_type_variation = &"SubheaderLabel"
	t.add_theme_font_size_override(&"font_size", 28)
	col.add_child(t)
	var sub := Label.new()
	sub.theme_type_variation = &"SmallLabel"
	sub.text = (UIChartData.get_island(TreasureMaps.island_of(id)).get("name", "") as String) + ("  ·  Treasure found!" if solved else "  ·  Unroll it and find the spot")
	if solved:
		sub.add_theme_color_override(&"font_color", UIPalette.GREEN_DARK)
	col.add_child(sub)
	if solved:
		var ck := UIIconView.make(&"check", 30)
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ck)
	return card


## Known totals for an island: UIChartData defaults overridden by runtime
## registrations on the UI root.
static func island_totals(id: StringName) -> Dictionary:
	var out: Dictionary = (UIChartData.get_island(id).get("totals", {}) as Dictionary).duplicate()
	if UIRoot.instance != null:
		out.merge(UIRoot.instance.get_island_totals(id), true)
	return out


func _stat(icon: StringName, caption: String, have: int, total: int) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := UIIconView.make(icon, 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", -6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var cap := Label.new()
	cap.text = caption
	cap.theme_type_variation = &"SmallLabel"
	cap.add_theme_font_size_override(&"font_size", 19)
	v.add_child(cap)
	var complete := total > 0 and have >= total
	var val := Label.new()
	val.text = "%d / %s" % [have, str(total) if total > 0 else "?"]
	val.theme_type_variation = &"SubheaderLabel"
	val.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	val.add_theme_font_size_override(&"font_size", 28)
	if complete:
		val.add_theme_color_override(&"font_color", UIPalette.GREEN_DARK)
	v.add_child(val)
	if complete:
		var ck := UIIconView.make(&"check", 26)
		ck.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ck)
	return h
