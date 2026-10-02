@tool
class_name OtterModel
extends Node3D
## Pip, Driftwood Key's young sea otter (spec §101): stands on her hind
## feet in a yellow sou'wester with a red-and-white life ring around her
## middle, paws together, and can't keep still: little hops, tail wags,
## curious head tilts. Original design.

const FUR := Color("75502f")
const FUR_DARK := Color("553720")
const FUR_LIGHT := Color("ead2a8")
const HAT := Color("ffc93c")
const RING_RED := Color("e8483c")
const RING_WHITE := Color("f7f3ea")

var body: Node3D
var head: Node3D
var paws: Node3D
var tail: Node3D
var _t := 0.0


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	body = Node3D.new()
	body.set_meta(&"generated", true)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	_part(body, func(mb: MeshBuilder) -> void:
		# Webbed hind feet, stubby legs, a long sleek body with a pale chest.
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.065, 0.03, 0.11), Transform3D(Basis.from_euler(Vector3(0, side * 0.3, 0)), Vector3(side * 0.085, 0.03, -0.05)), FUR_DARK, 5, 8)
			mb.ellipsoid(Vector3(0.07, 0.1, 0.075), Transform3D(Basis.IDENTITY, Vector3(side * 0.08, 0.11, 0.0)), FUR, 6, 8)
		mb.ellipsoid(Vector3(0.155, 0.25, 0.14), Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0)), FUR, 10, 14)
		mb.ellipsoid(Vector3(0.11, 0.19, 0.06), Transform3D(Basis.IDENTITY, Vector3(0, 0.41, -0.1)), FUR_LIGHT, 8, 10)
		# Life ring: eight alternating red and white sections.
		var n := 8
		var steps := 4
		for k in n:
			var pts := PackedVector3Array()
			var radii := PackedFloat32Array()
			for j in steps + 1:
				var a := TAU * (k + float(j) / steps) / n
				pts.append(Vector3(cos(a) * 0.19, 0.24, sin(a) * 0.175))
				radii.append(0.045)
			mb.tube(pts, radii, RING_RED if k % 2 == 0 else RING_WHITE, 8, false)
	)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.14, 0.1)
	body.add_child(tail)
	_part(tail, func(mb: MeshBuilder) -> void:
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 7:
			var k := float(i) / 6.0
			pts.append(Vector3(0, -0.1 * k + 0.02 * sin(k * PI), 0.04 + 0.36 * k))
			radii.append(lerpf(0.075, 0.03, k))
		mb.tube(pts, radii, FUR, 8, true)
	)
	paws = Node3D.new()
	paws.position = Vector3(0, 0.5, -0.04)
	body.add_child(paws)
	_part(paws, func(mb: MeshBuilder) -> void:
		# Short arms with the paws held together at the chest.
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.04, 0.09, 0.04), Transform3D(Basis.from_euler(Vector3(-0.9, 0, side * 0.6)), Vector3(side * 0.08, -0.04, -0.07)), FUR, 5, 8)
			mb.sphere(0.04, Transform3D(Basis.IDENTITY, Vector3(side * 0.03, -0.07, -0.14)), FUR_DARK, 5, 7)
	)
	head = Node3D.new()
	head.position = Vector3(0, 0.6, 0)
	body.add_child(head)
	_part(head, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.15, 0.13, 0.14), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), FUR, 10, 14)
		# Pale face, puffy cheeks, a big button nose and whiskers.
		mb.ellipsoid(Vector3(0.1, 0.065, 0.07), Transform3D(Basis.IDENTITY, Vector3(0, 0.055, -0.11)), FUR_LIGHT, 8, 10)
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.055, 0.045, 0.045), Transform3D(Basis.IDENTITY, Vector3(side * 0.055, 0.06, -0.135)), FUR_LIGHT.lightened(0.05), 5, 8)
			mb.sphere(0.03, Transform3D(Basis.IDENTITY, Vector3(side * 0.062, 0.145, -0.115)), Palette.PUPIL, 6, 8)
			mb.sphere(0.009, Transform3D(Basis.IDENTITY, Vector3(side * 0.07, 0.155, -0.142)), Color.WHITE, 3, 4)
			mb.sphere(0.035, Transform3D(Basis.IDENTITY, Vector3(side * 0.125, 0.16, 0.03)), FUR_DARK, 5, 7)
			for w in 3:
				var tilt := (w - 1) * 0.18
				mb.box(Vector3(0.11, 0.006, 0.006), Transform3D(Basis.from_euler(Vector3(0, side * -0.35, side * tilt)), Vector3(side * 0.12, 0.06 + (w - 1) * 0.012, -0.15)), FUR_LIGHT.lightened(0.3))
		mb.ellipsoid(Vector3(0.036, 0.022, 0.02), Transform3D(Basis.IDENTITY, Vector3(0, 0.092, -0.178)), Color("2b2024"), 5, 8)
		mb.ellipsoid(Vector3(0.02, 0.008, 0.01), Transform3D(Basis.IDENTITY, Vector3(0, 0.035, -0.178)), Color("2b2024"), 3, 5)
		# Yellow sou'wester, its brim longer at the back.
		mb.ellipsoid(Vector3(0.125, 0.08, 0.125), Transform3D(Basis.IDENTITY, Vector3(0, 0.215, 0.01)), HAT, 8, 12)
		mb.cylinder(0.175, 0.175, 0.016, Transform3D(Basis.from_euler(Vector3(0.18, 0, 0)).scaled(Vector3(1.0, 1.0, 1.15)), Vector3(0, 0.185, 0.03)), HAT.darkened(0.06), 18)
	)


func _part(parent: Node3D, fn: Callable) -> void:
	var mb := MeshBuilder.new()
	fn.call(mb)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	parent.add_child(mi)


func _process(delta: float) -> void:
	if body == null:
		return
	_t += delta
	# A double hop every 4 s, a wagging tail and a curious head tilt.
	var ph := fmod(_t, 4.0)
	var hop := 0.0
	for start: float in [0.0, 0.42]:
		var k := (ph - start) / 0.38
		if k > 0.0 and k < 1.0:
			hop = maxf(hop, sin(k * PI) * 0.07)
	body.position.y = hop
	body.scale = Vector3(1.0, 1.0 + sin(_t * 2.6) * 0.012, 1.0)
	tail.rotation.y = sin(_t * 3.1) * 0.3
	head.rotation = Vector3(sin(_t * 0.7) * 0.06, sin(_t * 0.45) * 0.2, sin(_t * 0.9 + 1.0) * 0.12)
	paws.rotation.x = -hop * 2.0
