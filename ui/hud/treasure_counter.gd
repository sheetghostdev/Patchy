class_name UITreasureCounter
extends HBoxContainer
## Gold coin + total treasure value. Changes tick up with a bouncy count, the
## coin spins, a "+N" floats away, and after a while of inactivity the counter
## tucks itself away (contextual HUD).

@export var icon_size: float = 58.0
@export var auto_hide: bool = true
@export var idle_hide_time: float = 4.0

var value: int = 0
var _shown_value: float = 0.0
var _last_shown_int: int = 0
var _idle := 0.0
var _count_tween: Tween
var _spin_t := -1.0
var _tick_cooldown := 0.0

var coin: UIIconView
var label: Label
var _float_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 10)
	coin = UIIconView.make(&"coin", icon_size)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(coin)
	label = Label.new()
	label.theme_type_variation = &"HudNumber"
	label.text = "0"
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	UIFx.prepare(label)
	label.offset_transform_pivot_ratio = Vector2(0.0, 0.5)
	_float_layer = Control.new()
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.custom_minimum_size = Vector2(1, 1)
	add_child(_float_layer)
	if auto_hide:
		modulate.a = 0.0
		visible = false


static func format_number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func set_value(v: int, animate: bool = true) -> void:
	var delta := v - value
	value = v
	if not animate or delta == 0:
		_shown_value = v
		_last_shown_int = v
		label.text = format_number(v)
		return
	reveal()
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	var dur := clampf(0.3 + log(float(absi(delta)) + 1.0) * 0.12, 0.3, 1.1)
	_count_tween = create_tween()
	_count_tween.tween_method(_set_shown, _shown_value, float(v), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_count_tween.tween_callback(func() -> void: UIFx.pop(label, 0.22, 0.3))
	_spin_t = 0.0
	if delta > 0:
		_spawn_floater("+" + format_number(delta))


func _set_shown(f: float) -> void:
	_shown_value = f
	var n := roundi(f)
	if n != _last_shown_int:
		_last_shown_int = n
		label.text = format_number(n)
		if _tick_cooldown <= 0.0:
			_tick_cooldown = 0.06
			UIFx.pop(label, 0.1, 0.12)
			UIFx.sound(&"ui_coin_tick", -10.0)


## Shows the counter and restarts the inactivity timer.
func reveal(hold: float = -1.0) -> void:
	_idle = 0.0 if hold < 0.0 else idle_hide_time - hold
	if not visible or modulate.a < 0.99:
		UIFx.fade(self, 1.0, 0.18)


func conceal() -> void:
	if visible:
		UIFx.fade(self, 0.0, 0.35)


func _process(delta: float) -> void:
	_tick_cooldown -= delta
	if _spin_t >= 0.0:
		_spin_t += delta
		var t := _spin_t / 0.7
		if t >= 1.0:
			_spin_t = -1.0
			coin.offset_transform_scale = Vector2.ONE
		else:
			# Coin flip: squash horizontally through two half turns.
			coin.offset_transform_scale = Vector2(absf(cos(t * TAU)) * 0.85 + 0.15, 1.0)
	if auto_hide and visible and modulate.a > 0.0:
		var busy := _count_tween != null and _count_tween.is_running()
		if not busy:
			_idle += delta
			if _idle >= idle_hide_time:
				conceal()


func _spawn_floater(t: String) -> void:
	var l := Label.new()
	l.theme_type_variation = &"HudLabel"
	l.text = t
	l.add_theme_color_override(&"font_color", UIPalette.GOLD_LIGHT)
	l.add_theme_font_size_override(&"font_size", 30)
	_float_layer.add_child(l)
	l.position = Vector2(12, -4)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", -46.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)
