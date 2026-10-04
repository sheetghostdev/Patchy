@tool
class_name NetRack
extends PropBody
## A fishing net hung out to dry on a pole frame, with cork floats along
## its top and a couple of glass floats in rope cradles. Origin: the
## ground at the middle; the net hangs across X. The top bar is
## hook-swing height and solid. Footsteps report &"wood".

@export_range(1.5, 6.0, 0.05) var width := 3.2:
	set(v):
		width = v
		_queue_rebuild()
@export_range(1.5, 4.0, 0.05) var height := 2.4:
	set(v):
		height = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var parts := PropParts.new()
	parts.foliage_profile = &"cloth"
	var rng := PropKit.make_rng(seed, 601)
	var hw := width * 0.5
	for sx: float in [-1.0, 1.0]:
		parts.matte.cylinder(0.07, 0.08, height + 0.2, Transform3D(Basis(Vector3.BACK, sx * 0.06), Vector3(sx * hw, (height + 0.2) * 0.5, 0)), PropPalette.DRIFTWOOD_DARK, 8)
	parts.matte.cylinder(0.05, 0.05, width + 0.3, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0, height, 0)), PropPalette.DRIFTWOOD, 8)
	# The net: a sagging mesh of cords.
	var cols := int(width / 0.18)
	var rows := int(height * 0.8 / 0.18)
	var net := PropPalette.ROPE_DARK.darkened(0.15)
	var pts := []
	for r in rows + 1:
		var row := []
		for c in cols + 1:
			var u := float(c) / cols
			var v := float(r) / rows
			var drop := v * height * 0.8 + 0.25 * sin(u * PI) * v
			row.append(Vector3(-hw + 0.05 + u * (width - 0.1), height - drop, 0.03 * sin(u * 9.0 + v * 4.0)))
		pts.append(row)
	for r in rows + 1:
		var line := PackedVector3Array()
		for c in cols + 1:
			line.append(pts[r][c])
		parts.matte.tube(line, PackedFloat32Array([0.012]), net, 3, false)
	for c in range(0, cols + 1, 1):
		var line := PackedVector3Array()
		for r in rows + 1:
			line.append(pts[r][c])
		parts.matte.tube(line, PackedFloat32Array([0.012]), net, 3, false)
	for c in range(1, cols, 3):
		parts.matte.chamfer_box(Vector3(0.12, 0.08, 0.08), 0.02, Transform3D(Basis.IDENTITY, pts[0][c] + Vector3.DOWN * 0.04), Color("d9a45e"))
	for k in 2:
		var p: Vector3 = pts[rows][int(cols * (0.3 + k * 0.4))] + Vector3.DOWN * 0.15
		var glass: Color = [Color("6fc7c0"), Color("7fa6e6")][k]
		parts.glossy.sphere(0.15, Transform3D(Basis.IDENTITY, p), glass, 6, 10)
		parts.matte.torus(0.13, 0.155, Transform3D(Basis(Vector3.RIGHT, rng.randf_range(0.0, 1.0)), p), Palette.ROPE, 10, 3)
	add_mesh(parts.build(), "NetRack")
	add_shape(PropKit.box_shape(Vector3(width + 0.3, 0.12, 0.12)), Transform3D(Basis.IDENTITY, Vector3(0, height, 0)), "Bar")
	for sx: float in [-1.0, 1.0]:
		add_shape(PropKit.cylinder_shape(0.09, height), Transform3D(Basis.IDENTITY, Vector3(sx * hw, height * 0.5, 0)), "Pole")
