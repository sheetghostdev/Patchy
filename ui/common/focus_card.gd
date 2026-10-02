class_name UIFocusCard
extends PanelContainer
## A focusable parchment card (list rows in menus). Shows a brass focus ring
## and lifts slightly when focused, so controller users can scroll lists.

signal activated

@export var focusable: bool = true


func _ready() -> void:
	theme_type_variation = &"CardPanel"
	focus_mode = Control.FOCUS_ALL if focusable else Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_STOP
	UIFx.prepare(self)
	focus_entered.connect(_on_focus.bind(true))
	focus_exited.connect(_on_focus.bind(false))
	mouse_entered.connect(func() -> void:
		if focusable:
			grab_focus())


func _on_focus(on: bool) -> void:
	queue_redraw()
	var tw := create_tween()
	tw.tween_property(self, "offset_transform_scale", Vector2.ONE * (1.012 if on else 1.0), 0.12)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		activated.emit()
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		activated.emit()


func _draw() -> void:
	if has_focus():
		draw_style_box(UIStyle.focus_ring(16, 4), Rect2(Vector2.ZERO, size))
