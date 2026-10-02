class_name UIToastStack
extends VBoxContainer
## Short parchment notes that drop in at the top of the screen
## (Events.hud_message, unlocks, checkpoints, quick saves). Newest at the top;
## at most `max_toasts` are kept.

@export var max_toasts: int = 4
@export var default_duration: float = 2.6


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override(&"separation", 10)


func show_toast(text: String, duration: float = -1.0, icon: StringName = &"") -> void:
	if text.strip_edges() == "":
		return
	var d := default_duration if duration <= 0.0 else duration
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	if icon != &"":
		var ic := UIIconView.make(icon, 42)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
	var pr := UIPromptRow.new()
	pr.label_variation = &"PromptText"
	pr.font_size = 28
	pr.glyph_height = 38.0
	pr.prompt = text
	row.add_child(pr)
	add_child(panel)
	move_child(panel, 0)
	UIFx.slide_in(panel, Vector2(0, -30), 0.3)
	while get_child_count() > max_toasts:
		var old := get_child(get_child_count() - 1)
		remove_child(old)
		old.queue_free()
	var tw := panel.create_tween()
	tw.tween_interval(d)
	tw.tween_property(panel, "modulate:a", 0.0, 0.35).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(panel.queue_free)


func clear() -> void:
	for c in get_children():
		c.queue_free()
