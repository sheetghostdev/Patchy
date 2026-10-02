class_name UIMapPage
extends UIPage
## Pause-menu page holding the sea chart.

var chart: UISeaChart


func _ready() -> void:
	build_frame("Sea Chart", &"compass")
	chart = UISeaChart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(chart)


func refresh() -> void:
	chart.refresh()
	var island := GameManager.current_island
	set_subtitle("Current waters: %s" % (UIChartData.display_name(island) if island != &"" else "Uncharted"))
