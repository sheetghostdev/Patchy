class_name BrockCameo
extends Node3D
## Brock the Croc's first appearance (spec §100). Once King Claw has fallen
## and the Ship's Wheel is Patchy's, the self-styled Admiral of the
## Archipelago rows his royal barge in under the headland. He sizes up the
## castaway, recites a few of his titles, gloats that the rest of the ship
## is scattered across "his" islands, and is rowed off. That is the
## vertical slice's promise of the bigger adventure. It plays once
## (WorldState `seen_flag`).

signal finished

@export var barge: RoyalBarge
## Where Patchy watches from (the cliff edge) and where the barge waits.
@export var lookout: Marker3D
@export var hold: Marker3D
## Where the barge rows in from and off to.
@export var enter_from: Marker3D
@export var exit_to: Marker3D
@export var seen_flag: StringName = &"brock_cameo_seen"
@export_range(5.0, 120.0, 1.0) var trigger_radius := 45.0
@export var lines: PackedStringArray = PackedStringArray()

var _running := false
var _cam: Camera3D
var _poll := 0.0


func _ready() -> void:
	_hide_barge()
	if WorldState.is_completed(seen_flag):
		set_process(false)


func is_running() -> bool:
	return _running


func _exit_tree() -> void:
	# Interrupted (quit to title mid-scene): it plays again next time.
	if _running:
		_hud_hidden(false)


func _process(delta: float) -> void:
	if _running:
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = 0.5
	if WorldState.is_completed(seen_flag) or not WorldState.is_completed(&"king_claw") \
			or not InventoryManager.has_ship_part(&"ships_wheel"):
		return
	var p := GameManager.player as Player
	if p == null or p.state_id != &"ground" or p.global_position.distance_to(hold.global_position) > trigger_radius:
		return
	_run(p)


func _run(p: Player) -> void:
	_running = true
	var face := Player.flat(hold.global_position - lookout.global_position).normalized()
	p.set_locked(true, {"anim": &"idle", "face": face})
	await SceneTransition.fade_out(0.35)
	_hud_hidden(true)
	p.teleport(lookout.global_position, face)
	p.set_locked(true, {"anim": &"idle", "face": face})
	barge.visible = true
	barge.process_mode = Node.PROCESS_MODE_INHERIT
	barge.global_transform = enter_from.global_transform
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 2000.0
	add_child(_cam)
	_wide_shot(face)
	_cam.make_current()
	await SceneTransition.fade_in(0.5)
	AudioManager.play_stinger(&"stinger_brock", -12.0)
	var row_in := create_tween()
	row_in.tween_property(barge, "global_transform", hold.global_transform, 5.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await row_in.finished
	# Close on the Admiral himself.
	var brock := barge.brock
	var head := brock.global_position + Vector3.UP * 1.9
	var toward := -Player.flat(hold.global_basis.z).normalized()
	_cam.global_position = head + toward * 4.4 + hold.global_basis.x * 1.3 + Vector3.UP * 0.35
	_cam.look_at(head + Vector3.DOWN * 0.15)
	brock.talking = true
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"show_dialogue"):
		var arr: Array[String] = []
		for l in lines:
			arr.append(l)
		await ui.show_dialogue("Brock the Croc", arr, false)
	else:
		await get_tree().create_timer(2.0, false).timeout
	brock.talking = false
	# Wide again as he is rowed off, still waving.
	_wide_shot(face)
	var row_off := create_tween()
	row_off.tween_property(barge, "global_transform", exit_to.global_transform, 7.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(3.0, false).timeout
	await SceneTransition.fade_out(0.4)
	row_off.kill()
	_hide_barge()
	var rig := p.camera_rig as CameraRig
	if rig != null:
		rig.get_camera().make_current()
		rig.snap_behind_target()
	_cam.queue_free()
	_cam = null
	WorldState.mark_completed(seen_flag)
	GameManager.quest_log_refresh()
	if p.state_id == &"locked":
		p.set_locked(false)
	_hud_hidden(false)
	await SceneTransition.fade_in(0.5)
	_running = false
	set_process(false)
	finished.emit()


## Over Patchy's shoulder, out to sea.
func _wide_shot(face: Vector3) -> void:
	var right := face.cross(Vector3.UP).normalized()
	_cam.global_position = lookout.global_position - face * 4.0 + right * 1.2 + Vector3.UP * 2.6
	_cam.look_at(hold.global_position + Vector3.UP * 1.5)


func _hud_hidden(on: bool) -> void:
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"set_hud_hidden"):
		ui.call(&"set_hud_hidden", on)


func _hide_barge() -> void:
	if barge != null:
		barge.visible = false
		barge.process_mode = Node.PROCESS_MODE_DISABLED
