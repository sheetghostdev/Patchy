class_name UIMapPage
extends UIPage
## Pause-menu page holding the sea chart.

var chart: UISeaChart
## "Sail to ..." buttons for every discovered island in reach (fast travel).
var voyages: HBoxContainer


func _ready() -> void:
	build_frame("Sea Chart", &"compass")
	chart = UISeaChart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(chart)
	voyages = HBoxContainer.new()
	voyages.alignment = BoxContainer.ALIGNMENT_CENTER
	voyages.add_theme_constant_override(&"separation", 14)
	body.add_child(voyages)


func refresh() -> void:
	chart.refresh()
	var island := GameManager.current_island
	set_subtitle("Current waters: %s" % (UIChartData.display_name(island) if island != &"" else "Uncharted"))
	for c in voyages.get_children():
		c.queue_free()
	for id in UIChartData.ids():
		if not GameManager.can_sail_to(id):
			continue
		var b := Button.new()
		b.text = "Sail to %s" % UIChartData.display_name(id)
		b.focus_mode = Control.FOCUS_ALL
		b.pressed.connect(func() -> void:
			var ui := get_node_or_null(^"/root/UI")
			if ui != null:
				ui.call(&"close_pause_menu")
			GameManager.sail_to(id))
		voyages.add_child(b)


func get_first_focus() -> Control:
	return voyages.get_child(0) as Control if voyages.get_child_count() > 0 else null
