class_name UIHeartsDisplay
extends Control
## Patchy's hearts. Lost hearts pop and deflate while the row shakes; gained
## hearts refill one after another with a bounce. At one heart left the last
## heart beats gently (a scale pulse, never a flash).

@export var heart_size: float = 66.0:
	set(v):
		heart_size = v
		update_minimum_size()
@export var spacing: float = 4.0

var health: int = 4
var max_health: int = 4

var _fill: PackedFloat32Array = PackedFloat32Array()     # displayed fill per heart
var _target: PackedFloat32Array = PackedFloat32Array()   # wanted fill per heart
var _delay: PackedFloat32Array = PackedFloat32Array()    # stagger before refilling
var _pop: PackedFloat32Array = PackedFloat32Array()      # pop timer per heart (<0 idle)
var _flash: PackedFloat32Array = PackedFloat32Array()    # white/red overlay 0..1
var _shake := 0.0
var _beat_t := 0.0
var _time := 0.0

const POP_TIME := 0.42


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize(max_health)
	set_health(health, max_health, false)


func _get_minimum_size() -> Vector2:
	return Vector2(maxi(max_health, 1) * (heart_size + spacing) - spacing, heart_size)


func _resize(n: int) -> void:
	var old := _fill.size()
	_fill.resize(n)
	_target.resize(n)
	_delay.resize(n)
	_pop.resize(n)
	_flash.resize(n)
	for i in range(old, n):
		_fill[i] = 0.0
		_target[i] = 0.0
		_delay[i] = 0.0
		_pop[i] = -1.0
		_flash[i] = 0.0


func set_health(h: int, m: int, animate: bool = true) -> void:
	var old_h := health
	var old_m := max_health
	max_health = maxi(m, 1)
	health = clampi(h, 0, max_health)
	if max_health != old_m or _fill.size() != max_health:
		_resize(max_health)
		update_minimum_size()
	var gained := 0
	for i in max_health:
		var want := 1.0 if i < health else 0.0
		if not animate:
			_fill[i] = want
			_target[i] = want
			_delay[i] = 0.0
			continue
		if want < _target[i]:
			# Lost: punch, flash, then deflate.
			_pop[i] = 0.0
			_flash[i] = 1.0
			_delay[i] = 0.12
		elif want > _target[i]:
			_delay[i] = 0.1 + 0.13 * gained
			gained += 1
		_target[i] = want
	if animate and health < old_h:
		_shake = 1.0
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	var busy := _shake > 0.0
	_shake = maxf(_shake - delta / 0.45, 0.0)
	for i in _fill.size():
		if _delay[i] > 0.0:
			_delay[i] -= delta
			busy = true
			continue
		if not is_equal_approx(_fill[i], _target[i]):
			var speed := 9.0 if _target[i] > _fill[i] else 5.5
			var before := _fill[i]
			_fill[i] = move_toward(_fill[i], _target[i], delta * speed)
			if _target[i] > before and is_equal_approx(_fill[i], _target[i]):
				_pop[i] = 0.0
				_flash[i] = 0.7
				UIFx.sound(&"ui_heart_fill", -6.0)
			busy = true
		if _pop[i] >= 0.0:
			_pop[i] += delta
			if _pop[i] > POP_TIME:
				_pop[i] = -1.0
			busy = true
		if _flash[i] > 0.0:
			_flash[i] = maxf(_flash[i] - delta * 4.0, 0.0)
			busy = true
	if health == 1 and max_health > 1:
		_beat_t += delta
		busy = true
	else:
		_beat_t = 0.0
	if busy:
		queue_redraw()


func _beat_scale() -> float:
	# Two quick thumps per second-ish, like a heartbeat.
	var t := fmod(_beat_t, 1.1)
	var a := exp(-pow((t - 0.1) / 0.06, 2.0))
	var b := exp(-pow((t - 0.32) / 0.07, 2.0)) * 0.6
	return 1.0 + 0.12 * (a + b)


func _draw() -> void:
	var reduce := _reduce_flashing()
	var shake_x := sin(_time * 55.0) * 9.0 * _shake * _shake
	for i in _fill.size():
		var s := 1.0
		if _pop[i] >= 0.0:
			var t := _pop[i] / POP_TIME
			s += 0.32 * sin(t * PI) * (1.0 - t * 0.4)
		if i == 0 and health == 1 and max_health > 1:
			s *= _beat_scale()
		var cx := i * (heart_size + spacing) + heart_size * 0.5 + shake_x
		var cy := heart_size * 0.5
		var sz := heart_size * s
		var r := Rect2(Vector2(cx, cy) - Vector2(sz, sz) * 0.5, Vector2(sz, sz))
		UIIcons.draw_icon(self, &"heart", r, _fill[i])
		if _flash[i] > 0.01:
			var col := Color(1, 0.35, 0.3, 0.5 * _flash[i]) if reduce else Color(1, 1, 1, 0.7 * _flash[i])
			_draw_heart_overlay(r, col)


func _draw_heart_overlay(r: Rect2, col: Color) -> void:
	var s := minf(r.size.x, r.size.y) / 100.0
	draw_set_transform(r.position, 0.0, Vector2(s, s))
	draw_colored_polygon(UIIcons.heart_pts(), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _reduce_flashing() -> bool:
	var st := get_node_or_null(^"/root/Settings")
	return st != null and bool(st.get(&"reduce_flashing"))
