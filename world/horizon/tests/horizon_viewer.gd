extends Node3D
## Dev view of a horizon island over the real ocean and sky, for the photo
## tool. The island sits at the origin with its face toward -Z:
##   tools/photo/shoot.sh scene=res://world/horizon/tests/horizon_viewer.tscn \
##       island=skullcap_mountain "cams=0,30,-380>0,50,0"
## island=: an Archipelago id (skullcap_mountain, turtleback, ...), or
## "archipelago": every island at its place in the world, seen from where
## Castaway Cay stands (the origin).

func _ready() -> void:
	add_child(SkyEnvironment.new())
	add_child(Ocean.new())
	var which := "skullcap_mountain"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("island="):
			which = a.substr(7)
	if which == "archipelago":
		Archipelago.add_horizon(self)
		var c := Camera3D.new()
		c.far = 3000.0
		add_child(c)
		c.position = Vector3(0, 30, 0)
		return
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


## The island's silhouette at the origin, facing -Z (by Archipelago id).
static func make(which: String) -> HorizonIsland:
	var isl := Archipelago.make_horizon(StringName(which))
	if isl != null:
		isl.position = Vector3.ZERO
		isl.rotation = Vector3.ZERO
		isl.scale = Vector3.ONE
	return isl
