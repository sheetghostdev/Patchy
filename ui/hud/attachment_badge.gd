class_name UIAttachmentBadge
extends Control
## Bottom-right brass badge with the equipped hand attachment. Switching
## attachments plays a mechanical "clunk", flashes the attachment's name and
## shows the cycle buttons above the badge for a moment.

@export var badge_size: float = 136.0
@export var name_time: float = 1.8
@export var hint_time: float = 2.6

var attachment: StringName = &""
var icon_view: UIIconView
var name_label: Label
var hint_prev: UIGlyphView
var hint_next: UIGlyphView
var _ring: Control
var _name_timer := 0.0
var _hint_timer := 0.0

const P := preload("res://ui/common/ui_palette.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(badge_size, badge_size)
	_ring = Control.new()
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	UIFx.prepare(_ring)
	icon_view = UIIconView.new()
	var isz := badge_size * 0.64
	icon_view.position = Vector2(badge_size - isz, badge_size - isz) * 0.5
	icon_view.size = Vector2(isz, isz)
	add_child(icon_view)
	UIFx.prepare(icon_view)

	name_label = Label.new()
	name_label.theme_type_variation = &"HudLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	name_label.anchor_left = 0.0
	name_label.anchor_right = 0.0
	name_label.anchor_top = 0.5
	name_label.anchor_bottom = 0.5
	name_label.offset_right = -14.0
	name_label.offset_left = -14.0
	name_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	name_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	name_label.modulate.a = 0.0
	add_child(name_label)

	hint_prev = _make_hint(&"tool_previous")
	hint_prev.position = Vector2(-10, -30)
	hint_next = _make_hint(&"tool_next")
	hint_next.position = Vector2(badge_size - 44, -30)


func _make_hint(action: StringName) -> UIGlyphView:
	var g := UIGlyphView.new()
	g.action = action
	g.glyph_height = 40.0
	g.size = Vector2(54, 40)
	g.modulate.a = 0.0
	add_child(g)
	return g


func set_attachment(id: StringName, animate: bool = true) -> void:
	if id == &"":
		id = &"hook"
	var changed := id != attachment
	attachment = id
	icon_view.icon = UIAttachmentInfo.icon(id)
	icon_view.param = 1.0
	name_label.text = UIAttachmentInfo.display_name(id)
	if animate and changed:
		UIFx.clunk(icon_view, 0.45)
		UIFx.pop(_ring, 0.08, 0.3)
		UIFx.wiggle(icon_view, 10.0, 0.45)
		_name_timer = name_time
		UIFx.fade(name_label, 1.0, 0.12, false)
		show_cycle_hints()
		UIFx.sound(&"ui_equip")


## Show the previous/next buttons (only meaningful with 2+ attachments).
func show_cycle_hints(duration: float = -1.0) -> void:
	var count := 1
	var inv := get_node_or_null(^"/root/InventoryManager")
	if inv != null and inv.has_method(&"get_attachments"):
		count = (inv.call(&"get_attachments") as Array).size()
	if count < 2:
		return
	_hint_timer = hint_time if duration < 0.0 else duration
	UIFx.fade(hint_prev, 1.0, 0.15, false)
	UIFx.fade(hint_next, 1.0, 0.15, false)


func _process(delta: float) -> void:
	if _name_timer > 0.0:
		_name_timer -= delta
		if _name_timer <= 0.0:
			UIFx.fade(name_label, 0.0, 0.4, false)
	if _hint_timer > 0.0:
		_hint_timer -= delta
		if _hint_timer <= 0.0:
			UIFx.fade(hint_prev, 0.0, 0.4, false)
			UIFx.fade(hint_next, 0.0, 0.4, false)


func _draw_ring() -> void:
	var c := Vector2(badge_size, badge_size) * 0.5
	var r := badge_size * 0.5 - 4.0
	_ring.draw_circle(c + Vector2(0, 5), r, Color(0.06, 0.03, 0.02, 0.38), true, -1.0, true)
	_ring.draw_circle(c, r, P.BRASS, true, -1.0, true)
	_ring.draw_arc(c, r - 5.0, PI * 1.05, PI * 1.7, 18, Color(1, 1, 1, 0.45), 4.0, true)
	_ring.draw_arc(c, r - 5.0, PI * 0.05, PI * 0.7, 18, Color(P.BRASS_DARK, 0.6), 4.0, true)
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		_ring.draw_circle(c + Vector2(cos(a), sin(a)) * (r - 8.0), 3.2, P.BRASS_DARK, true, -1.0, true)
		_ring.draw_circle(c + Vector2(cos(a), sin(a)) * (r - 8.0) + Vector2(-0.8, -0.8), 1.4, P.BRASS_LIGHT, true, -1.0, true)
	_ring.draw_circle(c, r - 15.0, P.WOOD_DEEP, true, -1.0, true)
	_ring.draw_circle(c + Vector2(0, -3), r - 20.0, P.WOOD_DARK, true, -1.0, true)
	_ring.draw_circle(c + Vector2(0, -6), r - 30.0, Color(P.WOOD, 0.55), true, -1.0, true)
	_ring.draw_circle(c, r - 15.0, P.OUTLINE, false, 3.0, true)
	_ring.draw_circle(c, r, P.OUTLINE, false, 4.0, true)
