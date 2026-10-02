@tool
class_name KingClawModel
extends Node3D
## King Claw (spec §168): an enormous, vain hermit-king of a crab with a
## dented gold crown, a scarred crimson shell, a walrus mustache of
## barnacles, goggly eyes on stalks and two huge pincers. Original design.
## Built from code like every placeholder; pivots for procedural animation.

var body: Node3D
var crown: Node3D
var eye_l: Node3D
var eye_r: Node3D
var claw_l: Node3D
var claw_r: Node3D
var pincer_l: Node3D
var pincer_r: Node3D
var legs: Array[Node3D] = []

const SHELL := Color("d9472b")
const SHELL_DARK := Color("a8321d")
const BELLY := Color("f4d3a1")


func _ready() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	var root := Node3D.new()
	root.set_meta(&"generated", true)
	add_child(root, false, Node.INTERNAL_MODE_FRONT)
	body = Node3D.new()
	body.position = Vector3(0, 1.5, 0)
	root.add_child(body)
	_part(body, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(2.1, 1.25, 1.75), Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0.1)), SHELL, 12, 20)
		mb.ellipsoid(Vector3(1.8, 0.55, 1.5), Transform3D(Basis.IDENTITY, Vector3(0, -0.45, 0.05)), BELLY, 8, 18)
		# Shell spots and a battle scar.
		for k in 7:
			var a := -1.2 + k * 0.4
			mb.ellipsoid(Vector3(0.28, 0.12, 0.22), Transform3D(Basis.from_euler(Vector3(0.3, a, 0)), Vector3(sin(a) * 1.3, 1.0 - absf(a) * 0.15, 0.4 + cos(a) * 0.5)), SHELL_DARK, 4, 8)
		mb.box(Vector3(0.08, 0.04, 0.9), Transform3D(Basis.from_euler(Vector3(0.6, 0.5, 0)), Vector3(-0.6, 1.15, -0.4)), Color("f1e2c6"))
		# Barnacle mustache under the face.
		for k in 9:
			var x := -0.8 + k * 0.2
			mb.sphere(0.12 + 0.03 * sin(k * 1.7), Transform3D(Basis.IDENTITY, Vector3(x, -0.05 - absf(x) * 0.15, -1.62 + absf(x) * 0.12)), Color("efe6d2"), 4, 6)
		mb.box(Vector3(0.9, 0.06, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, -0.35, -1.62)), Color("5a1c14"))
	)
	crown = Node3D.new()
	crown.position = Vector3(0, 1.3, 0.1)
	body.add_child(crown)
	_part(crown, func(mb: MeshBuilder) -> void:
		mb.cylinder(0.62, 0.55, 0.42, Transform3D(Basis.IDENTITY, Vector3(0, 0.21, 0)), Palette.GOLD, 16)
		for k in 6:
			var a := TAU * k / 6.0
			mb.cylinder(0.0, 0.14, 0.38, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.56, 0.6, sin(a) * 0.56)), Palette.GOLD, 6)
			mb.sphere(0.07, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.56, 0.82, sin(a) * 0.56)), Palette.GEM_RED if k % 2 == 0 else Palette.GEM_BLUE, 4, 6)
		mb.sphere(0.12, Transform3D(Basis.IDENTITY, Vector3(0, 0.25, -0.6)), Palette.GEM_RED, 5, 8)
	, &"metal")
	eye_l = _eye(Vector3(-0.55, 0.9, -1.2))
	eye_r = _eye(Vector3(0.55, 0.9, -1.2))
	claw_l = _claw(Vector3(-1.9, 0.0, -0.9), -1.0)
	claw_r = _claw(Vector3(1.9, 0.0, -0.9), 1.0)
	pincer_l = claw_l.get_node("Arm/Pincer")
	pincer_r = claw_r.get_node("Arm/Pincer")
	for i in 6:
		var side := -1.0 if i < 3 else 1.0
		var row := i % 3
		legs.append(_leg(Vector3(side * 1.75, -0.2, -0.3 + row * 0.7), side))


func _part(parent: Node3D, fill: Callable, finish: StringName = &"soft") -> MeshInstance3D:
	var mb := MeshBuilder.new()
	fill.call(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, finish))
	parent.add_child(mi)
	return mi


func _eye(pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	body.add_child(pivot)
	_part(pivot, func(mb: MeshBuilder) -> void:
		mb.cylinder(0.09, 0.12, 0.8, Transform3D(Basis.IDENTITY, Vector3(0, 0.4, 0)), SHELL, 8)
		mb.sphere(0.3, Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0)), Color.WHITE, 8, 12)
		mb.sphere(0.13, Transform3D(Basis.IDENTITY, Vector3(0, 0.92, -0.24)), Palette.PUPIL, 6, 8)
		mb.ellipsoid(Vector3(0.34, 0.1, 0.3), Transform3D(Basis.from_euler(Vector3(0.3, 0, 0)), Vector3(0, 1.14, -0.05)), SHELL_DARK, 5, 10)
	)
	return pivot


func _claw(pos: Vector3, side: float) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = pos
	body.add_child(shoulder)
	var arm := Node3D.new()
	arm.name = "Arm"
	shoulder.add_child(arm)
	_part(arm, func(mb: MeshBuilder) -> void:
		mb.cylinder(0.32, 0.4, 1.3, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 0, -0.6)), SHELL, 10)
		mb.ellipsoid(Vector3(0.95, 0.75, 1.1), Transform3D(Basis.IDENTITY, Vector3(side * 0.1, 0.1, -1.7)), SHELL, 10, 14)
		mb.ellipsoid(Vector3(0.3, 0.2, 0.75), Transform3D(Basis.IDENTITY, Vector3(-side * 0.25, -0.1, -2.6)), SHELL_DARK, 6, 10)
		for k in 4:
			mb.cylinder(0.0, 0.07, 0.18, Transform3D(Basis.from_euler(Vector3(0, 0, PI)), Vector3(-side * 0.25, -0.28, -2.3 - k * 0.2)), Color("f1e2c6"), 5)
	)
	var pincer := Node3D.new()
	pincer.name = "Pincer"
	pincer.position = Vector3(side * 0.3, 0.25, -2.1)
	arm.add_child(pincer)
	_part(pincer, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.3, 0.24, 0.85), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.55)), SHELL, 6, 10)
		for k in 4:
			mb.cylinder(0.0, 0.07, 0.18, Transform3D.IDENTITY.translated(Vector3(0, -0.2, -0.3 - k * 0.2)), Color("f1e2c6"), 5)
	)
	return shoulder


func _leg(pos: Vector3, side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pos
	body.add_child(pivot)
	_part(pivot, func(mb: MeshBuilder) -> void:
		var pts := PackedVector3Array([Vector3.ZERO, Vector3(side * 0.7, 0.35, 0), Vector3(side * 1.25, -0.6, 0), Vector3(side * 1.35, -1.25, 0)])
		mb.tube(pts, PackedFloat32Array([0.2, 0.17, 0.12, 0.05]), SHELL_DARK, 8)
	)
	return pivot
