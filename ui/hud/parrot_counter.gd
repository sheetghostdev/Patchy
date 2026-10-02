class_name UIParrotCounter
extends HBoxContainer
## Contextual flock counter: pops in for a few seconds whenever the flock
## changes (a parrot is rescued), then tucks away again.

@export var icon_size: float = 62.0
@export var show_time: float = 3.0

var total: int = 0
var parrot: UIIconView
var label: Label
var _timer := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 8)
	parrot = UIIconView.make(&"parrot", icon_size)
	parrot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(parrot)
	label = Label.new()
	label.theme_type_variation = &"HudNumber"
	label.text = "0"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	UIFx.prepare(label)
	label.offset_transform_pivot_ratio = Vector2(0.0, 0.5)
	modulate.a = 0.0
	visible = false


func set_total(n: int, animate: bool = true) -> void:
	var changed := n != total
	total = n
	label.text = str(n)
	if animate and changed:
		reveal(show_time)
		UIFx.pop(label, 0.3, 0.4)
		UIFx.wiggle(parrot, 14.0, 0.7)
		UIFx.pop(parrot, 0.18, 0.35)


func reveal(duration: float = -1.0) -> void:
	_timer = show_time if duration < 0.0 else duration
	if not visible or modulate.a < 0.99:
		UIFx.fade(self, 1.0, 0.18)


func _process(delta: float) -> void:
	if _timer > 0.0:
		_timer -= delta
		if _timer <= 0.0:
			UIFx.fade(self, 0.0, 0.35)
