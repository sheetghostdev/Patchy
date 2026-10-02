extends Node
## Verifies that Ocean's CPU wave functions match the shader.
##
## Always (works with --headless):
##   1. Ocean.get_wave_offset (float32 constants, the shader's formula) vs an
##      independent double-precision Gerstner reference built straight from
##      the exported wave parameters.
##   2. get_wave_height(p + offset.xz) == sea_level + offset.y (Newton undo of
##      the horizontal motion), and get_surface_normal vs finite differences.
## With a GPU (xvfb + Vulkan):
##   3. The real ocean_offset() from ocean_waves.gdshaderinc is evaluated on
##      the GPU (ocean_wave_probe.gdshader), its float bits read back, and
##      compared with get_wave_offset at the very same points.
##
##   godot --headless --path . res://world/ocean/tests/ocean_wave_check.tscn
##   xvfb-run -a godot --path . --rendering-driver vulkan res://world/ocean/tests/ocean_wave_check.tscn

const PROBE_SHADER := preload("res://world/ocean/tests/ocean_wave_probe.gdshader")
const TIMES: Array[float] = [0.0, 0.37, 17.25, 1234.567, 86400.25]
const COLS := 64
const ROWS := 20
const ORIGIN := Vector2(-180.3, -140.7)
const SPACING := Vector2(5.71, 13.9)
const LOD_CENTER := Vector2(37.3, -12.9)
const GPU_TOLERANCE := 1.0e-3

var _ocean: Ocean
var _failed := false


func _ready() -> void:
	_ocean = Ocean.new()
	_ocean.set_lod_center(LOD_CENTER)
	_check_reference()
	_check_inversion()
	_report_mesh()
	if DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null:
		print("[ocean check] GPU comparison skipped (no rendering device; run under xvfb with Vulkan)")
	else:
		await _check_gpu()
	print("[ocean check] %s" % ("FAIL" if _failed else "PASS"))
	_ocean.free()
	get_tree().quit(1 if _failed else 0)


func _points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for j in ROWS:
		for i in COLS:
			pts.append(ORIGIN + Vector2(i, j) * SPACING)
	return pts


func _reference_offset(p: Vector2, t: float) -> Vector3:
	var o := _ocean
	var half_cells := maxi(o.core_cells / 2, 8)
	var core_extent := half_cells * o.cell_size
	var out := Vector3.ZERO
	for wv: Vector4 in [o.wave_a, o.wave_b, o.wave_c, o.wave_d]:
		var dir := Vector2(cos(deg_to_rad(wv.x)), sin(deg_to_rad(wv.x)))
		var k := TAU / wv.y
		var amp := wv.z * o.amplitude_scale
		var horiz := clampf(wv.w, 0.0, 0.95) / k * minf(o.amplitude_scale, 1.0)
		var omega := sqrt(Ocean.GRAVITY * k) * o.wave_speed
		var far := maxf(wv.y * half_cells / 12.0, core_extent)
		var x := clampf((p.distance_to(LOD_CENTER) - far * 0.6) / (far * 0.4), 0.0, 1.0)
		var w := 1.0 - x * x * (3.0 - 2.0 * x)
		var th := k * dir.dot(p) - omega * t
		out += Vector3(dir.x * horiz * cos(th), amp * sin(th), dir.y * horiz * cos(th)) * w
	return out


func _check_reference() -> void:
	var worst := 0.0
	var n := 0
	for t in TIMES:
		for p in _points():
			var d := (_ocean.get_wave_offset(p, t) - _reference_offset(p, t)).abs()
			worst = maxf(worst, maxf(d.x, maxf(d.y, d.z)))
			n += 1
	print("[ocean check] CPU get_wave_offset vs double-precision reference: max |diff| = %s m (%d samples, %d times)" % [_sci(worst), n, TIMES.size()])
	if worst > 1.0e-4:
		_failed = true


func _check_inversion() -> void:
	var worst_h := 0.0
	var worst_n := 0.0
	for t in TIMES:
		for p in _points():
			var o := _ocean.get_wave_offset(p, t)
			var world := p + Vector2(o.x, o.z)
			var h := _ocean.get_wave_height(world, t)
			worst_h = maxf(worst_h, absf(h - (_ocean.sea_level + o.y)))
			# Normal vs central differences of the height field.
			var e := 0.01
			var hx := (_ocean.get_wave_height(world + Vector2(e, 0.0), t) - _ocean.get_wave_height(world - Vector2(e, 0.0), t)) / (2.0 * e)
			var hz := (_ocean.get_wave_height(world + Vector2(0.0, e), t) - _ocean.get_wave_height(world - Vector2(0.0, e), t)) / (2.0 * e)
			var fd := Vector3(-hx, 1.0, -hz).normalized()
			worst_n = maxf(worst_n, fd.angle_to(_ocean.get_surface_normal(world, t)))
	print("[ocean check] get_wave_height at displaced points vs sea_level + offset.y: max |err| = %s m" % _sci(worst_h))
	print("[ocean check] get_surface_normal vs finite differences: max angle = %s rad" % _sci(worst_n))
	if worst_h > 1.0e-4 or worst_n > 1.0e-2:
		_failed = true


