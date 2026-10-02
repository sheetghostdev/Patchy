class_name UIParrotRequirement
extends PanelContainer
## "Parrot gate" indicator shown near a parrot task: [parrot] 4 / 6.
## Parchment while the flock is too small, turns green with a check once
## `have >= required`. Driven by Events.parrot_requirement_shown.

var required: int = 0
var have: int = 0
var shown := false
var met := false

var _icon: UIIconView
var _have_label: Label
var _of_label: Label
var _check: UIIconView
var _style_normal: StyleBoxFlat
var _style_met: StyleBoxFlat

const P := preload("res://ui/common/ui_palette.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_normal = UIStyle.prompt_pill()
	_style_normal.content_margin_left = 14
	_style_normal.content_margin_right = 22
	_style_met = _style_normal.duplicate() as StyleBoxFlat
	_style_met.bg_color = P.GREEN
	_style_met.border_color = P.GREEN_DARK.darkened(0.3)
	add_theme_stylebox_override(&"panel", _style_normal)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_icon = UIIconView.make(&"parrot", 50)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_icon)
	_have_label = Label.new()
	_have_label.theme_type_variation = &"PromptText"
	_have_label.add_theme_font_size_override(&"font_size", 36)
	_have_label.add_theme_font_override(&"font", UIStyle.font(&"heavy"))
	row.add_child(_have_label)
	UIFx.prepare(_have_label)
	_of_label = Label.new()
	_of_label.theme_type_variation = &"PromptText"
	_of_label.add_theme_font_size_override(&"font_size", 30)
	row.add_child(_of_label)
	_check = UIIconView.make(&"check", 40, 0.0)
	_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_check.visible = false
	row.add_child(_check)
	modulate.a = 0.0
	visible = false


func set_requirement(req: int, h: int, show_it: bool) -> void:
	var was_met := met
	var was_shown := shown
	var have_changed := h != have
	required = req
	have = h
	met = have >= required
	_have_label.text = str(have)
	_of_label.text = "/ %d" % required
	_apply_style()
	if show_it and not was_shown:
		shown = true
		UIFx.slide_in(self, Vector2(0, 24), 0.28)
		UIFx.pop(self, 0.08, 0.3)
	elif not show_it and was_shown:
		shown = false
		UIFx.slide_out(self, Vector2(0, 16), 0.2)
	elif show_it and have_changed:
		UIFx.pop(_have_label, 0.35, 0.35)
	if show_it and met and not was_met and was_shown:
		UIFx.pop(self, 0.15, 0.4)
		UIFx.wiggle(_icon, 12.0, 0.6)
		UIFx.sound(&"ui_select")


func _apply_style() -> void:
	add_theme_stylebox_override(&"panel", _style_met if met else _style_normal)
	_check.visible = met
	var text_col := P.CREAM if met else P.INK
	var have_col := P.CREAM if met else P.RED_DARK
	_of_label.add_theme_color_override(&"font_color", text_col)
	_have_label.add_theme_color_override(&"font_color", have_col)
	for l: Label in [_of_label, _have_label]:
		l.add_theme_constant_override(&"outline_size", 8 if met else 0)
		l.add_theme_color_override(&"font_outline_color", P.GREEN_DARK.darkened(0.35))
