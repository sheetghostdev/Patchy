@tool
class_name TurtleModel
extends Node3D
## Old Shellby: a stout sea-turtle fisherman with a domed shell, floppy
## straw hat, round spectacles and a bent fishing rod. Original design.

var head: Node3D


func _ready() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	var root := Node3D.new()
	root.set_meta(&"generated", true)
	add_child(root, false, Node.INTERNAL_MODE_FRONT)
	var skin := Color("8fc46a")
	var shell := Color("7a5a3a")
	var shell_light := Color("b08655")
	var mb := MeshBuilder.new()
	# Body + belly plate + domed shell with plates.
	mb.ellipsoid(Vector3(0.42, 0.5, 0.36), Transform3D(Basis.IDENTITY, Vector3(0, 0.75, 0)), skin, 10, 14)
	mb.ellipsoid(Vector3(0.34, 0.42, 0.12), Transform3D(Basis.IDENTITY, Vector3(0, 0.72, -0.27)), Color("e9d9a2"), 8, 12)
	mb.ellipsoid(Vector3(0.52, 0.58, 0.36), Transform3D(Basis.IDENTITY, Vector3(0, 0.82, 0.22)), shell, 10, 16)
	for k in 6:
		var a := -1.0 + k * 0.4
		mb.ellipsoid(Vector3(0.14, 0.14, 0.05), Transform3D(Basis.from_euler(Vector3(0, a * 0.6, 0)), Vector3(sin(a) * 0.3, 0.7 + (k % 2) * 0.28, 0.5 + cos(a) * 0.02)), shell_light, 4, 8)
	# Stubby legs and flipper-arms.
	for side: float in [-1.0, 1.0]:
		mb.ellipsoid(Vector3(0.14, 0.2, 0.16), Transform3D(Basis.IDENTITY, Vector3(side * 0.2, 0.18, 0.0)), skin.darkened(0.08), 6, 10)
		mb.ellipsoid(Vector3(0.1, 0.26, 0.1), Transform3D(Basis.from_euler(Vector3(0.4, 0, side * 0.5)), Vector3(side * 0.42, 0.78, -0.12)), skin, 6, 10)
	# Fishing rod held in the right flipper.
	mb.cylinder(0.02, 0.03, 1.8, Transform3D(Basis.from_euler(Vector3(-0.9, 0, 0)), Vector3(0.48, 1.25, -0.6)), Palette.WOOD, 6)
	var body_mi := MeshInstance3D.new()
	body_mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	root.add_child(body_mi)
	head = Node3D.new()
	head.position = Vector3(0, 1.28, -0.12)
	root.add_child(head)
	var hb := MeshBuilder.new()
	hb.ellipsoid(Vector3(0.26, 0.24, 0.27), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.05)), skin, 10, 14)
	for side: float in [-1.0, 1.0]:
		hb.sphere(0.07, Transform3D(Basis.IDENTITY, Vector3(side * 0.1, 0.1, -0.27)), Color.WHITE, 6, 8)
		hb.sphere(0.035, Transform3D(Basis.IDENTITY, Vector3(side * 0.1, 0.1, -0.33)), Palette.PUPIL, 4, 6)
		hb.torus(0.07, 0.09, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(side * 0.1, 0.1, -0.33)), Palette.BRASS, 12, 4)
	hb.box(Vector3(0.12, 0.025, 0.02), Transform3D(Basis.IDENTITY, Vector3(0, -0.06, -0.31)), skin.darkened(0.4))
	# Floppy straw hat.
	hb.cylinder(0.42, 0.44, 0.04, Transform3D(Basis.from_euler(Vector3(0.12, 0, 0)), Vector3(0, 0.24, 0)), Color("e8c66e"), 18)
	hb.ellipsoid(Vector3(0.22, 0.15, 0.22), Transform3D(Basis.IDENTITY, Vector3(0, 0.33, 0.02)), Color("e8c66e"), 8, 12)
	hb.cylinder(0.225, 0.225, 0.05, Transform3D(Basis.IDENTITY, Vector3(0, 0.27, 0.02)), Palette.COAT.lightened(0.1), 14)
	var head_mi := MeshInstance3D.new()
	head_mi.mesh = hb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	head.add_child(head_mi)


func _process(_delta: float) -> void:
	if head != null and not Engine.is_editor_hint():
		head.rotation.x = sin(Time.get_ticks_msec() * 0.0015) * 0.08
