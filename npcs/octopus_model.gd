@tool
class_name OctopusModel
extends Node3D
## Auntie Ink, keeper of the Soggy Biscuit: a plump pink octopus in a
## polka-dot headscarf and a little apron, standing on a curl of tentacles
## while two more polish a mug and wave hello. Never still. Original design.

const SKIN := Color("e8789a")
const SKIN_LIGHT := Color("f6b3c4")
const SPOTS := Color("c95479")
const SCARF := Color("3fa7ef")

var body: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var _t := 0.0


func _ready() -> void:
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	arms.clear()
	body = Node3D.new()
	body.set_meta(&"generated", true)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	head = Node3D.new()
	head.position = Vector3(0, 0.95, 0)
	body.add_child(head)
	_part(head, func(mb: MeshBuilder) -> void:
		# The great round mantle with spots, big kind eyes, a smile.
		mb.ellipsoid(Vector3(0.46, 0.5, 0.44), Transform3D(Basis.IDENTITY, Vector3(0, 0.24, 0.06)), SKIN, 12, 16)
		for k in 7:
			var a := -1.2 + k * 0.4
			mb.ellipsoid(Vector3(0.05, 0.04, 0.02), Transform3D(Basis.from_euler(Vector3(0, a, 0)), Vector3(sin(a) * 0.37, 0.36 + (k % 2) * 0.12, cos(a) * 0.3 + 0.08)), SPOTS, 4, 6)
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.1, 0.12, 0.06), Transform3D(Basis.IDENTITY, Vector3(side * 0.15, 0.08, -0.3)), Color.WHITE, 6, 8)
			mb.sphere(0.06, Transform3D(Basis.IDENTITY, Vector3(side * 0.14, 0.06, -0.35)), Palette.PUPIL, 6, 8)
			mb.sphere(0.018, Transform3D(Basis.IDENTITY, Vector3(side * 0.12, 0.1, -0.4)), Color.WHITE, 3, 4)
			mb.ellipsoid(Vector3(0.06, 0.03, 0.02), Transform3D(Basis.IDENTITY, Vector3(side * 0.24, -0.05, -0.31)), Color("ff9fb6"), 4, 6)
		mb.torus(0.05, 0.07, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, -0.07, -0.36)).scaled_local(Vector3(1.4, 1.0, 0.6)), SKIN.darkened(0.35), 10, 4)
		# Headscarf, knotted at the back with two tails, polka dots.
		mb.ellipsoid(Vector3(0.44, 0.24, 0.42), Transform3D(Basis.IDENTITY, Vector3(0, 0.46, 0.08)), SCARF, 10, 14)
		for k in 8:
			var a := TAU * k / 8.0
			mb.sphere(0.035, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.36, 0.5 + (k % 2) * 0.08, sin(a) * 0.34 + 0.08)), Color("f6efe0"), 3, 5)
		mb.sphere(0.08, Transform3D(Basis.IDENTITY, Vector3(0, 0.44, 0.5)), SCARF.darkened(0.1), 5, 7)
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.05, 0.14, 0.03), Transform3D(Basis.from_euler(Vector3(0.6, 0, side * 0.5)), Vector3(side * 0.08, 0.32, 0.58)), SCARF, 4, 6)
	)
	_part(body, func(mb: MeshBuilder) -> void:
		# A little apron round where the tentacles meet.
		mb.ellipsoid(Vector3(0.36, 0.2, 0.32), Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0.02)), SKIN_LIGHT, 10, 14)
		mb.ellipsoid(Vector3(0.2, 0.11, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, 0.7, -0.28)), Color("f6efe0"), 8, 10)
		mb.torus(0.3, 0.33, Transform3D(Basis.IDENTITY, Vector3(0, 0.82, 0.02)), Color("f6efe0"), 18, 4)
	)
	# Eight tentacles: six for standing on, two lifted (a mug and a wave).
	for k in 8:
		var pivot := Node3D.new()
		var a := TAU * (k + 0.5) / 8.0
		pivot.position = Vector3(cos(a) * 0.22, 0.75, sin(a) * 0.2)
		pivot.rotation.y = -a - PI * 0.5
		body.add_child(pivot)
		arms.append(pivot)
		var lifted := k == 4 or k == 7
		_part(pivot, func(mb: MeshBuilder) -> void:
			var pts := PackedVector3Array()
			var radii := PackedFloat32Array()
			for i in 9:
				var u := float(i) / 8.0
				if lifted:
					pts.append(Vector3(0, -0.05 + u * 0.5 - u * u * 0.1, -0.1 - u * 0.32))
				else:
					pts.append(Vector3(sin(u * 4.0) * 0.05, -0.72 * smoothstep(0.0, 0.45, u) + 0.12 * smoothstep(0.75, 1.0, u), -0.05 - u * 0.7))
				radii.append(lerpf(0.12, 0.03, u))
			mb.tube(pts, radii, SKIN, 8, true)
			for i in range(2, 8, 2):
				mb.sphere(0.022, Transform3D(Basis.IDENTITY, pts[i] + Vector3(0, -radii[i] * 0.8, 0)), SKIN_LIGHT, 3, 5)
			if lifted and k == 7:
				# A frothy mug.
				var tip := pts[8]
				mb.cylinder(0.07, 0.065, 0.16, Transform3D(Basis.IDENTITY, tip + Vector3(0, 0.08, 0)), Color("c98a4b"), 10)
				mb.ellipsoid(Vector3(0.075, 0.04, 0.075), Transform3D(Basis.IDENTITY, tip + Vector3(0, 0.17, 0)), Color("fff6e0"), 5, 8)
				mb.torus(0.03, 0.045, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), tip + Vector3(0.08, 0.08, 0)), Color("c98a4b"), 8, 4)
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
	# The mantle bobs, every tentacle curls on its own beat, one waves.
	head.position.y = 0.95 + sin(_t * 1.8) * 0.03
	head.rotation.z = sin(_t * 0.9) * 0.06
	for k in arms.size():
		var a := arms[k]
		if k == 4:
			a.rotation.x = 0.4 + sin(_t * 5.0) * 0.35
		elif k == 7:
			a.rotation.x = sin(_t * 1.2) * 0.1
		else:
			a.rotation.x = sin(_t * 1.6 + k * 0.8) * 0.08
			a.rotation.z = sin(_t * 1.1 + k) * 0.05
