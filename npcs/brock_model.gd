@tool
class_name BrockModel
extends Node3D
## Brock the Croc (spec §100): a big, theatrical crocodile admiral. Purple
## coat with gold epaulettes and buttons, a lace jabot, a feathered bicorne
## worn sideways, a monocle and one gold tooth. While `talking` his jaw
## flaps and his right arm flourishes; at rest he puffs out his chest and
## sways his tail, chin held high. Original design.

const SCALES := Color("4f8a3c")
const SCALES_DARK := Color("3b6a2c")
const BELLY := Color("c9d68a")
const COAT := Color("5b2d82")
const GOLD := Color("f2c14e")
const HAT := Color("1e1a2b")

var talking := false
var body: Node3D
var head: Node3D
var jaw: Node3D
var arm_r: Node3D
var arm_l: Node3D
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
		# Stout legs and clawed feet.
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.15, 0.3, 0.17), Transform3D(Basis.IDENTITY, Vector3(side * 0.18, 0.3, 0.02)), SCALES, 6, 10)
			mb.ellipsoid(Vector3(0.14, 0.07, 0.24), Transform3D(Basis.IDENTITY, Vector3(side * 0.2, 0.06, -0.08)), SCALES_DARK, 5, 8)
			for k in 3:
				mb.cylinder(0.0, 0.03, 0.08, Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(side * 0.2 + (k - 1) * 0.07, 0.04, -0.33)), BELLY.lightened(0.3), 5)
		# Coat: body, flared skirts, open front showing the belly scales.
		mb.ellipsoid(Vector3(0.4, 0.5, 0.33), Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0)), COAT, 10, 14)
		mb.cylinder(0.36, 0.5, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, 0.68, 0.02)), COAT.darkened(0.08), 16, false)
		mb.ellipsoid(Vector3(0.2, 0.36, 0.1), Transform3D(Basis.IDENTITY, Vector3(0, 1.0, -0.27)), BELLY, 8, 10)
		for k in 4:
			for side: float in [-1.0, 1.0]:
				mb.sphere(0.03, Transform3D(Basis.IDENTITY, Vector3(side * 0.2, 1.22 - k * 0.14, -0.27 + k * 0.012)), GOLD, 4, 6)
		mb.cylinder(0.415, 0.415, 0.09, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0.02)), Color("2a1d14"), 18)
		mb.box(Vector3(0.14, 0.12, 0.04), Transform3D(Basis.IDENTITY, Vector3(0, 0.8, -0.4)), GOLD)
		# Lace jabot and gold epaulettes with fringe.
		for k in 3:
			mb.ellipsoid(Vector3(0.11 - k * 0.02, 0.05, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, 1.43 - k * 0.07, -0.27)), Color("f6f1e4"), 5, 8)
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Vector3(0.17, 0.05, 0.15), Transform3D(Basis.IDENTITY, Vector3(side * 0.38, 1.45, 0)), GOLD, 6, 10)
			for k in 5:
				mb.cylinder(0.012, 0.012, 0.1, Transform3D(Basis.IDENTITY, Vector3(side * (0.29 + k * 0.045), 1.38, -0.1 + (k % 2) * 0.1)), GOLD.darkened(0.15), 4)
	)
	tail = Node3D.new()
	tail.position = Vector3(0, 0.55, 0.3)
	body.add_child(tail)
	_part(tail, func(mb: MeshBuilder) -> void:
		var pts := PackedVector3Array()
		var radii := PackedFloat32Array()
		for i in 9:
			var k := float(i) / 8.0
			pts.append(Vector3(0, -0.45 * k + 0.15 * sin(k * PI) - 0.05, 0.05 + 1.25 * k))
			radii.append(lerpf(0.22, 0.04, k))
		mb.tube(pts, radii, SCALES, 8, true)
		for i in 5:
			var k := 0.15 + i * 0.16
			mb.cylinder(0.0, 0.05, 0.1, Transform3D(Basis.IDENTITY, Vector3(0, -0.45 * k + 0.15 * sin(k * PI) + lerpf(0.2, 0.06, k), 0.05 + 1.25 * k)), SCALES_DARK, 4)
	)
	arm_l = _arm(-1.0)
	arm_r = _arm(1.0)
	head = Node3D.new()
	head.position = Vector3(0, 1.5, -0.02)
	body.add_child(head)
	_part(head, func(mb: MeshBuilder) -> void:
		# Skull and long upper snout, nostril bumps, a row of teeth.
		mb.ellipsoid(Vector3(0.27, 0.22, 0.28), Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), SCALES, 10, 14)
		mb.ellipsoid(Vector3(0.21, 0.1, 0.42), Transform3D(Basis.IDENTITY, Vector3(0, 0.07, -0.42)), SCALES, 8, 12)
		for side: float in [-1.0, 1.0]:
			mb.sphere(0.04, Transform3D(Basis.IDENTITY, Vector3(side * 0.06, 0.15, -0.78)), SCALES_DARK, 4, 6)
			for k in 6:
				mb.cylinder(0.0, 0.028, 0.07, Transform3D(Basis.from_euler(Vector3(PI, 0, 0)), Vector3(side * 0.17, 0.0, -0.2 - k * 0.1)), Color("fffbea") if k != 2 or side < 0.0 else GOLD, 4)
			# Bulging eyes on top with heavy, haughty lids.
			mb.sphere(0.085, Transform3D(Basis.IDENTITY, Vector3(side * 0.13, 0.3, -0.06)), Color("f3d64a"), 6, 10)
			mb.box(Vector3(0.018, 0.1, 0.02), Transform3D(Basis.IDENTITY, Vector3(side * 0.13, 0.3, -0.142)), Palette.PUPIL)
			mb.ellipsoid(Vector3(0.1, 0.05, 0.1), Transform3D(Basis.from_euler(Vector3(-0.35, 0, side * -0.15)), Vector3(side * 0.13, 0.36, -0.07)), SCALES_DARK, 5, 8)
		# Monocle on the right eye, its chain looping down.
		mb.torus(0.075, 0.095, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0.13, 0.3, -0.16)), GOLD, 14, 4)
		mb.tube(PackedVector3Array([Vector3(0.21, 0.27, -0.15), Vector3(0.27, 0.1, -0.1), Vector3(0.26, -0.08, -0.05)]), PackedFloat32Array([0.008, 0.008, 0.008]), GOLD, 4, false)
		# Bicorne, worn sideways, with gold trim, cockade and plume.
		mb.ellipsoid(Vector3(0.2, 0.1, 0.17), Transform3D(Basis.IDENTITY, Vector3(0, 0.36, 0.02)), HAT, 8, 10)
		mb.ellipsoid(Vector3(0.52, 0.24, 0.075), Transform3D(Basis.IDENTITY, Vector3(0, 0.46, 0.02)), GOLD, 10, 16)
		mb.ellipsoid(Vector3(0.49, 0.225, 0.09), Transform3D(Basis.IDENTITY, Vector3(0, 0.455, 0.02)), HAT, 10, 16)
		mb.cylinder(0.07, 0.07, 0.02, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0.2, 0.52, -0.08)), Palette.COAT, 12)
		mb.cylinder(0.04, 0.04, 0.025, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0.2, 0.52, -0.085)), Color("f6f1e4"), 10)
		var plume := PackedVector3Array()
		var pr := PackedFloat32Array()
		for i in 7:
			var k := float(i) / 6.0
			plume.append(Vector3(-0.1 - 0.1 * k, 0.62 + 0.38 * sin(k * 1.4), 0.05 + 0.32 * k * k))
			pr.append(lerpf(0.05, 0.015, k))
		mb.tube(plume, pr, Color("e8483c"), 6, true)
	)
	jaw = Node3D.new()
	jaw.position = Vector3(0, 0.02, -0.12)
	head.add_child(jaw)
	_part(jaw, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.19, 0.06, 0.4), Transform3D(Basis.IDENTITY, Vector3(0, -0.04, -0.3)), BELLY, 8, 12)
		for side: float in [-1.0, 1.0]:
			for k in 5:
				mb.cylinder(0.0, 0.025, 0.06, Transform3D(Basis.IDENTITY, Vector3(side * 0.15, 0.03, -0.12 - k * 0.1)), Color("fffbea"), 4)
	)


