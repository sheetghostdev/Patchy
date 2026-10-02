class_name UIMovementHud
extends PanelContainer
## F3 movement readout (top-right): speeds, state, timers, camera info and a
## speed sparkline for tuning feel. Toggled by Settings.show_movement_hud.

const ROWS := [
	"fps", "speed", "h_speed", "v_speed", "grounded", "floor_angle", "state", "anim",
	"jump_kind", "coyote", "jump_buffer", "wall_kicks", "air_time", "camera", "attachment",
	"time_scale",
]
const LABELS := {
	"fps": "FPS", "speed": "Speed", "h_speed": "Horizontal", "v_speed": "Vertical",
	"grounded": "Grounded", "floor_angle": "Floor angle", "state": "State", "anim": "Anim",
	"jump_kind": "Jump kind", "coyote": "Coyote", "jump_buffer": "Jump buffer age",
	"wall_kicks": "Wall-kick chain", "air_time": "Air time", "camera": "Camera",
	"attachment": "Attachment", "time_scale": "Time scale",
}

var _values: Dictionary = {}
var _graph: Control
var _history: PackedFloat32Array = PackedFloat32Array()
var _hist_max := 12.0


func _ready() -> void:
	theme_type_variation = &"DebugPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 6)
	add_child(col)
	var title := Label.new()
	title.text = "MOVEMENT  (F3)"
	title.theme_type_variation = &"DebugValue"
	title.add_theme_color_override(&"font_color", UIPalette.BRASS_LIGHT)
	col.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 1)
	col.add_child(grid)
	for key: String in ROWS:
		var k := Label.new()
		k.text = LABELS[key]
		k.theme_type_variation = &"DebugLabel"
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(k)
		var v := Label.new()
		v.theme_type_variation = &"DebugValue"
		v.custom_minimum_size = Vector2(190, 0)
		v.text = "-"
		grid.add_child(v)
		_values[key] = v
	_graph = Control.new()
	_graph.custom_minimum_size = Vector2(0, 64)
	_graph.draw.connect(_draw_graph)
	col.add_child(_graph)
	_history.resize(180)
	_history.fill(0.0)


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_put(&"fps", "%d" % Engine.get_frames_per_second())
	_put(&"time_scale", "%.2f" % Engine.time_scale)
	_put(&"attachment", String(InventoryManager.equipped_attachment))
	var p := GameManager.player
	if p == null or not is_instance_valid(p):
		for k: String in ["speed", "h_speed", "v_speed", "grounded", "floor_angle", "state", "anim", "jump_kind", "coyote", "jump_buffer", "wall_kicks", "air_time", "camera"]:
			_put(StringName(k), "-")
		return
	var vel: Vector3 = p.get(&"velocity")
	var hv := Vector3(vel.x, 0.0, vel.z)
	_put(&"speed", "%6.2f m/s" % vel.length())
	_put(&"h_speed", "%6.2f m/s" % hv.length())
	_put(&"v_speed", "%+6.2f m/s" % vel.y)
	var grounded: bool = p.call(&"is_on_floor") if p.has_method(&"is_on_floor") else false
	_put(&"grounded", "YES" if grounded else "no", UIPalette.GREEN_LIGHT if grounded else Color("ffb38a"))
	_put(&"floor_angle", "%5.1f°" % rad_to_deg(float(p.get(&"floor_angle"))))
	_put(&"state", str(p.get(&"state_id")))
	_put(&"anim", str(p.get(&"anim_state")))
	_put(&"jump_kind", str(p.get(&"jump_kind")) if str(p.get(&"jump_kind")) != "" else "-")
	_put(&"coyote", "%.3f s" % float(p.get(&"coyote_timer")))
	var input: Object = p.get(&"input")
	if input != null and input.has_method(&"get_press_age"):
		var age: float = input.call(&"get_press_age", &"jump")
		_put(&"jump_buffer", "%.3f s" % age if age < 99.0 else "-")
	_put(&"wall_kicks", str(p.get(&"wall_kick_chain")))
	_put(&"air_time", "%.2f s" % float(p.get(&"air_time")))
	var rig: Object = p.get(&"camera_rig")
	if rig != null and is_instance_valid(rig):
		var dist: Variant = rig.get(&"_arm_length")
		var fov: Variant = rig.get(&"_fov")
		var mode := "recenter" if float(rig.get(&"_recenter_t") if rig.get(&"_recenter_t") != null else -1.0) >= 0.0 else ("auto" if Settings.auto_camera else "manual")
		var zone: Variant = rig.get(&"_zone_weight")
		if zone != null and float(zone) > 0.01:
			mode += " +zone"
		_put(&"camera", "%.1fm  %d°  %s" % [float(dist if dist != null else 0.0), int(float(fov if fov != null else 0.0)), mode])
	else:
		_put(&"camera", "-")
	_history.remove_at(0)
	_history.append(hv.length())
	_graph.queue_redraw()


func _put(key: StringName, text: String, color: Color = Color("eef4ff")) -> void:
	var l: Label = _values[String(key)]
	l.text = text
	l.add_theme_color_override(&"font_color", color)


func _draw_graph() -> void:
	var r := Rect2(Vector2.ZERO, _graph.size)
	_graph.draw_rect(r, Color(0, 0, 0, 0.25))
	var top := 0.0
	for v in _history:
		top = maxf(top, v)
	_hist_max = maxf(lerpf(_hist_max, top * 1.1, 0.05), 8.0)
	var pts := PackedVector2Array()
	for i in _history.size():
		var x := r.size.x * float(i) / float(_history.size() - 1)
		var y := r.size.y - clampf(_history[i] / _hist_max, 0.0, 1.0) * (r.size.y - 4.0) - 2.0
		pts.append(Vector2(x, y))
	_graph.draw_polyline(pts, Color(0.3, 0.9, 1.0), 2.0, true)
	var f := UIStyle.font(&"mono")
	_graph.draw_string(f, Vector2(4, 16), "h-speed  max %.0f" % _hist_max, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.8, 0.95, 0.8))
