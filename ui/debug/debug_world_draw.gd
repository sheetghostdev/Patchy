class_name UIDebugWorldDraw
extends Node3D
## World-space debug overlays drawn with an ImmediateMesh (no depth test, so
## they show through geometry):
##  - movement vectors above Patchy: velocity (yellow), horizontal (cyan),
##    vertical (magenta), facing (green), stick input (white)
##  - grapple anchors: every node in group &"hook_point" gets range rings and a
##    billboard label with its distance (green when in range)

var show_vectors := false:
	set(v):
		show_vectors = v
		_update_active()
var show_anchors := false:
	set(v):
		show_anchors = v
		_update_active()
## Hook range used for the rings (matches Patchy's HookSensor radius).
var hook_range := 5.4

var _mesh: MeshInstance3D
var _im: ImmediateMesh
var _labels: Dictionary = {}  # Node -> Label3D


func _ready() -> void:
	top_level = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_im = ImmediateMesh.new()
	_mesh = MeshInstance3D.new()
	_mesh.mesh = _im
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 10
	_mesh.material_override = mat
	add_child(_mesh)
	_update_active()


func _update_active() -> void:
	if not is_inside_tree():
		return
	set_process(show_vectors or show_anchors)
	if not (show_vectors or show_anchors):
		_im.clear_surfaces()
	if not show_anchors:
		_clear_labels()


func _clear_labels() -> void:
	for k: Node in _labels:
		var l: Label3D = _labels[k]
		if is_instance_valid(l):
			l.queue_free()
	_labels.clear()


func _process(_delta: float) -> void:
	_im.clear_surfaces()
	var player := GameManager.player
	if player != null and not is_instance_valid(player):
		player = null
	_im.surface_begin(Mesh.PRIMITIVE_LINES)
	var any := false
	if show_vectors and player != null:
		any = _draw_vectors(player) or any
	if show_anchors:
		any = _draw_anchors(player) or any
	if not any:
		# An empty surface is invalid; add a degenerate line.
		_line(Vector3.ZERO, Vector3.ZERO, Color.TRANSPARENT)
	_im.surface_end()


func _draw_vectors(p: Node3D) -> bool:
	var origin := p.get_global_transform_interpolated().origin + Vector3.UP * 0.12
	var vel: Vector3 = p.get(&"velocity") if p.get(&"velocity") != null else Vector3.ZERO
	var hv := Vector3(vel.x, 0.0, vel.z)
	var k := 0.25
	_arrow(origin, origin + vel * k, Color(1.0, 0.9, 0.2))
	_arrow(origin, origin + hv * k, Color(0.3, 0.9, 1.0))
	var top := origin + Vector3.UP * 1.9
	_arrow(top, top + Vector3.UP * vel.y * k, Color(1.0, 0.35, 0.9))
	var facing: Variant = p.get(&"facing")
	if facing is Vector3:
		_arrow(origin + Vector3.UP * 0.05, origin + Vector3.UP * 0.05 + (facing as Vector3) * 1.2, Color(0.35, 1.0, 0.4))
	var input: Variant = p.get(&"input")
	if input is Object and (input as Object).get(&"move_dir") is Vector3:
		var md: Vector3 = (input as Object).get(&"move_dir")
		_arrow(origin + Vector3.UP * 0.1, origin + Vector3.UP * 0.1 + md * 1.5, Color(1, 1, 1, 0.9))
	_ring(origin - Vector3.UP * 0.1, 0.45, Color(1, 1, 1, 0.35), 20)
	return true


func _draw_anchors(player: Node3D) -> bool:
	var drew := false
	var seen := {}
	var ppos := player.global_position if player != null else Vector3.INF
	for n in get_tree().get_nodes_in_group(&"hook_point"):
		var a := n as Node3D
		if a == null or not a.is_inside_tree():
			continue
		seen[a] = true
		var pos := a.global_position
		var d := ppos.distance_to(pos) if player != null else INF
		var in_range := d <= hook_range
		var col := Color(0.35, 1.0, 0.45, 0.9) if in_range else Color(1.0, 0.65, 0.25, 0.75)
		_ring(pos, hook_range, Color(col, 0.55), 48)
		_ring_v(pos, hook_range, Color(col, 0.25), 48, Vector3.RIGHT)
		_ring_v(pos, hook_range, Color(col, 0.25), 48, Vector3.FORWARD)
		_ring(pos, 0.5, col, 16)
		_line(pos, pos + Vector3.UP * 0.9, col)
		if player != null and in_range:
			_line(player.global_position + Vector3.UP * 1.2, pos, Color(0.35, 1.0, 0.45, 0.6))
		var l: Label3D = _labels.get(a, null)
		if l == null or not is_instance_valid(l):
			l = Label3D.new()
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.fixed_size = true
			l.pixel_size = 0.0012
			l.font_size = 26
			l.outline_size = 8
			l.render_priority = 11
			add_child(l)
			_labels[a] = l
		l.global_position = pos + Vector3.UP * 1.1
		l.modulate = col
		l.text = "%s\n%s" % [a.name, ("%.1f m" % d) if player != null else ""]
		drew = true
	for k: Node in _labels.keys():
		if not seen.has(k):
			var l: Label3D = _labels[k]
			if is_instance_valid(l):
				l.queue_free()
			_labels.erase(k)
	return drew


func _line(a: Vector3, b: Vector3, c: Color) -> void:
	_im.surface_set_color(c)
	_im.surface_add_vertex(a)
	_im.surface_set_color(c)
	_im.surface_add_vertex(b)


func _arrow(a: Vector3, b: Vector3, c: Color) -> void:
	var d := b - a
	if d.length() < 0.02:
		return
	_line(a, b, c)
	var dir := d.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.1:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var head := minf(0.25, d.length() * 0.35)
	_line(b, b - dir * head + side * head * 0.5, c)
	_line(b, b - dir * head - side * head * 0.5, c)


func _ring(center: Vector3, r: float, c: Color, seg: int) -> void:
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		_line(center + Vector3(cos(a0), 0, sin(a0)) * r, center + Vector3(cos(a1), 0, sin(a1)) * r, c)


func _ring_v(center: Vector3, r: float, c: Color, seg: int, axis: Vector3) -> void:
	var u := axis
	for i in seg:
		var a0 := TAU * float(i) / float(seg)
		var a1 := TAU * float(i + 1) / float(seg)
		_line(center + (u * cos(a0) + Vector3.UP * sin(a0)) * r, center + (u * cos(a1) + Vector3.UP * sin(a1)) * r, c)
