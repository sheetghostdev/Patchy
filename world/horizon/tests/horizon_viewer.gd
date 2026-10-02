extends Node3D
## Dev view of a horizon island over the real ocean and sky, for the photo
## tool. The island sits at the origin with its face toward -Z:
##   tools/photo/shoot.sh scene=res://world/horizon/tests/horizon_viewer.tscn \
##       island=skullcap "cams=0,30,-380>0,50,0"
## island=: skullcap, turtleback, cannon_cliffs, wreck_shoals, crabby_coast,
## lantern_lagoon.

func _ready() -> void:
	add_child(SkyEnvironment.new())
	add_child(Ocean.new())
	var which := "skullcap"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("island="):
			which = a.substr(7)
	var isl := make(which)
	if isl == null:
		push_error("horizon_viewer: unknown island %s" % which)
		return
	add_child(isl)
	var cam := Camera3D.new()
	cam.far = 3000.0
	add_child(cam)
	cam.position = Vector3(0, 30, -380)
	cam.look_at(Vector3(0, 50, 0))


static func make(which: String) -> HorizonIsland:
	match which:
		"skullcap":
			return HorizonSkullcap.new()
		"turtleback":
			return HorizonTurtleback.new()
		"cannon_cliffs":
			return HorizonCannonCliffs.new()
		"wreck_shoals":
			return HorizonWreckShoals.new()
		"crabby_coast":
			return HorizonCrabbyCoast.new()
		"lantern_lagoon":
			return HorizonLanternLagoon.new()
	return null
