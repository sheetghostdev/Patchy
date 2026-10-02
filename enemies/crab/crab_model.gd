@tool
class_name CrabModel
extends Node3D
## Procedural crab (spec §88, §187): a round orange shell, googly eye
## stalks, six scuttling legs and one comically oversized claw. Pivots are
## exposed for CrabAnimator-style posing by the Crab script.

enum Variant { NORMAL, ARMORED, HERMIT }

@export var variant := Variant.NORMAL:
	set(v):
		variant = v
		_build()
@export var shell_color := Palette.CRAB:
	set(v):
		shell_color = v
		_build()

var body: Node3D
var eye_l: Node3D
var eye_r: Node3D
var claw_l: Node3D
var claw_r: Node3D
var jaw_l: Node3D
var jaw_r: Node3D
var legs: Array[Node3D] = []
var carry_point: Node3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta(&"crab_generated", false):
			c.free()
	legs.clear()
	body = Node3D.new()
	body.name = "Body"
	body.set_meta(&"crab_generated", true)
	body.position = Vector3(0, 0.32, 0)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	var shell := shell_color
	var dark := shell.darkened(0.3)
	var belly := shell.lightened(0.35)
	_part(body, func(mb: MeshBuilder, gl: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.42, 0.2, 0.33), Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), shell, 10, 16)
		mb.ellipsoid(Vector3(0.36, 0.1, 0.28), Transform3D(Basis.IDENTITY, Vector3(0, -0.08, 0)), belly, 8, 14)
		# Shell bumps and a darker rim give the shell form.
		for k in 5:
			var a := -0.9 + k * 0.45
			mb.sphere(0.06, Transform3D(Basis.IDENTITY, Vector3(sin(a) * 0.26, 0.17, cos(a) * 0.14 + 0.03)), shell.lightened(0.12), 4, 8)
		mb.torus(0.34, 0.4, Transform3D(Basis.from_scale(Vector3(1.0, 0.4, 0.8)), Vector3(0, -0.02, 0)), dark, 18, 6)
		# Little mouth.
		mb.box(Vector3(0.1, 0.025, 0.02), Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.32)), dark.darkened(0.3))
		if variant == Variant.ARMORED:
			gl.ellipsoid(Vector3(0.44, 0.16, 0.35), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Palette.METAL, 8, 14)
			for k in 3:
				gl.sphere(0.045, Transform3D(Basis.IDENTITY, Vector3(-0.18 + k * 0.18, 0.25, 0.0)), Palette.BRASS, 4, 6)
		elif variant == Variant.HERMIT:
			gl.cylinder(0.05, 0.3, 0.42, Transform3D(Basis.from_euler(Vector3(-0.5, 0, 0)), Vector3(0, 0.25, 0.12)), Color("e8d2b0"), 14)
			gl.torus(0.1, 0.24, Transform3D(Basis.from_euler(Vector3(-0.5, 0, 0)), Vector3(0, 0.18, 0.1)), Color("d4a373"), 14, 6)
	)
	eye_l = _eye(Vector3(-0.11, 0.14, -0.2))
	eye_r = _eye(Vector3(0.11, 0.14, -0.2))
	claw_l = _claw(Vector3(-0.38, -0.02, -0.18), 0.7, -1.0)
	claw_r = _claw(Vector3(0.38, -0.02, -0.18), 1.25, 1.0)
	jaw_l = claw_l.get_node("Jaw")
	jaw_r = claw_r.get_node("Jaw")
	carry_point = Node3D.new()
	carry_point.name = "CarryPoint"
	carry_point.position = Vector3(0.0, 0.35, -0.25)
	body.add_child(carry_point)
	for side: float in [-1.0, 1.0]:
		for k in 3:
			legs.append(_leg(Vector3(side * 0.33, -0.06, -0.05 + k * 0.13), side, k))


func _part(parent: Node3D, fill: Callable) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var gl := MeshBuilder.new()
	fill.call(mb, gl)
	var mesh := ArrayMesh.new()
	if not mb.is_empty():
		mb.build(mesh, MaterialLibrary.toon(Color.WHITE, &"glossy"))
	if not gl.is_empty():
		gl.build(mesh, MaterialLibrary.toon(Color.WHITE, &"metal"))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	parent.add_child(mi)
	return mi


func _eye(pos: Vector3) -> Node3D:
	var stalk := Node3D.new()
	stalk.name = "EyeStalk"
	stalk.position = pos
	body.add_child(stalk)
	_part(stalk, func(mb: MeshBuilder, _gl: MeshBuilder) -> void:
		mb.cylinder(0.025, 0.03, 0.18, Transform3D(Basis.IDENTITY, Vector3(0, 0.09, 0)), shell_color.darkened(0.15), 6)
		mb.sphere(0.075, Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0)), Palette.EYE_WHITE, 8, 10)
		mb.sphere(0.04, Transform3D(Basis.IDENTITY, Vector3(0, 0.205, -0.055)), Palette.PUPIL, 6, 8)
	)
	return stalk


func _claw(pos: Vector3, size: float, side: float) -> Node3D:
	var arm := Node3D.new()
	arm.name = "ClawL" if side < 0.0 else "ClawR"
	arm.position = pos
	body.add_child(arm)
	var c := shell_color
	_part(arm, func(mb: MeshBuilder, _gl: MeshBuilder) -> void:
		mb.cylinder(0.05, 0.055, 0.22, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 0, -0.08)), c.darkened(0.1), 8)
		# Palm (fixed upper pincer).
		mb.ellipsoid(Vector3(0.12, 0.1, 0.16) * size, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, -0.25 * size)), c.lightened(0.05), 8, 12)
		mb.ellipsoid(Vector3(0.05, 0.05, 0.14) * size, Transform3D(Basis.from_euler(Vector3(0.25, 0, 0)), Vector3(0, 0.05 * size, -0.42 * size)), c.lightened(0.15), 6, 8)
	)
	var jaw := Node3D.new()
	jaw.name = "Jaw"
	jaw.position = Vector3(0, -0.02 * size, -0.3 * size)
	arm.add_child(jaw)
	_part(jaw, func(mb: MeshBuilder, _gl: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.045, 0.04, 0.13) * size, Transform3D(Basis.from_euler(Vector3(-0.2, 0, 0)), Vector3(0, -0.02 * size, -0.1 * size)), c.lightened(0.2), 6, 8)
	)
	return arm


func _leg(pos: Vector3, side: float, index: int) -> Node3D:
	var hip := Node3D.new()
	hip.name = "Leg%d%s" % [index, "L" if side < 0.0 else "R"]
	hip.position = pos
	body.add_child(hip)
	var c := shell_color.darkened(0.12)
	_part(hip, func(mb: MeshBuilder, _gl: MeshBuilder) -> void:
		var pts := PackedVector3Array([Vector3.ZERO, Vector3(side * 0.16, 0.08, 0), Vector3(side * 0.28, -0.12, 0), Vector3(side * 0.32, -0.3, 0)])
		mb.tube(pts, PackedFloat32Array([0.035, 0.03, 0.025, 0.012]), c, 6)
	)
	return hip