func _report_mesh() -> void:
	var t0 := Time.get_ticks_usec()
	var mesh := Ocean.build_surface_mesh(_ocean.cell_size, _ocean.core_cells, _ocean.extent)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	print("[ocean check] surface mesh: %d vertices, %d triangles, built in %.0f ms" % [verts.size(), idx.size() / 3, ms])
	if verts.size() > 150000:
		_failed = true
	# Watertight LOD stitching: an edge used by a single triangle may only lie
	# on the outer border (a T-junction or crack would leave inner open edges),
	# and every triangle must face up (Godot front faces wind clockwise).
	var outer := 0.0
	for v in verts:
		outer = maxf(outer, maxf(absf(v.x), absf(v.z)))
	var edges := {}
	var flipped := 0
	var n := verts.size()
	for t in range(0, idx.size(), 3):
		var a := idx[t]
		var b := idx[t + 1]
		var c := idx[t + 2]
		var e1 := verts[b] - verts[a]
		var e2 := verts[c] - verts[a]
		if e1.z * e2.x - e1.x * e2.z >= 0.0:
			flipped += 1
		for pair: Array in [[a, b], [b, c], [c, a]]:
			var key: int = mini(pair[0], pair[1]) * n + maxi(pair[0], pair[1])
			edges[key] = int(edges.get(key, 0)) + 1
	var inner_open := 0
	var over_shared := 0
	for key: int in edges:
		var count: int = edges[key]
		if count > 2:
			over_shared += 1
		elif count == 1:
			var pa := verts[key / n]
			var pb := verts[key % n]
			var on_border := func(p: Vector3) -> bool: return is_equal_approx(absf(p.x), outer) or is_equal_approx(absf(p.z), outer)
			if not (on_border.call(pa) and on_border.call(pb)):
				inner_open += 1
	print("[ocean check] mesh topology: %d open edges inside the border, %d over-shared edges, %d triangles not facing up" % [inner_open, over_shared, flipped])
	if inner_open > 0 or over_shared > 0 or flipped > 0:
		_failed = true


func _check_gpu() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(COLS * 5, ROWS)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := ColorRect.new()
	rect.size = Vector2(vp.size)
	var mat := ShaderMaterial.new()
	mat.shader = PROBE_SHADER
	mat.set_shader_parameter(&"origin", ORIGIN)
	mat.set_shader_parameter(&"spacing", SPACING)
	rect.material = mat
	vp.add_child(rect)
	add_child(vp)
	var worst := 0.0
	var worst_ref := 0.0
	var worst_h := 0.0
	var count := 0
	for t in TIMES:
		_ocean.time = t
		var uniforms := _ocean.get_wave_uniforms()
		for key: StringName in uniforms:
			mat.set_shader_parameter(key, uniforms[key])
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
		var data := img.get_data()
		var w := img.get_width()
		for j in ROWS:
			for i in COLS:
				var base := (j * w + i * 5) * 4
				var gpu := Vector3(data.decode_float(base), data.decode_float(base + 4), data.decode_float(base + 8))
				var p := Vector2(data.decode_float(base + 12), data.decode_float(base + 16))
				var cpu := _ocean.get_wave_offset(p, t)
				if j == 9 and i == 37 and t == TIMES[3]:
					print("[ocean check] sample t=%.3f p=%s  gpu=%s  cpu=%s" % [t, p, gpu, cpu])
				var d := (gpu - cpu).abs()
				worst = maxf(worst, maxf(d.x, maxf(d.y, d.z)))
				var r := (gpu - _reference_offset(p, t)).abs()
				worst_ref = maxf(worst_ref, maxf(r.x, maxf(r.y, r.z)))
				# What a floating object asks for: the height at the displaced spot.
				var h := _ocean.get_wave_height(p + Vector2(gpu.x, gpu.z), t)
				worst_h = maxf(worst_h, absf(h - (_ocean.sea_level + gpu.y)))
				count += 1
	vp.queue_free()
	print("[ocean check] GPU ocean_offset() vs CPU get_wave_offset: max |diff| = %s m (%d points x %d times)" % [_sci(worst), COLS * ROWS, TIMES.size()])
	print("[ocean check] GPU ocean_offset() vs double reference: max |diff| = %s m" % _sci(worst_ref))
	print("[ocean check] CPU get_wave_height vs GPU surface height at the displaced vertex: max |diff| = %s m" % _sci(worst_h))
	if worst > GPU_TOLERANCE or worst_h > GPU_TOLERANCE or count == 0:
		_failed = true


static func _sci(v: float) -> String:
	if v == 0.0:
		return "0"
	var e := floori(log(absf(v)) / log(10.0))
	return "%.2fe%d" % [v / pow(10.0, e), e]
