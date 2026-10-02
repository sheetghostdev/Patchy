@tool
class_name UIStyle
## StyleBox, font and theme factories. The theme builder
## (ui/tools/build_theme.gd) bakes these into ui/pirate_theme.tres; runtime
## widgets call the same functions so hand-drawn pieces match the theme.
##
## Type variations (set Control.theme_type_variation):
##   Panels:  ParchmentPanel, CardPanel, WoodPanel, DarkPanel, PromptPill,
##            BrassPlate, ToastPanel, DebugPanel, BannerPanel
##   Labels:  HudLabel, HudNumber, TitleLabel, HeaderLabel, SubheaderLabel,
##            SmallLabel, PlateLabel, CreamLabel, PromptText, HintText,
##            DebugLabel, DebugValue
##   Buttons: TitleButton, ListButton, TabButton, BindButton, RowButton
##   Rich text: DialogueText, SubtitleText

const THEME_PATH := "res://ui/pirate_theme.tres"

const P := preload("res://ui/common/ui_palette.gd")

static var _theme: Theme


## The shared theme (loaded once; rebuilt in memory if the .tres is missing).
static func get_theme() -> Theme:
	if _theme == null:
		if ResourceLoader.exists(THEME_PATH):
			_theme = load(THEME_PATH) as Theme
		if _theme == null:
			_theme = build_theme()
	return _theme


## Named fonts stored in the theme under the "Fonts" type:
## body, bold, heavy, mono.
static func font(font_name: StringName = &"body") -> Font:
	var th := get_theme()
	if th.has_font(font_name, &"Fonts"):
		return th.get_font(font_name, &"Fonts")
	return ThemeDB.fallback_font


# --- Fonts -----------------------------------------------------------------------

static func make_font(embolden: float, spacing: int = 0, tabular: bool = false) -> FontVariation:
	var f := FontVariation.new()
	f.variation_embolden = embolden
	f.spacing_glyph = spacing
	if tabular:
		var ts := TextServerManager.get_primary_interface()
		f.opentype_features = {ts.name_to_tag("tnum"): 1}
	return f


# --- StyleBoxes --------------------------------------------------------------------

