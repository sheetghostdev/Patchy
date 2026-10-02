extends Node
## Loads every script, shader and scene under res://props so parse/compile
## errors surface (the --import step only refreshes the class cache). Runs as
## a scene so autoload singletons (WorldState, AudioManager) resolve.
##   godot --headless --path . res://props/tests/compile_check.tscn


func _ready() -> void:
	var failed := 0
	var checked := 0
	var self_path: String = (get_script() as Script).resource_path
	for path in _collect("res://props"):
		if path == self_path:
			continue
		checked += 1
		var res := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
		var ok := res != null
		if res is GDScript:
			# reload() reports dependency compile failures that load() hides.
			var err := (res as GDScript).reload(true)
			ok = (err == OK or err == ERR_ALREADY_IN_USE) and (res as GDScript).can_instantiate()
		if not ok:
			failed += 1
			printerr("FAILED: ", path)
	print("compile_check: %d files, %d failed" % [checked, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _collect(dir_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdshader") or f.ends_with(".tscn"):
			out.append(dir_path.path_join(f))
	for d in dir.get_directories():
		out.append_array(_collect(dir_path.path_join(d)))
	return out
