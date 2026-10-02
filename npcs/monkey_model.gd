@tool
class_name MonkeyModel
extends Node3D
## Tok, the outpost's lookout (spec §101): a small capuchin-ish monkey in a
## striped sailor shirt and red bandana with a curly tail, who every few
## seconds raises his brass spyglass to sweep the horizon. Original design.

const FUR := Color("8b5a3b")
const FUR_DARK := Color("6a4028")
const FACE := Color("f1d3a8")
const EAR_IN := Color("e7a294")
const SHIRT := Color("f6f1e4")
const STRIPE := Color("3b6fb6")

var body: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var spyglass: Node3D
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
		# Legs and big monkey feet.
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.075, 0.13, 0.085), Transform3D(Basis.from_euler(Vector3(0.15, 0, side * 0.12)), Vector3(side * 0.09, 0.15, 0.0)), FUR, 6, 10)
			mb.ellipsoid(Vector3(0.07, 0.04, 0.12), Transform3D(Basis.from_euler(Vector3(0, side * 0.2, 0)), Vector3(side * 0.11, 0.035, -0.05)), FACE.darkened(0.08), 5, 8)
		# Striped shirt.
		mb.ellipsoid(Vector3(0.17, 0.2, 0.15), Transform3D(Basis.IDENTITY, Vector3(0, 0.42, 0)), SHIRT, 10, 14)
		for dy: float in [-0.1, -0.03, 0.04, 0.11]:
			var r := 0.17 * sqrt(1.0 - pow(dy / 0.2, 2.0)) + 0.004
			mb.torus(r - 0.014, r + 0.006, Transform3D(Basis.from_scale(Vector3(1.0, 1.0, 0.15 / 0.17)), Vector3(0, 0.42 + dy, 0)), STRIPE, 18, 4)
		# Red bandana with a knot at the front.
		mb.torus(0.075, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, 0.6, 0)), Palette.COAT, 14, 5)
		mb.ellipsoid(Vector3(0.05, 0.06, 0.03), Transform3D(Basis.from_euler(Vector3(0.2, 0, 0.6)), Vector3(0.03, 0.56, -0.1)), Palette.COAT.darkened(0.1), 5, 8)
	)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.3, 0.12)
	body.add_child(tail)
	_part(tail, func(mb: MeshBuilder) -> void:
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		var n := 14
		for i in n:
			var k := float(i) / (n - 1)
			# Out the back, then up into a curl.
			var a := k * 4.4
			var p := Vector3(0, -0.06 * sin(k * PI) + 0.34 * k * k, 0.12 + 0.3 * k)
			if k > 0.55:
				var c := (k - 0.55) / 0.45
				p += Vector3(0, 0.06 * sin(a), -0.08 * c * c)
			pts.append(p)
			radii.append(lerpf(0.04, 0.022, k))
		mb.tube(pts, radii, FUR, 7, true)
	)
	head = Node3D.new()
	head.position = Vector3(0, 0.64, 0)
	body.add_child(head)
	_part(head, func(mb: MeshBuilder) -> void:
		mb.sphere(0.17, Transform3D(Basis.IDENTITY, Vector3(0, 0.17, 0)), FUR, 10, 14)
		# Heart-shaped face mask and a round muzzle.
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.075, 0.085, 0.06), Transform3D(Basis.IDENTITY, Vector3(side * 0.05, 0.2, -0.125)), FACE, 6, 10)
		mb.ellipsoid(Vector3(0.095, 0.07, 0.07), Transform3D(Basis.IDENTITY, Vector3(0, 0.1, -0.14)), FACE.lightened(0.08), 6, 10)
		for side: float in [-1.0, 1.0]:
			mb.sphere(0.045, Transform3D(Basis.IDENTITY, Vector3(side * 0.052, 0.205, -0.17)), Palette.EYE_WHITE, 6, 8)
			mb.sphere(0.025, Transform3D(Basis.IDENTITY, Vector3(side * 0.054, 0.205, -0.208)), Palette.PUPIL, 4, 6)
			mb.box(Vector3(0.06, 0.014, 0.02), Transform3D(Basis.from_euler(Vector3(0, 0, side * -0.25)), Vector3(side * 0.055, 0.262, -0.17)), FUR_DARK)
			mb.sphere(0.011, Transform3D(Basis.IDENTITY, Vector3(side * 0.017, 0.125, -0.207)), FUR_DARK, 3, 5)
			# Round ears, pink inside.
			mb.cylinder(0.075, 0.075, 0.03, Transform3D(Basis.from_euler(Vector3(0, side * 0.35, PI * 0.5)), Vector3(side * 0.17, 0.19, -0.01)), FUR, 12)
			mb.cylinder(0.05, 0.05, 0.02, Transform3D(Basis.from_euler(Vector3(0, side * 0.35, PI * 0.5)), Vector3(side * 0.18, 0.19, -0.022)), EAR_IN, 10)
		# Grin and a scruffy tuft.
		mb.ellipsoid(Vector3(0.04, 0.012, 0.012), Transform3D(Basis.IDENTITY, Vector3(0, 0.072, -0.2)), FUR_DARK.darkened(0.3), 4, 6)
		for k in 3:
			mb.ellipsoid(Vector3(0.03, 0.07, 0.03), Transform3D(Basis.from_euler(Vector3(-0.3, 0, (k - 1) * 0.45)), Vector3((k - 1) * 0.035, 0.34, 0.0)), FUR_DARK, 4, 6)
	)
	arm_l = _arm(-1.0)
	arm_r = _arm(1.0)
	# The spyglass stays level whatever the arm does (see _process).
	spyglass = Node3D.new()
	spyglass.position = Vector3(0, -0.3, 0)
	arm_r.add_child(spyglass)
	_part(spyglass, func(mb: MeshBuilder) -> void:
		var fwd := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
		mb.cylinder(0.034, 0.034, 0.14, Transform3D(fwd, Vector3(0, 0, -0.11)), Palette.BRASS, 10)
		mb.cylinder(0.037, 0.037, 0.06, Transform3D(fwd, Vector3(0, 0, -0.09)), Palette.BOOTS, 10)
		mb.cylinder(0.029, 0.029, 0.11, Transform3D(fwd, Vector3(0, 0, -0.22)), Palette.BRASS.lightened(0.1), 10)
		mb.cylinder(0.024, 0.024, 0.09, Transform3D(fwd, Vector3(0, 0, -0.31)), Palette.BRASS, 10)
		mb.cylinder(0.026, 0.026, 0.012, Transform3D(fwd, Vector3(0, 0, -0.355)), Color("9fd4ff"), 10)
	)
	arm_l.rotation = Vector3(0.15, 0, -0.2)
	arm_r.rotation = Vector3(1.2, 0, 0.2)
	spyglass.basis = arm_r.basis.inverse()