static func box(bg: Color, radius: int = 14, border: int = 0, border_color: Color = Color.TRANSPARENT,
		margin_h: float = 16.0, margin_v: float = 10.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 10 if radius > 10 else 6
	if border > 0:
		sb.set_border_width_all(border)
		sb.border_color = border_color
	sb.content_margin_left = margin_h
	sb.content_margin_right = margin_h
	sb.content_margin_top = margin_v
	sb.content_margin_bottom = margin_v
	sb.anti_aliasing = true
	return sb


static func with_shadow(sb: StyleBoxFlat, size: int = 14, offset: Vector2 = Vector2(0, 6), alpha: float = 0.35) -> StyleBoxFlat:
	sb.shadow_color = Color(0.1, 0.05, 0.02, alpha)
	sb.shadow_size = size
	sb.shadow_offset = offset
	return sb


static func parchment_panel() -> StyleBoxFlat:
	var sb := box(P.PARCHMENT, 22, 3, P.PARCHMENT_EDGE, 30, 26)
	return with_shadow(sb, 18, Vector2(0, 10), 0.4)


static func card_panel() -> StyleBoxFlat:
	var sb := box(P.PARCHMENT_LIGHT, 16, 2, P.PARCHMENT_DARK, 20, 14)
	return sb


static func card_focus() -> StyleBoxFlat:
	var sb := box(Color(P.BRASS_LIGHT, 0.0), 18, 4, P.BRASS, 0, 0)
	sb.draw_center = false
	sb.set_expand_margin_all(3)
	sb.shadow_color = Color(P.BRASS, 0.45)
	sb.shadow_size = 8
	return sb


static func wood_panel() -> StyleBoxFlat:
	var sb := box(P.WOOD, 18, 4, P.WOOD_DEEP, 24, 20)
	return with_shadow(sb, 18, Vector2(0, 10), 0.45)


static func dark_panel(alpha: float = 0.72) -> StyleBoxFlat:
	return box(Color(P.NAVY, alpha), 16, 0, Color.TRANSPARENT, 22, 12)


static func prompt_pill() -> StyleBoxFlat:
	var sb := box(P.PARCHMENT_LIGHT, 40, 4, P.OUTLINE, 18, 8)
	return with_shadow(sb, 10, Vector2(0, 5), 0.35)


static func brass_plate() -> StyleBoxFlat:
	var sb := box(P.BRASS, 12, 3, P.BRASS_DARK, 22, 8)
	sb.border_width_bottom = 6
	return with_shadow(sb, 8, Vector2(0, 4), 0.35)


static func toast_panel() -> StyleBoxFlat:
	var sb := box(P.PARCHMENT_LIGHT, 18, 3, P.PARCHMENT_EDGE, 22, 12)
	return with_shadow(sb, 10, Vector2(0, 5), 0.3)


static func debug_panel() -> StyleBoxFlat:
	var sb := box(Color(0.06, 0.08, 0.13, 0.86), 12, 2, Color(0.45, 0.62, 0.85, 0.5), 16, 12)
	return sb


static func banner_panel() -> StyleBoxFlat:
	var sb := box(P.PARCHMENT_LIGHT, 10, 4, P.WOOD_DARK, 40, 14)
	return with_shadow(sb, 16, Vector2(0, 8), 0.35)


# Buttons --------------------------------------------------------------------------

static func wood_button(state: StringName) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	match state:
		&"hover":
			sb = box(P.WOOD_LIGHT, 14, 3, P.WOOD_DEEP, 22, 10)
		&"pressed":
			sb = box(P.WOOD_DARK, 14, 3, P.WOOD_DEEP, 22, 10)
		&"disabled":
			sb = box(Color(0.42, 0.36, 0.31, 0.55), 14, 3, Color(0.25, 0.2, 0.16, 0.5), 22, 10)
		_:
			sb = box(P.WOOD, 14, 3, P.WOOD_DEEP, 22, 10)
	if state == &"pressed":
		sb.border_width_bottom = 3
		sb.content_margin_top = 13.0
		sb.content_margin_bottom = 9.0
	else:
		sb.border_width_bottom = 7
		sb.content_margin_bottom = 12.0
	return sb


static func focus_ring(radius: int = 16, expand: float = 5.0) -> StyleBoxFlat:
	var sb := box(Color.TRANSPARENT, radius, 4, P.BRASS_LIGHT, 0, 0)
	sb.draw_center = false
	sb.set_expand_margin_all(expand)
	sb.shadow_color = Color(1.0, 0.8, 0.35, 0.55)
	sb.shadow_size = 10
	return sb


static func tab_button(state: StringName) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	match state:
		&"pressed":
			sb = box(P.PARCHMENT_LIGHT, 14, 3, P.PARCHMENT_EDGE, 22, 8)
		&"hover":
			sb = box(P.PARCHMENT, 14, 2, P.PARCHMENT_EDGE, 22, 8)
		_:
			sb = box(P.PARCHMENT_DARK, 14, 2, Color(P.PARCHMENT_EDGE, 0.6), 22, 8)
	return sb


static func bind_button(state: StringName) -> StyleBoxFlat:
	var sb: StyleBoxFlat
	match state:
		&"hover":
			sb = box(Color("fffaf0"), 10, 2, P.PARCHMENT_EDGE, 14, 6)
		&"pressed":
			sb = box(P.BRASS_LIGHT, 10, 2, P.BRASS_DARK, 14, 6)
		&"disabled":
			sb = box(Color(P.PARCHMENT_DARK, 0.6), 10, 2, Color(P.PARCHMENT_EDGE, 0.4), 14, 6)
		_:
			sb = box(P.PARCHMENT_LIGHT, 10, 2, Color(P.PARCHMENT_EDGE, 0.8), 14, 6)
	sb.border_width_bottom = 4
	return sb


static func row_button(state: StringName) -> StyleBoxFlat:
	match state:
		&"hover", &"pressed":
			return box(Color(P.BRASS_LIGHT, 0.28), 12, 0, Color.TRANSPARENT, 18, 8)
		_:
			return box(Color(0, 0, 0, 0), 12, 0, Color.TRANSPARENT, 18, 8)


# --- Theme --------------------------------------------------------------------------

static func build_theme() -> Theme:
	var th := Theme.new()
	var f_body := make_font(0.15)
	var f_bold := make_font(0.7)
	var f_heavy := make_font(1.25, 1)
	var f_mono := make_font(0.2, 0, true)
	th.default_font = f_body
	th.default_font_size = 28
	th.set_font(&"body", &"Fonts", f_body)
	th.set_font(&"bold", &"Fonts", f_bold)
	th.set_font(&"heavy", &"Fonts", f_heavy)
	th.set_font(&"mono", &"Fonts", f_mono)

	# Label ---------------------------------------------------------------------
	th.set_color(&"font_color", &"Label", P.INK)
	th.set_color(&"font_outline_color", &"Label", P.OUTLINE)
	th.set_color(&"font_shadow_color", &"Label", Color(0, 0, 0, 0))
	th.set_constant(&"outline_size", &"Label", 0)
	th.set_font_size(&"font_size", &"Label", 28)

	_label_variation(th, &"HudLabel", f_bold, 32, P.CREAM, 12, P.OUTLINE, true)
	_label_variation(th, &"HudNumber", f_heavy, 46, P.CREAM, 14, P.OUTLINE, true)
	_label_variation(th, &"TitleLabel", f_heavy, 76, P.CREAM, 20, P.WOOD_DEEP, true)
	_label_variation(th, &"HeaderLabel", f_heavy, 44, P.INK, 0, P.OUTLINE, false)
	_label_variation(th, &"SubheaderLabel", f_bold, 32, P.INK, 0, P.OUTLINE, false)
	_label_variation(th, &"SmallLabel", f_body, 22, P.INK_SOFT, 0, P.OUTLINE, false)
	_label_variation(th, &"PlateLabel", f_heavy, 34, P.WOOD_DEEP, 0, P.OUTLINE, false)
	_label_variation(th, &"CreamLabel", f_bold, 30, P.CREAM, 8, P.WOOD_DEEP, false)
	_label_variation(th, &"PromptText", f_bold, 32, P.INK, 0, P.OUTLINE, false)
	_label_variation(th, &"HintText", f_bold, 24, P.CREAM, 7, P.OUTLINE, false)
	_label_variation(th, &"DebugLabel", f_mono, 19, Color("9fb4d0"), 0, P.OUTLINE, false)
	_label_variation(th, &"DebugValue", f_mono, 19, Color("eef4ff"), 0, P.OUTLINE, false)

	# RichTextLabel ---------------------------------------------------------------
	th.set_color(&"default_color", &"RichTextLabel", P.INK)
	th.set_font(&"normal_font", &"RichTextLabel", f_body)
	th.set_font(&"bold_font", &"RichTextLabel", f_bold)
	th.set_font(&"italics_font", &"RichTextLabel", _italic(f_body))
	th.set_font(&"mono_font", &"RichTextLabel", f_mono)
	for s: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"mono_font_size"]:
		th.set_font_size(s, &"RichTextLabel", 28)
	th.set_stylebox(&"normal", &"RichTextLabel", StyleBoxEmpty.new())
	th.set_stylebox(&"focus", &"RichTextLabel", StyleBoxEmpty.new())
	th.set_type_variation(&"DialogueText", &"RichTextLabel")
	for s: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"mono_font_size"]:
		th.set_font_size(s, &"DialogueText", 33)
	th.set_constant(&"line_separation", &"DialogueText", 4)
	th.set_type_variation(&"SubtitleText", &"RichTextLabel")
	th.set_color(&"default_color", &"SubtitleText", P.CREAM)
	th.set_color(&"font_outline_color", &"SubtitleText", Color(0.05, 0.04, 0.08, 0.9))
	th.set_constant(&"outline_size", &"SubtitleText", 8)
	for s: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"mono_font_size"]:
		th.set_font_size(s, &"SubtitleText", 31)

	# Panels -------------------------------------------------------------------------
	th.set_stylebox(&"panel", &"PanelContainer", parchment_panel())
	th.set_stylebox(&"panel", &"Panel", parchment_panel())
	_panel_variation(th, &"ParchmentPanel", parchment_panel())
	_panel_variation(th, &"CardPanel", card_panel())
	_panel_variation(th, &"WoodPanel", wood_panel())
	_panel_variation(th, &"DarkPanel", dark_panel())
	_panel_variation(th, &"PromptPill", prompt_pill())
	_panel_variation(th, &"BrassPlate", brass_plate())
	_panel_variation(th, &"ToastPanel", toast_panel())
	_panel_variation(th, &"DebugPanel", debug_panel())
	_panel_variation(th, &"BannerPanel", banner_panel())
	th.set_type_variation(&"ClearPanel", &"PanelContainer")
	th.set_stylebox(&"panel", &"ClearPanel", StyleBoxEmpty.new())

	# Buttons --------------------------------------------------------------------------
	for st: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		th.set_stylebox(st, &"Button", wood_button(st))
	th.set_stylebox(&"hover_pressed", &"Button", wood_button(&"pressed"))
	th.set_stylebox(&"focus", &"Button", focus_ring())
	th.set_font(&"font", &"Button", f_bold)
	th.set_font_size(&"font_size", &"Button", 30)
	th.set_constant(&"outline_size", &"Button", 7)
	th.set_constant(&"h_separation", &"Button", 14)
	th.set_color(&"font_outline_color", &"Button", P.WOOD_DEEP)
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		th.set_color(c, &"Button", P.CREAM)
	th.set_color(&"font_hover_color", &"Button", Color("fffbe9"))
	th.set_color(&"font_disabled_color", &"Button", Color(0.92, 0.88, 0.8, 0.55))

	th.set_type_variation(&"TitleButton", &"Button")
	th.set_font_size(&"font_size", &"TitleButton", 38)
	th.set_constant(&"outline_size", &"TitleButton", 9)
	for st: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var sb := wood_button(st)
		sb.content_margin_left = 40
		sb.content_margin_right = 40
		sb.content_margin_top += 4
		sb.content_margin_bottom += 4
		th.set_stylebox(st, &"TitleButton", with_shadow(sb, 10, Vector2(0, 6), 0.3))
	th.set_stylebox(&"focus", &"TitleButton", focus_ring(18, 6))

	th.set_type_variation(&"ListButton", &"Button")
	th.set_font_size(&"font_size", &"ListButton", 31)
	for st: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		var sb := wood_button(st)
		sb.content_margin_left = 82
		th.set_stylebox(st, &"ListButton", sb)

	th.set_type_variation(&"TabButton", &"Button")
	th.set_font(&"font", &"TabButton", f_bold)
	th.set_font_size(&"font_size", &"TabButton", 26)
	th.set_constant(&"outline_size", &"TabButton", 0)
	th.set_stylebox(&"normal", &"TabButton", tab_button(&"normal"))
	th.set_stylebox(&"hover", &"TabButton", tab_button(&"hover"))
	th.set_stylebox(&"pressed", &"TabButton", tab_button(&"pressed"))
	th.set_stylebox(&"hover_pressed", &"TabButton", tab_button(&"pressed"))
	th.set_stylebox(&"disabled", &"TabButton", tab_button(&"normal"))
	th.set_stylebox(&"focus", &"TabButton", focus_ring(14, 4))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color"]:
		th.set_color(c, &"TabButton", P.INK_SOFT)
	th.set_color(&"font_pressed_color", &"TabButton", P.INK)
	th.set_color(&"font_hover_pressed_color", &"TabButton", P.INK)

	th.set_type_variation(&"BindButton", &"Button")
	th.set_font(&"font", &"BindButton", f_bold)
	th.set_font_size(&"font_size", &"BindButton", 24)
	th.set_constant(&"outline_size", &"BindButton", 0)
	for st: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		th.set_stylebox(st, &"BindButton", bind_button(st))
	th.set_stylebox(&"hover_pressed", &"BindButton", bind_button(&"pressed"))
	th.set_stylebox(&"focus", &"BindButton", focus_ring(12, 4))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		th.set_color(c, &"BindButton", P.INK)
	th.set_color(&"font_disabled_color", &"BindButton", P.INK_FAINT)

	th.set_type_variation(&"RowButton", &"Button")
	th.set_font(&"font", &"RowButton", f_bold)
	th.set_font_size(&"font_size", &"RowButton", 28)
	th.set_constant(&"outline_size", &"RowButton", 0)
	for st: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		th.set_stylebox(st, &"RowButton", row_button(st))
	th.set_stylebox(&"hover_pressed", &"RowButton", row_button(&"pressed"))
	th.set_stylebox(&"focus", &"RowButton", focus_ring(12, 2))
	for c: StringName in [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		th.set_color(c, &"RowButton", P.INK)

	# Slider ----------------------------------------------------------------------------
	var track := box(Color(P.WOOD_DEEP, 0.55), 7, 0, Color.TRANSPARENT, 0, 6)
	var fill := box(P.BRASS, 7, 0, Color.TRANSPARENT, 0, 6)
	var fill_hi := box(P.BRASS_LIGHT, 7, 0, Color.TRANSPARENT, 0, 6)
	th.set_stylebox(&"slider", &"HSlider", track)
	th.set_stylebox(&"grabber_area", &"HSlider", fill)
	th.set_stylebox(&"grabber_area_highlight", &"HSlider", fill_hi)
	th.set_icon(&"grabber", &"HSlider", _knob_texture(P.BRASS, P.BRASS_DARK, 34))
	th.set_icon(&"grabber_highlight", &"HSlider", _knob_texture(P.BRASS_LIGHT, P.BRASS_DARK, 38))
	th.set_icon(&"grabber_disabled", &"HSlider", _knob_texture(Color(0.6, 0.55, 0.5), Color(0.35, 0.3, 0.25), 30))
	th.set_constant(&"center_grabber", &"HSlider", 1)

	# Scrollbars -----------------------------------------------------------------------
	var sc_track := box(Color(P.WOOD_DEEP, 0.18), 6, 0, Color.TRANSPARENT, 6, 6)
	th.set_stylebox(&"scroll", &"VScrollBar", sc_track)
	th.set_stylebox(&"scroll_focus", &"VScrollBar", sc_track)
	th.set_stylebox(&"grabber", &"VScrollBar", box(Color(P.WOOD, 0.85), 6, 0, Color.TRANSPARENT, 6, 6))
	th.set_stylebox(&"grabber_highlight", &"VScrollBar", box(P.WOOD_LIGHT, 6, 0, Color.TRANSPARENT, 6, 6))
	th.set_stylebox(&"grabber_pressed", &"VScrollBar", box(P.WOOD_DARK, 6, 0, Color.TRANSPARENT, 6, 6))
	th.set_stylebox(&"panel", &"ScrollContainer", StyleBoxEmpty.new())
	th.set_stylebox(&"focus", &"ScrollContainer", StyleBoxEmpty.new())

	# Tooltips --------------------------------------------------------------------------
	th.set_stylebox(&"panel", &"TooltipPanel", toast_panel())
	th.set_color(&"font_color", &"TooltipLabel", P.INK)
	th.set_font_size(&"font_size", &"TooltipLabel", 22)

	# Containers --------------------------------------------------------------------------
	th.set_constant(&"separation", &"VBoxContainer", 12)
	th.set_constant(&"separation", &"HBoxContainer", 12)
	return th


static func _label_variation(th: Theme, type_name: StringName, f: Font, size: int, color: Color,
		outline: int, outline_color: Color, shadow: bool) -> void:
	th.set_type_variation(type_name, &"Label")
	th.set_font(&"font", type_name, f)
	th.set_font_size(&"font_size", type_name, size)
	th.set_color(&"font_color", type_name, color)
	th.set_constant(&"outline_size", type_name, outline)
	th.set_color(&"font_outline_color", type_name, outline_color)
	if shadow:
		th.set_color(&"font_shadow_color", type_name, P.SHADOW)
		th.set_constant(&"shadow_offset_x", type_name, 0)
		th.set_constant(&"shadow_offset_y", type_name, 5)
		th.set_constant(&"shadow_outline_size", type_name, outline)


static func _panel_variation(th: Theme, type_name: StringName, sb: StyleBox) -> void:
	th.set_type_variation(type_name, &"PanelContainer")
	th.set_stylebox(&"panel", type_name, sb)


static func _italic(base: FontVariation) -> FontVariation:
	var f := FontVariation.new()
	f.variation_embolden = base.variation_embolden
	f.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	return f


## Round brass knob for sliders, built from a radial gradient (no image files).
static func _knob_texture(face: Color, rim: Color, px: int) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.5, 0.74, 0.86, 0.93, 1.0])
	g.colors = PackedColorArray([
		face.lightened(0.35), face, face.darkened(0.05), rim, Color(rim, 0.6), Color(rim, 0.0),
	])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = px
	t.height = px
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	return t