func _arm(side: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.42, 1.36, 0)
	body.add_child(pivot)
	_part(pivot, func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Vector3(0.1, 0.27, 0.11), Transform3D(Basis.IDENTITY, Vector3(0, -0.22, 0)), COAT, 6, 10)
		mb.cylinder(0.11, 0.11, 0.07, Transform3D(Basis.IDENTITY, Vector3(0, -0.45, 0)), GOLD, 10)
		mb.ellipsoid(Vector3(0.08, 0.09, 0.07), Transform3D(Basis.IDENTITY, Vector3(0, -0.55, 0)), SCALES, 6, 8)
		for k in 3:
			mb.cylinder(0.0, 0.022, 0.08, Transform3D(Basis.IDENTITY, Vector3((k - 1) * 0.04, -0.66, -0.02)), BELLY.lightened(0.3), 4)
	)
	pivot.rotation.z = side * 0.18
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
	body.scale = Vector3(1.0, 1.0 + sin(_t * 1.6) * 0.012, 1.0 + sin(_t * 1.6) * 0.02)
	tail.rotation.y = sin(_t * 0.9) * 0.25
	head.rotation.x = -0.12 + sin(_t * 0.7) * 0.03
	if talking:
		jaw.rotation.x = absf(sin(_t * 11.0)) * 0.3
		# Theatrical flourishes: point, sweep, point.
		var g := fmod(_t, 2.4) / 2.4
		arm_r.rotation = Vector3(lerpf(-1.4, -0.6, smoothstep(0.3, 0.7, g)), 0, lerpf(0.18, 1.2, sin(g * PI)))
		arm_l.rotation = Vector3(0.0, 0, -0.18 - 0.5 * sin(_t * 1.3) * 0.5)
		head.rotation.y = sin(_t * 2.2) * 0.12
	else:
		jaw.rotation.x = move_toward(jaw.rotation.x, 0.0, delta * 2.0)
		# Hands on hips, chin up.
		arm_r.rotation = arm_r.rotation.lerp(Vector3(0.0, 0, 0.55), 1.0 - exp(-delta * 4.0))
		arm_l.rotation = arm_l.rotation.lerp(Vector3(0.0, 0, -0.55), 1.0 - exp(-delta * 4.0))
		head.rotation.y = lerpf(head.rotation.y, 0.0, 1.0 - exp(-delta * 3.0))
