class_name UISubtitles
extends VBoxContainer
## Ambient bark subtitles: high-contrast cream text on a dark band, shown only
## when Settings.subtitles is on. Up to two lines stack; each expires on its
## own timer.

@export var max_lines: int = 2
@export var max_width: float = 1100.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override(&"separation", 8)


func show_subtitle(text: String, duration: float = 3.0, speaker: String = "") -> void:
	if not _enabled() or text.strip_edges() == "":
		return
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"DarkPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rt := RichTextLabel.new()
	rt.theme_type_variation = &"SubtitleText"
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body := text.replace("[", "[lb]")
	if speaker != "":
		rt.text = "[color=#%s][b]%s:[/b][/color] %s" % [UIPalette.BRASS_LIGHT.to_html(false), speaker.replace("[", "[lb]"), body]
	else:
		rt.text = body
	panel.add_child(rt)
	add_child(panel)
	# Size to the text (theme fonts resolve once in the tree); wrap past max_width.
	var fs := rt.get_theme_font_size(&"normal_font_size")
	var w := rt.get_theme_font(&"normal_font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if speaker != "":
		w += rt.get_theme_font(&"bold_font").get_string_size(speaker + ": ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	rt.custom_minimum_size = Vector2(minf(w + 12.0, max_width), 0)
	UIFx.slide_in(panel, Vector2(0, 12), 0.2)
	while get_child_count() > max_lines:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	var tw := panel.create_tween()
	tw.tween_interval(maxf(duration, 0.5))
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	tw.tween_callback(panel.queue_free)


func clear() -> void:
	for c in get_children():
		c.queue_free()


func _enabled() -> bool:
	var st := get_node_or_null(^"/root/Settings")
	return st == null or bool(st.get(&"subtitles"))