func _arm(side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.17, 0.55, 0)
	body.add_child(pivot)
	_part(pivot, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.048, 0.16, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, -0.14, 0)), FUR, 6, 10)
		mb.sphere(0.05, Transform3D(Basis.IDENTITY, Vector3(0, -0.29, 0)), FACE.darkened(0.08), 6, 8)
	)
	return pivot


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
	body.scale = Vector3(1.0, 1.0 + sin(_t * 2.2) * 0.015, 1.0)
	tail.rotation = Vector3(sin(_t * 1.3) * 0.12, sin(_t * 0.9) * 0.35, 0)
	# Every 6 s: spyglass up to the eye, a slow sweep of the horizon, down.
	var ph := fmod(_t, 6.0) / 6.0
	var up := smoothstep(0.0, 0.1, ph) * (1.0 - smoothstep(0.5, 0.62, ph))
	arm_r.rotation = Vector3(lerpf(1.2, 2.72, up), 0, lerpf(0.2, -0.38, up))
	spyglass.basis = arm_r.basis.inverse()
	var sweep := sin((ph - 0.1) / 0.4 * TAU) * 0.35 if ph > 0.1 and ph < 0.5 else 0.0
	body.rotation.y = sweep * up
	head.rotation = Vector3(lerpf(0.0, -0.08, up), 0, 0)
	arm_l.rotation = Vector3(0.15 + sin(_t * 1.7) * 0.05, 0, -0.2 - up * 0.25)
