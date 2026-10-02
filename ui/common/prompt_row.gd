class_name UIPromptRow
extends HBoxContainer
## Renders text with inline input glyphs. Tokens in braces name InputMap
## actions and become glyphs for the last used device:
##   "{interact} Talk"          -> [E] Talk   /  (Y) Talk
##   "{tool_primary} Dig"       -> [RMB] Dig  /  (RT) Dig
##   "Hold {jump} to skip"
## When `auto_interact` is on and the text has no tokens, the interact glyph is
## prepended. Use the token {-} to suppress that.
## Fixed gamepad buttons (not actions) use pad_* tokens: {pad_a} {pad_b}
## {pad_x} {pad_y} {pad_lb} {pad_rb} {pad_start} {pad_back}.

const TOKEN_RE := "\\{([A-Za-z0-9_\\-]+)\\}"
const PAD_TOKENS := {
	"pad_a": JOY_BUTTON_A, "pad_b": JOY_BUTTON_B, "pad_x": JOY_BUTTON_X, "pad_y": JOY_BUTTON_Y,
	"pad_lb": JOY_BUTTON_LEFT_SHOULDER, "pad_rb": JOY_BUTTON_RIGHT_SHOULDER,
	"pad_start": JOY_BUTTON_START, "pad_back": JOY_BUTTON_BACK,
}

@export_multiline var prompt: String = "":
	set(v):
		if v == prompt and get_child_count() > 0:
			return
		prompt = v
		_rebuild()
@export var label_variation: StringName = &"PromptText"
@export var glyph_height: float = 46.0
@export var auto_interact: bool = false
## 0 keeps the theme size.
@export var font_size: int = 0
## Extra space inserted where the text has 2+ consecutive spaces.
@export var gap_width: float = 26.0

var _re := RegEx.create_from_string(TOKEN_RE)
var _gap_re := RegEx.create_from_string("\\s{2,}")


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override(&"separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var text := prompt
	var matches := _re.search_all(text)
	var has_token := false
	for m in matches:
		var t := m.get_string(1)
		if t == "-" or PAD_TOKENS.has(t) or InputMap.has_action(StringName(t)):
			has_token = true
	if not has_token and auto_interact and text.strip_edges() != "":
		_add_glyph(&"interact")
	var cursor := 0
	for m in matches:
		_add_text(text.substr(cursor, m.get_start() - cursor))
		var tok := m.get_string(1)
		if tok != "-":
			if PAD_TOKENS.has(tok):
				var ev := InputEventJoypadButton.new()
				ev.button_index = PAD_TOKENS[tok]
				_add_glyph(&"", ev)
			elif InputMap.has_action(StringName(tok)):
				_add_glyph(StringName(tok))
			else:
				_add_text(tok)
		cursor = m.get_end()
	_add_text(text.substr(cursor))


## Text segment; runs of 2+ spaces become wider gaps (for hint bars like
## "{ui_accept} Select    {ui_cancel} Back").
func _add_text(s: String) -> void:
	var pos := 0
	for m in _gap_re.search_all(s):
		_add_label(s.substr(pos, m.get_start() - pos))
		if get_child_count() > 0:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(gap_width, 0)
			gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(gap)
		pos = m.get_end()
	_add_label(s.substr(pos))


func _add_label(s: String) -> void:
	var t := s.strip_edges()
	if t == "":
		return
	var l := Label.new()
	l.text = t
	l.theme_type_variation = label_variation
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font_size > 0:
		l.add_theme_font_size_override(&"font_size", font_size)
	add_child(l)


func _add_glyph(action: StringName, fixed_event: InputEvent = null) -> void:
	var g := UIGlyphView.new()
	g.glyph_height = glyph_height
	if fixed_event != null:
		g.event = fixed_event
	else:
		g.action = action
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(g)
