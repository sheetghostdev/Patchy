extends Node
## Renders scenes to PNG for visual review (art direction, camera framing).
## Run under a display (xvfb-run on servers):
##   godot --path . res://tools/photo/photo.tscn -- scene=res://tests/scenes/movement_test.tscn \
##       out=/tmp/shot.png frames=40 [size=1280x720] [player=x,y,z] [yaw=deg] \
##       [cam=x,y,z look=x,y,z] [move=x,y] [press=jump@10-20,dive@30]
##       [snaps=f1,f2,...] [follow=dx,dy,dz (camera offset that tracks Patchy)]
##       [flags=castaway_intro_seen,... (WorldState completions set before loading)]
##       [progress=demo (mid-game inventory)] [hud=0 (hide the HUD)] [weather=rain]
## Multiple free-camera shots: cams="x,y,z>lx,ly,lz;x,y,z>lx,ly,lz" with out=/tmp/shot_%d.png

var _args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	var size := Vector2i(1280, 720)
	if _args.has("size"):
		var p: PackedStringArray = String(_args.size).split("x")
		size = Vector2i(int(p[0]), int(p[1]))
	get_window().size = size
	Settings.auto_camera = _args.get("autocam", "1") == "1"
	for f in String(_args.get("flags", "")).split(",", false):
		WorldState.mark_completed(StringName(f))
	if _args.get("progress", "") == "demo":
		_demo_progress()
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and _args.get("hud", "1") == "0":
		ui.call(&"set_hud_hidden", true)
	var scene_path: String = _args.get("scene", "res://tests/scenes/movement_test.tscn")
	var scene: Node = load(scene_path).instantiate()
	add_child(scene)
	await get_tree().process_frame
	if _args.get("weather", "") == "rain":
		await get_tree().process_frame
		for w in scene.find_children("*", "Weather", true, false):
			w.call(&"start_shower", true)
	var player := GameManager.player as Player
	if player != null and _args.has("player"):
		var pos := _vec3(_args.player)
		var yaw := deg_to_rad(float(_args.get("yaw", "0")))
		player.teleport(pos, Player.dir_from_yaw(yaw))
	if player != null and (_args.has("move") or _args.has("press")):
		player.input.virtual_mode = true
	var total := int(_args.get("frames", "40"))
	var press_plan := _parse_presses(String(_args.get("press", "")))
	var move_v := _vec2(String(_args.get("move", "0,0")))
	var shots: Array = []
	if _args.has("cams"):
		for c in String(_args.cams).split(";"):
			var parts := c.split(">")
			shots.append([_vec3(parts[0]), _vec3(parts[1])])
	elif _args.has("cam"):
		shots.append([_vec3(_args.cam), _vec3(String(_args.get("look", "0,0,0")))])
	var snap_frames: Array[int] = []
	if _args.has("snaps"):
		for f in String(_args.snaps).split(","):
			snap_frames.append(int(f))
	var snap_index := 0
	var follow_cam: Camera3D = null
	if _args.has("follow") and player != null:
		follow_cam = Camera3D.new()
		follow_cam.fov = float(_args.get("fov", "40"))
		add_child(follow_cam)
		follow_cam.make_current()
	for i in total:
		if follow_cam != null:
			var off := _vec3(_args.follow)
			var target := player.get_global_transform_interpolated().origin + Vector3.UP * 0.9
			follow_cam.global_position = target + off
			follow_cam.look_at(target)
		if player != null and player.input.virtual_mode:
			player.input.virtual_move = move_v
			for pr in press_plan:
				if pr[1] == i:
					player.input.virtual_press(pr[0])
				elif pr[2] == i:
					player.input.virtual_release(pr[0])
		await get_tree().process_frame
		if i in snap_frames:
			await RenderingServer.frame_post_draw
			_save(get_viewport().get_texture().get_image(), snap_index)
			snap_index += 1
	if not snap_frames.is_empty():
		get_tree().quit()
		return
	if shots.is_empty():
		await RenderingServer.frame_post_draw
		_save(get_viewport().get_texture().get_image(), 0)
	else:
		var cam := Camera3D.new()
		cam.fov = float(_args.get("fov", "58"))
		cam.far = 3000.0
		add_child(cam)
		for k in shots.size():
			cam.global_position = shots[k][0]
			cam.look_at(shots[k][1])
			cam.make_current()
			for f in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			_save(get_viewport().get_texture().get_image(), k)
	get_tree().quit()


## Mid-game progress for hub / UI shots: gold, treasures, parrots, tools.
func _demo_progress() -> void:
	InventoryManager.collect_treasure(&"", &"coin", 140)
	var picks := [[&"demo_gem_1", &"gem", Palette.GEM_BLUE], [&"demo_gem_2", &"gem", Palette.GEM_RED], [&"demo_gem_3", &"gem", Color("3ddc97")],
			[&"demo_goblet", &"goblet", Palette.GOLD], [&"demo_crown", &"crown", Palette.GOLD], [&"demo_relic", &"relic", Palette.GOLD],
			[&"demo_pearl", &"pearl", Color.WHITE]]
	for p: Array in picks:
		InventoryManager.collect_treasure(p[0], p[1], 5, &"castaway_cay", p[2])
	for id in ["castaway_parrot_wreck", "castaway_parrot_stack", "castaway_parrot_outpost", "castaway_parrot_summit", "driftwood_parrot_tower"]:
		ParrotManager.rescue(StringName(id), &"castaway_cay")
	for id: StringName in [&"grapple", &"shovel", &"lantern", &"cannon"]:
		InventoryManager.unlock_attachment(id)
	InventoryManager.add_ship_part(&"compass")
	InventoryManager.add_ship_part(&"ships_wheel")
	InventoryManager.add_key_item(&"spyglass")


func _save(img: Image, index: int) -> void:
	var out: String = _args.get("out", "/tmp/patchy_shot.png")
	if out.contains("%d"):
		out = out % index
	img.save_png(out)
	print("saved ", out)


func _vec3(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _vec2(s: String) -> Vector2:
	var p := s.split(",")
	return Vector2(float(p[0]), float(p[1]))


## "jump@10-20,dive@30" -> [[action, press_frame, release_frame]]
func _parse_presses(s: String) -> Array:
	var out := []
	if s == "":
		return out
	for item in s.split(","):
		var parts := item.split("@")
		var range_parts := parts[1].split("-")
		var a := int(range_parts[0])
		var b := int(range_parts[1]) if range_parts.size() > 1 else a + 1
		out.append([StringName(parts[0]), a, b])
	return out
