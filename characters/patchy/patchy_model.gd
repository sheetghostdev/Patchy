@tool
class_name PatchyModel
extends Node3D
## Patchy's stylized placeholder body (spec §4–5), built from soft primitives
## as a pivot rig the procedural animator drives. Readable silhouette first:
## oversized head with strong brows and big eyes, a wide pirate hat, chunky
## boots, big gloves and a clearly oversized hook on the right arm.
##
## Origin at the feet, facing -Z. Parts with several finishes get one surface
## per finish so materials stay shared.

## Rebuild in the editor after code edits.
@export var rebuild := false:
	set(v):
		_build()

const L := 2  # render layer used by Patchy (excluded from his blob shadow)

# Pivots the animator drives
var body: Node3D        ## squash/stretch & lean, origin at the feet
var spin: Node3D        ## flips/rolls around the center of mass
var hips: Node3D
var torso: Node3D
var chest: Node3D
var head: Node3D
var hat: Node3D
var tails: Node3D
var shoulder_l: Node3D
var elbow_l: Node3D
var shoulder_r: Node3D
var elbow_r: Node3D
var hook_socket: Node3D
var hip_l: Node3D
var knee_l: Node3D
var ankle_l: Node3D
var hip_r: Node3D
var knee_r: Node3D
var ankle_r: Node3D
var eye_l: Node3D
var eye_r: Node3D
var pupil_l: Node3D
var pupil_r: Node3D
var brow_l: Node3D
var brow_r: Node3D
var mouth: Node3D
var hook_mesh: MeshInstance3D

## Height of the spin pivot (center of mass) above the feet.
const SPIN_HEIGHT := 0.72
const HIP_HEIGHT := 0.5
const SHOULDER_Y := 0.47   # above hips
const NECK_Y := 0.6        # above hips


func _ready() -> void:
	_build()


func _build() -> void:
	for c in get_children(true):
		if c.get_meta(&"patchy_generated", false):
			c.free()
	body = _pivot(self, "Body", Vector3.ZERO)
	body.set_meta(&"patchy_generated", true)
	spin = _pivot(body, "Spin", Vector3(0, SPIN_HEIGHT, 0))
	hips = _pivot(spin, "Hips", Vector3(0, HIP_HEIGHT - SPIN_HEIGHT, 0))
	torso = _pivot(hips, "Torso", Vector3.ZERO)
	chest = _pivot(torso, "Chest", Vector3(0, SHOULDER_Y, 0))
	head = _pivot(torso, "Head", Vector3(0, NECK_Y, 0))
	hat = _pivot(head, "Hat", Vector3(0, 0.43, 0.0))
	tails = _pivot(torso, "Tails", Vector3(0, 0.16, 0.19))

	_build_torso()
	_build_head()
	_build_hat()
	_build_tails()

	shoulder_l = _pivot(chest, "ShoulderL", Vector3(-0.27, 0.0, 0.0))
	elbow_l = _pivot(shoulder_l, "ElbowL", Vector3(0, -0.21, 0))
	shoulder_r = _pivot(chest, "ShoulderR", Vector3(0.27, 0.0, 0.0))
	elbow_r = _pivot(shoulder_r, "ElbowR", Vector3(0, -0.21, 0))
	hook_socket = _pivot(elbow_r, "HookSocket", Vector3(0, -0.21, 0))
	_build_arm(shoulder_l, elbow_l, -1.0)
	_build_arm(shoulder_r, elbow_r, 1.0)
	_build_glove()
	_build_hook()

	hip_l = _pivot(hips, "HipL", Vector3(-0.115, -0.02, 0))
	knee_l = _pivot(hip_l, "KneeL", Vector3(0, -0.2, 0))
	ankle_l = _pivot(knee_l, "AnkleL", Vector3(0, -0.17, 0))
	hip_r = _pivot(hips, "HipR", Vector3(0.115, -0.02, 0))
	knee_r = _pivot(hip_r, "KneeR", Vector3(0, -0.2, 0))
	ankle_r = _pivot(knee_r, "AnkleR", Vector3(0, -0.17, 0))
	_build_leg(hip_l, knee_l, ankle_l)
	_build_leg(hip_r, knee_r, ankle_r)
	_part(hips, "Pelvis", func(m: Dictionary) -> void:
		(m[&"matte"] as MeshBuilder).ellipsoid(Vector3(0.2, 0.12, 0.16), xf(Vector3(0, 0.05, 0.01)), Palette.PANTS, 8, 14)
	)


