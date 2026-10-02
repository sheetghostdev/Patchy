extends Node
## Runs a scene-builder script after autoloads exist (builders reference game
## classes that use autoloads, so they can't run as `-s` SceneTree scripts).
##   godot --headless --path . res://tools/builders/run_builder.tscn -- movement_lab


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var path := "res://tools/builders/build_%s.gd" % arg
		if not ResourceLoader.exists(path):
			push_error("No builder at %s" % path)
			continue
		var builder: Object = load(path).new()
		builder.call(&"build")
	get_tree().quit()
