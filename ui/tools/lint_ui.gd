extends SceneTree
## Loads every script and scene under res://ui so parse/compile errors show
## up in one pass:
##   godot --headless --path . -s res://ui/tools/lint_ui.gd

var _failed := 0


func _initialize() -> void:
	_scan("res://ui")
	print("lint_ui: %d failure(s)" % _failed)
	quit(1 if _failed > 0 else 0)


func _scan(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		var p := dir_path.path_join(f)
		if f.ends_with(".gd"):
			var s := load(p) as Script
			if s == null or not s.can_instantiate() and not s.is_abstract():
				# Static-only scripts can still be instantiated; null means a load error.
				if s == null:
					_failed += 1
					print("FAILED: ", p)
		elif f.ends_with(".tscn") or f.ends_with(".tres"):
			var r := load(p)
			if r == null:
				_failed += 1
				print("FAILED: ", p)
	for sub in d.get_directories():
		_scan(dir_path.path_join(sub))
