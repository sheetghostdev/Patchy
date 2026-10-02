extends Node
## Rough CPU cost of a level (game logic + physics, no rendering):
##   godot --headless --path . --fixed-fps 60 res://tools/perf_probe.tscn -- [scene=res://...] [frames=600]

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var path: String = args.get("scene", "res://world/islands/castaway_cay/castaway_cay.tscn")
	var count := int(args.get("frames", "600"))
	WorldState.mark_completed(&"castaway_intro_seen")
	var t0 := Time.get_ticks_usec()
	var scene: Node = load(path).instantiate()
	add_child(scene)
	var t1 := Time.get_ticks_usec()
	print("load + ready: %.1f ms" % ((t1 - t0) / 1000.0))
	for i in 30:
		await get_tree().physics_frame
	var t2 := Time.get_ticks_usec()
	for i in count:
		await get_tree().physics_frame
	var t3 := Time.get_ticks_usec()
	print("avg frame: %.2f ms over %d frames, %d nodes" % [(t3 - t2) / 1000.0 / count, count, get_tree().get_node_count()])
	get_tree().quit()
