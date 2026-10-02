class_name UIOverviewPage
extends UIPage
## "Captain's Log" summary shown beside Resume / Return to Title: where you
## are, progress at a glance, the current quest, the equipped attachment and
## a rotating control tip (glyphs follow the active device).

const TIPS := [
	"Hold {crouch} then press {jump} for a high backflip.",
	"Run, hold {crouch} and press {jump} for a long jump.",
	"Press {dive} in mid-air to dive, then {jump} to roll out.",
	"Jump at a wall and press {jump} again to wall-kick.",
	"Press {attack} to swipe with your hook.",
	"Press {crouch} in mid-air to ground pound.",
	"Press {camera_reset} to snap the camera behind Patchy.",
	"Switch attachments with {tool_previous} and {tool_next}",
	"Open the sea chart any time with {map}",
]

var _island: Label
var _grid: GridContainer
var _quest_title: Label
var _quest_desc: Label
var _equip_icon: UIIconView
var _equip_name: Label
var _equip_desc: Label
var _tip: UIPromptRow
var _tip_index := 0


func _ready() -> void:
	build_frame("Captain's Log", &"compass")
	_island = Label.new()
	_island.theme_type_variation = &"SubheaderLabel"
	_island.add_theme_font_size_override(&"font_size", 38)
	body.add_child(_island)
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	body.add_child(card)
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override(&"h_separation", 60)
	_grid.add_theme_constant_override(&"v_separation", 22)
	card.add_child(_grid)

	var pair := HBoxContainer.new()
	pair.add_theme_constant_override(&"separation", 16)
	pair.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(pair)
	var quest := _titled_card(pair, "CURRENT QUEST")
	var qrow := HBoxContainer.new()
	qrow.add_theme_constant_override(&"separation", 14)
	quest.add_child(qrow)
	var qicon := UIIconView.make(&"quest", 64)
	qicon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	qrow.add_child(qicon)
	var qcol := VBoxContainer.new()
	qcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qcol.add_theme_constant_override(&"separation", 2)
	qrow.add_child(qcol)
	_quest_title = Label.new()
	_quest_title.theme_type_variation = &"SubheaderLabel"
	_quest_title.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	_quest_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	qcol.add_child(_quest_title)
	_quest_desc = Label.new()
	_quest_desc.add_theme_font_size_override(&"font_size", 24)
	_quest_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_desc.custom_minimum_size = Vector2(240, 0)
	qcol.add_child(_quest_desc)

	var equip := _titled_card(pair, "EQUIPPED")
	var erow := HBoxContainer.new()
	erow.add_theme_constant_override(&"separation", 14)
	equip.add_child(erow)
	_equip_icon = UIIconView.make(&"hook", 64)
	_equip_icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	erow.add_child(_equip_icon)
	var ecol := VBoxContainer.new()
	ecol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ecol.add_theme_constant_override(&"separation", 2)
	erow.add_child(ecol)
	_equip_name = Label.new()
	_equip_name.theme_type_variation = &"SubheaderLabel"
	_equip_name.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	ecol.add_child(_equip_name)
	_equip_desc = Label.new()
	_equip_desc.add_theme_font_size_override(&"font_size", 24)
	_equip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_equip_desc.custom_minimum_size = Vector2(240, 0)
	ecol.add_child(_equip_desc)

	var tip_card := PanelContainer.new()
	tip_card.theme_type_variation = &"CardPanel"
	body.add_child(tip_card)
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override(&"separation", 14)
	tip_card.add_child(tip_row)
	var bulb := UIIconView.make(&"lantern", 46)
	bulb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip_row.add_child(bulb)
	_tip = UIPromptRow.new()
	_tip.label_variation = &"PromptText"
	_tip.font_size = 27
	_tip.glyph_height = 40.0
	_tip.alignment = BoxContainer.ALIGNMENT_BEGIN
	tip_row.add_child(_tip)
	_tip_index = randi() % TIPS.size()


func _titled_card(parent: Container, caption: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = &"CardPanel"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 8)
	card.add_child(col)
	var cap := Label.new()
	cap.text = caption
	cap.theme_type_variation = &"SmallLabel"
	cap.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	cap.add_theme_color_override(&"font_color", UIPalette.WOOD)
	col.add_child(cap)
	return col


func refresh() -> void:
	var island := GameManager.current_island
	_island.text = UIChartData.display_name(island) if island != &"" else "Uncharted Waters"
	for c in _grid.get_children():
		c.queue_free()
	var attachments := InventoryManager.get_attachments().size()
	var charted := 0
	for id in UIChartData.ids():
		if GameManager.is_island_discovered(id):
			charted += 1
	_add_stat(&"coin", "Treasure", UITreasureCounter.format_number(InventoryManager.gold_value))
	_add_stat(&"parrot", "Parrots rescued", str(ParrotManager.get_total()))
	_add_stat(&"hook", "Attachments", "%d / %d" % [attachments, UIAttachmentInfo.ORDER.size()])
	_add_stat(&"compass", "Islands charted", "%d / %d" % [charted, UIChartData.ISLANDS.size()])
	_add_stat(&"treasure_map", "Treasure maps", str(InventoryManager.get_treasure_maps().size()))
	_add_stat(&"ship_wheel", "Ship parts", str(InventoryManager.get_ship_parts().size()))
	var quest := {}
	if UIRoot.instance != null:
		for q: Variant in UIRoot.instance.get_quests():
			if q is Dictionary and not bool(q.get("done", false)):
				quest = q
				break
	_quest_title.text = str(quest.get("title", "Explore the islands"))
	_quest_desc.text = str(quest.get("description", "Talk to the island folk to find work for a hook-handed pirate."))
	var eq := InventoryManager.equipped_attachment
	_equip_icon.icon = UIAttachmentInfo.icon(eq)
	_equip_name.text = UIAttachmentInfo.display_name(eq)
	_equip_desc.text = UIAttachmentInfo.description(eq)
	_tip_index = (_tip_index + 1) % TIPS.size()
	_tip.prompt = TIPS[_tip_index]


func _add_stat(icon: StringName, label: String, value: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 14)
	h.custom_minimum_size = Vector2(440, 0)
	var ic := UIIconView.make(icon, 54)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var v := Label.new()
	v.text = value
	v.theme_type_variation = &"SubheaderLabel"
	v.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	h.add_child(v)
	_grid.add_child(h)


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d:%02d" % [int(s / 3600.0), int(s / 60.0) % 60, s % 60]
