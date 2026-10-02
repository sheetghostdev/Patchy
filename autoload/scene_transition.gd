extends CanvasLayer
## Fades, iris wipes and scene changes that preserve player progression
## (spec §181). Everything is awaitable:
##   await SceneTransition.fade_out()
##   await SceneTransition.change_scene("res://...", &"dock_spawn")

signal scene_changed(path: String)

const IRIS_SHADER := """
shader_type canvas_item;
uniform float radius : hint_range(0.0, 1.5) = 1.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 color : source_color = vec4(0.06, 0.05, 0.12, 1.0);
uniform float aspect = 1.7777;
void fragment() {
	vec2 d = UV - center;
	d.x *= aspect;
	float edge = smoothstep(radius, radius + 0.01, length(d));
	COLOR = vec4(color.rgb, color.a * edge);
}
"""

var _rect: ColorRect
var _mat: ShaderMaterial
var _busy := false
## Spawn point id requested for the next loaded scene; levels read and clear it.
var pending_spawn_id: StringName = &""


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = IRIS_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_rect.material = _mat
	add_child(_rect)
	_set_radius(1.5)


func _set_radius(r: float) -> void:
	_mat.set_shader_parameter("radius", r)
	var size := get_viewport().get_visible_rect().size
	_mat.set_shader_parameter("aspect", size.x / maxf(size.y, 1.0))
	_rect.visible = r < 1.49


func is_busy() -> bool:
	return _busy


## Closes the iris toward `screen_uv` (0..1). Defaults to screen center.
func fade_out(duration: float = 0.35, screen_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	_mat.set_shader_parameter("center", screen_uv)
	var tw := create_tween()
	tw.tween_method(_set_radius, 1.5, 0.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


func fade_in(duration: float = 0.4) -> void:
	var tw := create_tween()
	tw.tween_method(_set_radius, 0.0, 1.5, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished


## Fade out, swap scenes, let the new level position the player, fade in.
func change_scene(path: String, spawn_id: StringName = &"") -> void:
	if _busy:
		return
	_busy = true
	await fade_out()
	pending_spawn_id = spawn_id
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneTransition: failed to load %s (%s)" % [path, error_string(err)])
	else:
		await get_tree().process_frame
		await get_tree().process_frame
		scene_changed.emit(path)
	await fade_in()
	_busy = false