# --- Construction helpers --------------------------------------------------------

func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n


## Builds a mesh part. `fill` receives a Dictionary finish -> MeshBuilder.
func _part(parent: Node3D, part_name: String, fill: Callable) -> MeshInstance3D:
	var buckets := {&"matte": MeshBuilder.new(), &"soft": MeshBuilder.new(), &"glossy": MeshBuilder.new(), &"metal": MeshBuilder.new()}
	fill.call(buckets)
	var mesh := ArrayMesh.new()
	for finish: StringName in buckets:
		var mb: MeshBuilder = buckets[finish]
		if not mb.is_empty():
			mb.build(mesh, MaterialLibrary.toon(Color.WHITE, finish))
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.layers = L
	parent.add_child(mi)
	return mi


static func xf(pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(rot_deg * (PI / 180.0)).scaled(scl)
	return Transform3D(b, pos)


# --- Body parts -------------------------------------------------------------------

func _build_torso() -> void:
	_part(torso, "Coat", func(m: Dictionary) -> void:
		var matte: MeshBuilder = m[&"matte"]
		var metal: MeshBuilder = m[&"metal"]
		# Lower coat flare and chest (red long coat).
		# Open frock coat: side panels below the belt, tails at the back.
		matte.rounded_box(Vector3(0.12, 0.27, 0.3), 0.05, xf(Vector3(-0.19, 0.05, 0.03), Vector3(0, 0, -9)), Palette.COAT, 2)
		matte.rounded_box(Vector3(0.12, 0.27, 0.3), 0.05, xf(Vector3(0.19, 0.05, 0.03), Vector3(0, 0, 9)), Palette.COAT, 2)
		matte.cylinder(0.215, 0.235, 0.12, xf(Vector3(0, 0.13, 0.04)), Palette.COAT, 18)
		matte.ellipsoid(Vector3(0.255, 0.26, 0.2), xf(Vector3(0, 0.38, 0.0)), Palette.COAT, 12, 18)
		# Shirt showing at the front, and gold lapel trim.
		matte.ellipsoid(Vector3(0.1, 0.17, 0.05), xf(Vector3(0, 0.42, -0.175), Vector3(-10, 0, 0)), Palette.SHIRT, 8, 12)
		matte.box(Vector3(0.03, 0.28, 0.025), xf(Vector3(-0.085, 0.37, -0.198), Vector3(-8, 0, 14)), Palette.COAT_TRIM)
		matte.box(Vector3(0.03, 0.28, 0.025), xf(Vector3(0.085, 0.37, -0.198), Vector3(-8, 0, -14)), Palette.COAT_TRIM)
		# Collar ring.
		matte.torus(0.09, 0.14, xf(Vector3(0, 0.58, 0.0)), Palette.COAT.darkened(0.25), 16, 6)
		# Belt + buckle.
		matte.cylinder(0.236, 0.236, 0.07, xf(Vector3(0, 0.19, 0)), Palette.BELT, 18)
		metal.rounded_box(Vector3(0.1, 0.08, 0.03), 0.012, xf(Vector3(0, 0.19, -0.238)), Palette.BRASS, 1)
		for k in 3:
			metal.sphere(0.018, xf(Vector3(0.07, 0.45 - k * 0.075, -0.205)), Palette.BRASS, 4, 8)
		# Tool satchel on the back (where attachments live) with straps.
		matte.rounded_box(Vector3(0.27, 0.25, 0.13), 0.04, xf(Vector3(0, 0.38, 0.2)), Palette.BOOTS, 2)
		matte.rounded_box(Vector3(0.28, 0.1, 0.14), 0.03, xf(Vector3(0, 0.48, 0.205), Vector3(8, 0, 0)), Color("8a5636"), 2)
		metal.sphere(0.022, xf(Vector3(0, 0.44, 0.28)), Palette.BRASS, 4, 8)
		matte.box(Vector3(0.035, 0.3, 0.02), xf(Vector3(-0.13, 0.42, -0.19), Vector3(-6, 0, 0)), Color("6b4129"))
		matte.box(Vector3(0.035, 0.3, 0.02), xf(Vector3(0.13, 0.42, -0.19), Vector3(-6, 0, 0)), Color("6b4129"))
	)


func _build_head() -> void:
	_part(head, "Head", func(m: Dictionary) -> void:
		var soft: MeshBuilder = m[&"soft"]
		var matte: MeshBuilder = m[&"matte"]
		soft.ellipsoid(Vector3(0.3, 0.29, 0.28), xf(Vector3(0, 0.22, 0)), Palette.SKIN, 14, 20)
		soft.sphere(0.068, xf(Vector3(0, 0.17, -0.285)), Palette.SKIN.darkened(0.06), 8, 12)
		soft.sphere(0.06, xf(Vector3(-0.29, 0.21, 0.01)), Palette.SKIN.darkened(0.04), 6, 10)
		soft.sphere(0.06, xf(Vector3(0.29, 0.21, 0.01)), Palette.SKIN.darkened(0.04), 6, 10)
		# Short scruffy chin beard.
		matte.ellipsoid(Vector3(0.16, 0.09, 0.1), xf(Vector3(0, 0.045, -0.18), Vector3(18, 0, 0)), Palette.BEARD, 8, 12)
		# Hair under the hat and a ribboned ponytail (reads from behind).
		matte.ellipsoid(Vector3(0.285, 0.21, 0.24), xf(Vector3(0, 0.27, 0.06)), Palette.BEARD, 10, 14)
		matte.ellipsoid(Vector3(0.05, 0.09, 0.05), xf(Vector3(0, 0.1, 0.29), Vector3(-55, 0, 0)), Palette.BEARD, 6, 10)
		matte.torus(0.022, 0.05, xf(Vector3(0, 0.15, 0.26), Vector3(-55, 0, 0)), Palette.COAT, 10, 6)
	)
	eye_l = _pivot(head, "EyeL", Vector3(-0.1, 0.23, -0.245))
	eye_r = _pivot(head, "EyeR", Vector3(0.1, 0.23, -0.245))
	for e: Node3D in [eye_l, eye_r]:
		var side := signf(e.position.x)
		e.rotation_degrees = Vector3(0, -side * 16.0, 0)
		_part(e, "White", func(m: Dictionary) -> void:
			(m[&"glossy"] as MeshBuilder).ellipsoid(Vector3(0.072, 0.092, 0.045), xf(Vector3.ZERO), Palette.EYE_WHITE, 8, 12)
		)
		var pupil := _pivot(e, "Pupil", Vector3(0, -0.005, -0.03))
		_part(pupil, "PupilMesh", func(m: Dictionary) -> void:
			(m[&"glossy"] as MeshBuilder).ellipsoid(Vector3(0.036, 0.05, 0.022), xf(Vector3.ZERO), Palette.PUPIL, 6, 10)
			(m[&"glossy"] as MeshBuilder).sphere(0.011, xf(Vector3(0.012, 0.018, -0.016)), Color.WHITE, 4, 6)
		)
		if side < 0.0:
			pupil_l = pupil
		else:
			pupil_r = pupil
	brow_l = _pivot(head, "BrowL", Vector3(-0.105, 0.34, -0.24))
	brow_r = _pivot(head, "BrowR", Vector3(0.105, 0.34, -0.24))
	for b: Node3D in [brow_l, brow_r]:
		_part(b, "BrowMesh", func(m: Dictionary) -> void:
			(m[&"matte"] as MeshBuilder).rounded_box(Vector3(0.13, 0.042, 0.045), 0.016, xf(Vector3.ZERO), Palette.BROW, 1)
		)
	mouth = _pivot(head, "Mouth", Vector3(0, 0.095, -0.255))
	_part(mouth, "MouthMesh", func(m: Dictionary) -> void:
		(m[&"matte"] as MeshBuilder).ellipsoid(Vector3(0.065, 0.026, 0.03), xf(Vector3.ZERO), Color("6e2b2b"), 6, 10)
	)


func _build_hat() -> void:
	_part(hat, "HatMesh", func(m: Dictionary) -> void:
		var matte: MeshBuilder = m[&"matte"]
		var metal: MeshBuilder = m[&"metal"]
		# Tricorne: brim cocked up between three corners (front + back sides).
		var top := _tricorne_rows(0.0)
		var bottom := _tricorne_rows(-0.035)
		matte.grid(top, Palette.HAT, func(_p: Vector3) -> Vector3: return Vector3.UP, true)
		matte.grid(bottom, Palette.HAT.darkened(0.25), func(_p: Vector3) -> Vector3: return Vector3.DOWN, true)
		var rim := [top[top.size() - 1], bottom[bottom.size() - 1]]
		matte.grid(rim, Palette.HAT, func(p: Vector3) -> Vector3: return Vector3(p.x, 0.0, p.z), true)
		var trim: PackedVector3Array = (top[top.size() - 1] as PackedVector3Array).duplicate()
		trim.append(trim[0])
		matte.tube(trim, PackedFloat32Array([0.017]), Palette.HAT_BAND, 6, false)
		# Crown, band and a brass cockade badge.
		matte.ellipsoid(Vector3(0.235, 0.2, 0.225), xf(Vector3(0, 0.07, 0.0)), Palette.HAT, 10, 16)
		matte.cylinder(0.238, 0.245, 0.055, xf(Vector3(0, 0.02, 0.0)), Palette.HAT_BAND, 18)
		metal.torus(0.022, 0.05, xf(Vector3(0, 0.1, -0.215), Vector3(80, 0, 0)), Palette.BRASS, 12, 6)
		metal.sphere(0.03, xf(Vector3(0, 0.1, -0.225)), Palette.BRASS, 6, 8)
	)


## Rows of the tricorne brim surface (radial rings from crown to rim).
static func _tricorne_rows(offset: float) -> Array:
	const FRONT := -PI * 0.5
	var rows := []
	var rings := 7
	var segments := 54
	for j in rings + 1:
		var t := float(j) / rings
		var row := PackedVector3Array()
		for i in segments:
			var th := TAU * float(i) / segments
			var corner := 0.5 + 0.5 * cos(3.0 * (th - FRONT))
			var radius := lerpf(0.41, 0.53, pow(corner, 3.0))
			var r := lerpf(0.2, radius, t)
			var up := lerpf(0.27, 0.02, pow(corner, 0.6))
			row.append(Vector3(cos(th) * r, up * pow(t, 1.8) + offset, sin(th) * r))
		rows.append(row)
	return rows


func _build_tails() -> void:
	_part(tails, "TailsMesh", func(m: Dictionary) -> void:
		var matte: MeshBuilder = m[&"matte"]
		matte.rounded_box(Vector3(0.15, 0.3, 0.035), 0.015, xf(Vector3(-0.085, -0.17, 0.03), Vector3(8, 0, -6)), Palette.COAT, 2)
		matte.rounded_box(Vector3(0.15, 0.3, 0.035), 0.015, xf(Vector3(0.085, -0.17, 0.03), Vector3(8, 0, 6)), Palette.COAT, 2)
		matte.box(Vector3(0.15, 0.03, 0.04), xf(Vector3(-0.085, -0.31, 0.04), Vector3(8, 0, -6)), Palette.COAT_TRIM)
		matte.box(Vector3(0.15, 0.03, 0.04), xf(Vector3(0.085, -0.31, 0.04), Vector3(8, 0, 6)), Palette.COAT_TRIM)
	)


func _build_arm(shoulder: Node3D, elbow: Node3D, side: float) -> void:
	_part(shoulder, "UpperArm", func(m: Dictionary) -> void:
		var matte: MeshBuilder = m[&"matte"]
		matte.sphere(0.076, xf(Vector3(0, 0, 0)), Palette.COAT, 8, 12)
		matte.cylinder(0.068, 0.075, 0.22, xf(Vector3(0, -0.11, 0)), Palette.COAT, 12)
	)
	_part(elbow, "Forearm", func(m: Dictionary) -> void:
		var matte: MeshBuilder = m[&"matte"]
		matte.sphere(0.07, xf(Vector3(0, 0, 0)), Palette.COAT, 8, 10)
		matte.cylinder(0.082, 0.066, 0.17, xf(Vector3(0, -0.095, 0)), Palette.COAT, 12)
		matte.cylinder(0.09, 0.088, 0.05, xf(Vector3(0, -0.175, 0)), Palette.SHIRT, 12)
	)


func _build_glove() -> void:
	var hand := _pivot(elbow_l, "HandL", Vector3(0, -0.22, 0))
	_part(hand, "Glove", func(m: Dictionary) -> void:
		var soft: MeshBuilder = m[&"soft"]
		soft.cylinder(0.082, 0.072, 0.075, xf(Vector3(0, 0.0, 0)), Palette.GLOVE, 12)
		soft.ellipsoid(Vector3(0.115, 0.12, 0.095), xf(Vector3(0, -0.095, 0)), Palette.GLOVE, 10, 14)
		soft.ellipsoid(Vector3(0.048, 0.068, 0.045), xf(Vector3(0.085, -0.06, -0.045), Vector3(0, 0, 30)), Palette.GLOVE, 6, 8)
	)


func _build_hook() -> void:
	hook_mesh = _part(hook_socket, "Hook", func(m: Dictionary) -> void:
		var metal: MeshBuilder = m[&"metal"]
		# Brass cuff, steel shank and a big J curve opening forward.
		metal.cylinder(0.085, 0.075, 0.09, xf(Vector3(0, 0.02, 0)), Palette.BRASS, 14)
		metal.torus(0.05, 0.085, xf(Vector3(0, 0.07, 0), Vector3(0, 0, 0)), Palette.BRASS.darkened(0.15), 14, 6)
		var pts := PackedVector3Array()
		pts.append(Vector3(0, -0.02, 0))
		pts.append(Vector3(0, -0.17, 0))
		for k in 15:
			var a := PI * float(k) / 14.0 * 1.12
			pts.append(Vector3(0, -0.17 - sin(a) * 0.125, -(1.0 - cos(a)) * 0.125))
		var radii := PackedFloat32Array()
		for k in pts.size():
			radii.append(lerpf(0.042, 0.017, pow(float(k) / (pts.size() - 1), 1.5)))
		metal.tube(pts, radii, Palette.HOOK_METAL, 10)
	)


func _build_leg(hip: Node3D, knee: Node3D, ankle: Node3D) -> void:
	_part(hip, "Thigh", func(m: Dictionary) -> void:
		(m[&"matte"] as MeshBuilder).cylinder(0.078, 0.07, 0.22, xf(Vector3(0, -0.1, 0)), Palette.PANTS, 12)
	)
	_part(knee, "Shin", func(m: Dictionary) -> void:
		(m[&"matte"] as MeshBuilder).sphere(0.07, xf(Vector3.ZERO), Palette.PANTS, 6, 10)
		(m[&"matte"] as MeshBuilder).cylinder(0.068, 0.065, 0.12, xf(Vector3(0, -0.06, 0)), Palette.PANTS, 10)
	)
	_part(ankle, "Boot", func(m: Dictionary) -> void:
		var matte: MeshBuilder = m[&"matte"]
		# Big rounded boot with a turned-down cuff.
		matte.cylinder(0.13, 0.126, 0.075, xf(Vector3(0, 0.15, 0)), Color("7d4a30"), 14)
		matte.cylinder(0.1, 0.106, 0.16, xf(Vector3(0, 0.05, 0)), Palette.BOOTS, 14)
		matte.ellipsoid(Vector3(0.12, 0.075, 0.195), xf(Vector3(0, -0.035, -0.06)), Palette.BOOTS, 8, 14)
		matte.rounded_box(Vector3(0.2, 0.03, 0.3), 0.012, xf(Vector3(0, -0.095, -0.055)), Color("3b2219"), 1)
	)
