extends Control
## Visual check for procedural icons and input glyphs:
##   tools/photo/shoot.sh scene=res://ui/tests/icon_gallery.tscn out=/tmp/icons.png size=1600x900

const ICONS: Array[StringName] = [
	&"heart", &"coin", &"parrot", &"chest", &"treasure_map", &"ship_wheel", &"compass",
	&"quest", &"cog", &"play", &"anchor", &"flag", &"check", &"lock", &"star", &"skull",
	&"ship", &"question", &"hook", &"grapple", &"shovel", &"cannon", &"lantern", &"harpoon",
	&"spring_fist",
]
const ACTIONS: Array[StringName] = [
	&"interact", &"jump", &"attack", &"tool_primary", &"tool_next", &"tool_previous",
	&"dive", &"crouch", &"pause", &"map", &"camera_reset", &"tool_secondary", &"move_left", &"walk",
]


func _ready() -> void:
	theme = UIStyle.get_theme()
	var bg := ColorRect.new()
	bg.color = UIPalette.PARCHMENT
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var dark := ColorRect.new()
	dark.color = Color("2b3a4a")
	dark.position = Vector2(0, 560)
	dark.size = Vector2(1920, 520)
	add_child(dark)
	var grid := GridContainer.new()
	grid.columns = 13
	grid.position = Vector2(40, 30)
	grid.add_theme_constant_override(&"h_separation", 30)
	grid.add_theme_constant_override(&"v_separation", 16)
	add_child(grid)
	for id in ICONS:
		var v := VBoxContainer.new()
		var ic := UIIconView.make(id, 104, 1.0 if id != &"heart" else 1.0)
		v.add_child(ic)
		var l := Label.new()
		l.text = String(id)
		l.theme_type_variation = &"SmallLabel"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		grid.add_child(v)
	var hearts := HBoxContainer.new()
	hearts.position = Vector2(40, 380)
	add_child(hearts)
	for f: float in [1.0, 0.5, 0.0]:
		hearts.add_child(UIIconView.make(&"heart", 72, f))
	for id: StringName in [&"coin", &"parrot", &"hook"]:
		hearts.add_child(UIIconView.make(id, 48))
		hearts.add_child(UIIconView.make(id, 32))
	# Glyph rows: keyboard, xbox, playstation, nintendo.
	var y := 590.0
	var styles := [[false, InputGlyphs.PadStyle.XBOX], [true, InputGlyphs.PadStyle.XBOX],
		[true, InputGlyphs.PadStyle.PLAYSTATION], [true, InputGlyphs.PadStyle.NINTENDO]]
	for st: Array in styles:
		InputGlyphs.pad_style = st[1]
		var row := HBoxContainer.new()
		row.position = Vector2(40, y)
		row.add_theme_constant_override(&"separation", 18)
		add_child(row)
		for a in ACTIONS:
			var g := UIGlyphView.new()
			g.glyph_height = 52
			g.force_device = 1 if st[0] else 0
			g.action = a
			row.add_child(g)
		# Freeze the description now (pad_style is global).
		await get_tree().process_frame
		y += 84.0
	InputGlyphs.pad_style = InputGlyphs.PadStyle.XBOX
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"PromptPill"
	pill.position = Vector2(40, 930)
	add_child(pill)
	var pr := UIPromptRow.new()
	pr.prompt = "{interact} Talk to Captain Gull"
	pill.add_child(pr)
	var pill2 := PanelContainer.new()
	pill2.theme_type_variation = &"PromptPill"
	pill2.position = Vector2(700, 930)
	add_child(pill2)
	var pr2 := UIPromptRow.new()
	pr2.prompt = "{tool_primary} Dig    {attack} Swipe"
	pill2.add_child(pr2)
