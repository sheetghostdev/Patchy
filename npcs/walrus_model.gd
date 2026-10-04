@tool
class_name WalrusModel
extends Node3D
## Gus, Barnacle Bay's shipwright: a big barrel of a walrus in a red knit
## cap and a scuffed leather apron, with a bristly moustache over two long
## tusks, a pencil tucked behind one ear and a mallet he can't stop tapping
## against his flipper. Original design.

const SKIN := Color("9a7462")
const SKIN_DARK := Color("74543f")
const SKIN_LIGHT := Color("c49a82")
const WHISKER := Color("efe2c8")
const TUSK := Color("f6efdc")
const CAP := Color("d9483b")
const APRON := Color("8a5a36")

var body: Node3D
var head: Node3D
var arm: Node3D
var _t := 0.0


func _ready() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	body = Node3D.new()
	body.set_meta(&"generated", true)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	_part(body, func(mb: MeshBuilder) -> void:
		# A great round body on a flat tail, a pale belly, the apron.
		mb.ellipsoid(Vector3(0.62, 0.66, 0.56), Transform3D(Basis.IDENTITY, Vector3(0, 0.7, 0.04)), SKIN, 12, 16)
		mb.ellipsoid(Vector3(0.46, 0.5, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, 0.64, -0.36)), SKIN_LIGHT, 10, 12)
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.24, 0.07, 0.32), Transform3D(Basis.from_euler(Vector3(0, side * 0.5, 0)), Vector3(side * 0.32, 0.05, -0.12)), SKIN_DARK, 6, 10)
		# Apron: a bib and skirt of leather, its strap, a pocket of nails.
		mb.ellipsoid(Vector3(0.44, 0.48, 0.09), Transform3D(Basis.IDENTITY, Vector3(0, 0.6, -0.48)), APRON, 8, 12)
		mb.box(Vector3(0.22, 0.14, 0.04), Transform3D(Basis.IDENTITY, Vector3(0.12, 0.48, -0.57)), APRON.darkened(0.2))
		for k in 3:
			mb.cylinder(0.01, 0.01, 0.1, Transform3D(Basis.IDENTITY, Vector3(0.06 + k * 0.05, 0.59, -0.57)), Palette.METAL, 4)
		mb.torus(0.5, 0.53, Transform3D(Basis.from_euler(Vector3(-0.15, 0, 0)), Vector3(0, 1.05, 0.0)), APRON.darkened(0.3), 20, 4)
		# The resting flipper (left), down by his side.
		mb.ellipsoid(Vector3(0.12, 0.3, 0.1), Transform3D(Basis.from_euler(Vector3(0.2, 0, -0.35)), Vector3(-0.6, 0.72, -0.12)), SKIN_DARK, 6, 10)
	)
	arm = Node3D.new()
	arm.position = Vector3(0.58, 0.95, -0.15)
	body.add_child(arm)
	_part(arm, func(mb: MeshBuilder) -> void:
		# The right flipper and his mallet.
		mb.ellipsoid(Vector3(0.12, 0.3, 0.1), Transform3D(Basis.from_euler(Vector3(-0.7, 0, 0.3)), Vector3(0.04, -0.12, -0.16)), SKIN_DARK, 6, 10)
		mb.cylinder(0.028, 0.028, 0.62, Transform3D(Basis.from_euler(Vector3(-0.3, 0, 0)), Vector3(0.06, 0.02, -0.36)), Palette.WOOD, 6)
		mb.rounded_box(Vector3(0.3, 0.16, 0.16), 0.04, Transform3D(Basis.IDENTITY, Vector3(0.06, 0.32, -0.27)), Palette.WOOD_DARK)
	)
	head = Node3D.new()
	head.position = Vector3(0, 1.32, -0.06)
	body.add_child(head)
	_part(head, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.36, 0.32, 0.34), Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), SKIN, 12, 16)
		# Big whiskered muzzle, a nose, two tusks curving down.
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.17, 0.13, 0.13), Transform3D(Basis.IDENTITY, Vector3(side * 0.12, -0.02, -0.28)), SKIN_LIGHT, 8, 10)
			for k in 3:
				mb.box(Vector3(0.16, 0.008, 0.008), Transform3D(Basis.from_euler(Vector3(0, side * -0.4, side * (0.15 - k * 0.15))), Vector3(side * 0.2, 0.0 - k * 0.035, -0.37)), WHISKER)
			var pts := PackedVector3Array([Vector3(side * 0.08, -0.08, -0.34), Vector3(side * 0.09, -0.24, -0.36), Vector3(side * 0.07, -0.38, -0.31)])
			mb.tube(pts, PackedFloat32Array([0.035, 0.028, 0.012]), TUSK, 7, true)
			mb.sphere(0.045, Transform3D(Basis.IDENTITY, Vector3(side * 0.13, 0.16, -0.27)), Palette.PUPIL, 6, 8)
			mb.sphere(0.012, Transform3D(Basis.IDENTITY, Vector3(side * 0.14, 0.18, -0.31)), Color.WHITE, 3, 4)
			mb.ellipsoid(Vector3(0.07, 0.02, 0.03), Transform3D(Basis.from_euler(Vector3(0, 0, side * -0.25)), Vector3(side * 0.14, 0.23, -0.28)), SKIN_DARK.darkened(0.3), 4, 6)
		# The moustache: a bristly ridge across the muzzle.
		for k in 9:
			var x := -0.22 + k * 0.055
			mb.ellipsoid(Vector3(0.045, 0.07, 0.04), Transform3D(Basis.from_euler(Vector3(0.3, 0, x * 1.2)), Vector3(x, 0.03 - absf(x) * 0.3, -0.37)), WHISKER.darkened(0.08), 4, 6)
		mb.ellipsoid(Vector3(0.07, 0.045, 0.04), Transform3D(Basis.IDENTITY, Vector3(0, 0.08, -0.38)), Color("3b2a24"), 6, 8)
		# Red knit cap with a fold and a bobble; a pencil behind the ear.
		mb.ellipsoid(Vector3(0.32, 0.2, 0.31), Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0.04)), CAP, 10, 14)
		mb.torus(0.26, 0.34, Transform3D(Basis.IDENTITY, Vector3(0, 0.23, 0.03)), CAP.darkened(0.15), 18, 6)
		mb.sphere(0.07, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0.06)), Color("f6efe0"), 5, 7)
		mb.cylinder(0.015, 0.015, 0.22, Transform3D(Basis.from_euler(Vector3(0.4, 0, 1.2)), Vector3(0.3, 0.18, 0.02)), Color("ffcf3f"), 6)
	)


func _part(parent: Node3D, fn: Callable) -> void:
	var mb := MeshBuilder.new()
	fn.call(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	parent.add_child(mi)


func _process(delta: float) -> void:
	if body == null or Engine.is_editor_hint():
		return
	_t += delta
	# Slow deep breaths, a nod, and the mallet tapping every few seconds.
	body.scale = Vector3(1.0 + sin(_t * 1.4) * 0.015, 1.0 - sin(_t * 1.4) * 0.01, 1.0)
	head.rotation.x = sin(_t * 0.8) * 0.05
	head.rotation.z = sin(_t * 0.5) * 0.04
	var ph := fmod(_t, 3.2)
	var tap := 0.0
	for start: float in [0.0, 0.3, 0.6]:
		var k := (ph - start) / 0.25
		if k > 0.0 and k < 1.0:
			tap = maxf(tap, sin(k * PI))
	arm.rotation.x = -tap * 0.6
