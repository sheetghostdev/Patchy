extends Node
## Runs props/tools/build_<name>.gd scene builders after autoloads exist.
##   godot --headless --path . res://props/tools/run_prop_builder.tscn -- prop_gallery


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var path := "res://props/tools/build_%s.gd" % arg
		if not ResourceLoader.exists(path):
			push_error("No builder at %s" % path)
			continue
		var builder: Object = load(path).new()
		builder.call(&"build")
	get_tree().quit()
