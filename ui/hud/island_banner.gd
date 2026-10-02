class_name UIIslandBanner
extends Control
## Big centered island title on an unfurling parchment ribbon. Fades in,
## holds and fades out over ~3 seconds (Events.island_discovered). Titles
## that arrive while one is showing are queued.

@export var hold_time: float = 2.2
@export_range(0.0, 1.0) var vertical_anchor: float = 0.24

var _group: Control
var _ribbon: UIRibbon
var _title: Label
var _kicker: Label
var _tween: Tween
var _queue: Array = []
var _busy := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_group = Control.new()
	_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_group.anchor_left = 0.5
	_group.anchor_right = 0.5
	_group.anchor_top = vertical_anchor
	_group.anchor_bottom = vertical_anchor
	add_child(_group)
	UIFx.prepare(_group)
	_ribbon = UIRibbon.new()
	_group.add_child(_ribbon)
	UIFx.prepare(_ribbon)
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.add_theme_font_size_override(&"font_size", 68)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_group.add_child(_title)
	UIFx.prepare(_title)
	_kicker = Label.new()
	_kicker.theme_type_variation = &"HudLabel"
	_kicker.add_theme_font_size_override(&"font_size", 26)
	_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_group.add_child(_kicker)
	UIFx.prepare(_kicker)
	_group.visible = false


## Shows `title` with a small line above it ("New Island Discovered").
func show_title(title: String, kicker: String = "New Island Discovered") -> void:
	if _busy:
		_queue.append([title, kicker])
		return
	_busy = true
	_title.text = title
	_kicker.text = "~  %s  ~" % kicker.to_upper() if kicker != "" else ""
	_layout()
	_group.visible = true
	_group.modulate.a = 1.0
	_group.offset_transform_position = Vector2.ZERO
	_ribbon.offset_transform_scale = Vector2(0.15, 1.0)
	_ribbon.modulate.a = 0.0
	_title.modulate.a = 0.0
	_title.offset_transform_scale = Vector2(1.18, 1.18)
	_kicker.modulate.a = 0.0
	_kicker.offset_transform_position = Vector2(0, 14)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(_ribbon, "offset_transform_scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_ribbon, "modulate:a", 1.0, 0.22)
	_tween.tween_property(_title, "modulate:a", 1.0, 0.3).set_delay(0.2)
	_tween.tween_property(_title, "offset_transform_scale", Vector2.ONE, 0.45).set_delay(0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_kicker, "modulate:a", 1.0, 0.3).set_delay(0.3)
	_tween.tween_property(_kicker, "offset_transform_position", Vector2.ZERO, 0.35).set_delay(0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.chain().tween_interval(hold_time)
	_tween.chain().tween_property(_group, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	_tween.parallel().tween_property(_group, "offset_transform_position", Vector2(0, -18), 0.5)
	_tween.chain().tween_callback(_finish)
	UIFx.sound(&"ui_island_reveal")


func is_showing() -> bool:
	return _busy


func _finish() -> void:
	_group.visible = false
	_busy = false
	if not _queue.is_empty():
		var next: Array = _queue.pop_front()
		show_title(next[0], next[1])


func _layout() -> void:
	var f := _title.get_theme_font(&"font")
	var fs := _title.get_theme_font_size(&"font_size")
	var tw := f.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var w := maxf(tw + 170.0, 520.0)
	var h := 112.0
	_ribbon.position = Vector2(-w * 0.5 - 70.0, -h * 0.5)
	_ribbon.size = Vector2(w + 140.0, h + 32.0)
	_ribbon.queue_redraw()
	_title.position = Vector2(-w * 0.5, -h * 0.5 + 4.0)
	_title.size = Vector2(w, h - 6.0)
	_kicker.position = Vector2(-w * 0.5, -h * 0.5 - 50.0)
	_kicker.size = Vector2(w, 40.0)
