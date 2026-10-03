class_name SpyglassView
extends Node
## The Spyglass's eyepiece (docs/ARCHIPELAGO.md, from Hat Rock's lookout): a
## camera at Patchy's eye zoomed far out to sea, aimed with the usual camera
## controls slowed right down, inside a round brass vignette. The island in
## the middle of the view is named; hold it there a moment the first time
## and it is pencilled onto the sea chart (GameManager.sight_island).

const ZOOM_FOV := 13.0
const OPEN_TIME := 0.3
## How close to the middle of the view an island must sit (degrees).
const SIGHT_CONE := 3.5
## How long to hold an island in view before it goes on the chart.
const SIGHT_TIME := 0.5

var player: Player
var rig: CameraRig
var cam: Camera3D
## The island in the middle of the view (or &"").
var sighting: StringName = &""
var _eyepiece: UISpyglassEyepiece
var _layer: CanvasLayer
var _prev_pitch := 0.0
var _held := 0.0


func open(p: Player) -> void:
	player = p
	rig = p.camera_rig as CameraRig
	_prev_pitch = rig.pitch
	rig.yaw = Player.yaw_of(p.facing)
	rig.pitch = -0.02
	rig.look_scale = ZOOM_FOV / 58.0
	rig.scoping = true
	cam = Camera3D.new()
	cam.far = 4000.0
	cam.fov = rig.get_camera().fov
	add_child(cam)
	_place_camera()
	cam.make_current()
	create_tween().tween_property(cam, "fov", ZOOM_FOV, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_layer = CanvasLayer.new()
	_layer.layer = 60
	add_child(_layer)
	_eyepiece = UISpyglassEyepiece.new()
	_eyepiece.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_eyepiece)
	AudioManager.play(&"switch_click", p.global_position, -4.0, 1.5)


func close() -> void:
	if rig != null and is_instance_valid(rig):
		rig.look_scale = 1.0
		rig.scoping = false
		rig.pitch = _prev_pitch
		rig.get_camera().make_current()
	queue_free()


func _process(delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	_place_camera()
	_update_sighting(delta)


func _place_camera() -> void:
	var eye := player.global_position + Vector3.UP * 1.35 + Player.dir_from_yaw(rig.yaw) * 0.45
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(rig.pitch, rig.yaw, 0.0)), eye)


## The island nearest the middle of the view, if any is close enough.
func island_in_view() -> StringName:
	var info := get_tree().get_first_node_in_group(&"island_info") as IslandInfo
	var fwd := -cam.global_basis.z
	var best: StringName = &""
	var best_angle := SIGHT_CONE
	for id in Archipelago.ids():
		if info != null and info.covers(id):
			continue
		var at := Archipelago.world_position(id) + Vector3.UP * 20.0
		var angle := rad_to_deg(fwd.angle_to((at - cam.global_position).normalized()))
		if angle < best_angle:
			best_angle = angle
			best = id
	return best


func _update_sighting(delta: float) -> void:
	var id := island_in_view()
	if id != sighting:
		sighting = id
		_held = 0.0
	if id == &"":
		_eyepiece.show_island("", "")
		return
	_held += delta
	if _held >= SIGHT_TIME and GameManager.sight_island(id):
		AudioManager.play(&"ui_map", player.global_position, -2.0, 1.15)
		_eyepiece.flash("Pencilled onto your sea chart!")
	var note := "Charted" if GameManager.is_island_discovered(id) else ("Sighted" if GameManager.is_island_sighted(id) else "Uncharted...")
	_eyepiece.show_island(UIChartData.display_name(id), note)
