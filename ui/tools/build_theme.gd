extends SceneTree
## Bakes UIStyle.build_theme() into res://ui/pirate_theme.tres.
## Run from the project root after changing ui/common/ui_style.gd:
##   godot --headless --path . -s res://ui/tools/build_theme.gd


func _initialize() -> void:
	print("Building pirate theme...")
	var th := UIStyle.build_theme()
	print("Theme built, saving...")
	var err := ResourceSaver.save(th, UIStyle.THEME_PATH)
	print("pirate_theme.tres saved: ", error_string(err))
	quit()
