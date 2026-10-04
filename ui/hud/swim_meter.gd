class_name UISwimMeter
extends Control
## Patchy's breath out at sea (SwimStamina): a ring beside him that empties
## as he swims the open sea, turning from sea-green to amber to red, with a
## bubble in the middle. It fades in once it's below full and out when
## it's full again. Draws nothing without a player.

const RADIUS := 26.0
const WIDTH := 7.0
const FULL := Color("5fd3b4")
const LOW := Color("ffb347")
const EMPTY := Color("ff5a4f")

var _alpha := 0.0
var _pulse := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	var s := _stamina()
	var want := 1.0 if s != null and (s.value < 0.999 or s.draining) else 0.0
	_alpha = move_toward(_alpha, want, delta * (4.0 if want > 0.0 else 1.6))
	_pulse += delta
	queue_redraw()


func _stamina() -> SwimStamina:
	var p := GameManager.player as Player
	if p == null or not is_instance_valid(p):
		return null
	return p.stamina


func _draw() -> void:
	var s := _stamina()
	if s == null or _alpha <= 0.01:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var head := (GameManager.player as Node3D).global_position + Vector3.UP * 1.9
	if cam.is_position_behind(head):
		return
	var at := cam.unproject_position(head) + Vector2(56, -40)
	var v := clampf(s.value, 0.0, 1.0)
	var col := LOW.lerp(FULL, clampf((v - 0.35) / 0.4, 0.0, 1.0)) if v > 0.35 else EMPTY.lerp(LOW, v / 0.35)
	if v < 0.3:
		col = col.lerp(Color.WHITE, 0.25 * (0.5 + 0.5 * sin(_pulse * 14.0)))
	var a := _alpha
	draw_circle(at, RADIUS + WIDTH * 0.5 + 3.0, Color(0.06, 0.1, 0.16, 0.45 * a))
	draw_arc(at, RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.18 * a), WIDTH, true)
	if v > 0.001:
		draw_arc(at, RADIUS, -PI * 0.5, -PI * 0.5 + TAU * v, 48, Color(col, a), WIDTH, true)
	# A bubble in the middle, wobbling a little.
	var wob := Vector2(sin(_pulse * 3.0), cos(_pulse * 2.3)) * 1.2
	draw_circle(at + wob, 8.5, Color(0.85, 0.97, 1.0, 0.85 * a))
	draw_circle(at + wob + Vector2(-2.8, -2.8), 2.6, Color(1, 1, 1, 0.95 * a))
	draw_arc(at + wob, 8.5, 0.0, TAU, 20, Color(0.2, 0.45, 0.6, 0.8 * a), 1.6, true)
