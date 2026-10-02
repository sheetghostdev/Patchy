@tool
class_name UIIconView
extends Control
## A Control that paints one procedural icon (see UIIcons) scaled to fit.
## Animate it with `offset_transform_*` (pops, shakes) so containers keep
## their layout.

@export var icon: StringName = &"coin":
	set(v):
		icon = v
		queue_redraw()
## Icon-specific parameter (heart fill 0..1, lantern glow...).
@export var param: float = 1.0:
	set(v):
		param = v
		queue_redraw()
## Draw as a flat silhouette (locked / undiscovered things).
@export var silhouette: bool = false:
	set(v):
		silhouette = v
		_apply_silhouette()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	offset_transform_enabled = true
	offset_transform_visual_only = true
	offset_transform_pivot_ratio = Vector2(0.5, 0.5)
	_apply_silhouette()


func _apply_silhouette() -> void:
	self_modulate = Color(0.25, 0.17, 0.11, 0.38) if silhouette else Color.WHITE
	queue_redraw()


func _draw() -> void:
	UIIcons.draw_icon(self, icon, Rect2(Vector2.ZERO, size), param)


static func make(icon_id: StringName, px: float, p: float = 1.0) -> UIIconView:
	var v := UIIconView.new()
	v.icon = icon_id
	v.param = p
	v.custom_minimum_size = Vector2(px, px)
	return v
