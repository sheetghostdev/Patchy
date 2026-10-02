class_name UIInteractionPrompt
extends PanelContainer
## Bottom-center context prompt: "[E] Pull" / "(Y) Pull". Fed by
## Events.interaction_prompt_changed(prompt, enabled). Keeps a small stack so
## overlapping interactables behave: the most recent enabled prompt shows,
## disabling it reveals the previous one. Tokens like {interact} become glyphs
## for the last used device; with no token the interact glyph is prepended.

var row: UIPromptRow
var _stack: Array[String] = []
var _current := ""
var suppressed := false:
	set(v):
		suppressed = v
		_update()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"PromptPill"
	row = UIPromptRow.new()
	row.auto_interact = true
	row.glyph_height = 48.0
	add_child(row)
	modulate.a = 0.0
	visible = false


func push(prompt: String, enabled: bool) -> void:
	if enabled:
		_stack.erase(prompt)
		if prompt.strip_edges() != "":
			_stack.append(prompt)
	else:
		if prompt == "":
			_stack.clear()
		else:
			_stack.erase(prompt)
	_update()


func clear() -> void:
	_stack.clear()
	_update()


func get_current() -> String:
	return _current


func _update() -> void:
	var want := "" if (_stack.is_empty() or suppressed) else _stack[_stack.size() - 1]
	if want == _current:
		return
	var was_empty := _current == ""
	_current = want
	if want == "":
		UIFx.slide_out(self, Vector2(0, 14), 0.16)
		return
	row.prompt = want
	if was_empty:
		UIFx.slide_in(self, Vector2(0, 26), 0.24)
		UIFx.pop(self, 0.1, 0.3)
	else:
		UIFx.pop(self, 0.08, 0.22)
