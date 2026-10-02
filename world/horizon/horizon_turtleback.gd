@tool
class_name HorizonTurtleback
extends HorizonIsland
## Turtleback on the horizon (spec §109): what looks like a domed jungle
## island is the shell of an enormous sea turtle, fast asleep with its chin
## on the waves. It never moves... except that, watched for long enough,
## the whole island slowly rises and falls with its breathing.

const SHELL := [Color("4f5a2e"), Color("66733a"), Color("3a4222")]
const SCUTE := [Color("9a7440"), Color("c49a58"), Color("6a4e2c")]
const SKIN := [Color("5fa07a"), Color("85c49c"), Color("3f7656")]
const LID := Color("2a3a30")
const SHELL_AT := Vector3(0, -2, 12)
const SHELL_R := Vector3(92, 36, 112)
## One breath, in seconds; how far the shell rises (fraction of its height).
const BREATH := 8.5
const RISE := 0.014

var _head: Node3D
var _t := 0.0


func _build() -> void:
	var rng := PropKit.make_rng(seed, 202)
	var noise := lump_noise(seed + 1)
	# The shell: a low dome on a rim of marginal scutes, with raised plates.
	var shell := lump(SHELL_R, seed + 1, Transform3D(Basis.IDENTITY, SHELL_AT), 0.03, [], 12, 24)
	shell.append(lump(Vector3(101, 7, 122), seed + 2, Transform3D(Basis.IDENTITY, Vector3(0, 2, 12)), 0.03, [], 4, 26))
	paint(shell, SHELL, seed)
	add_part(shell)
	var plates := PropBuilder.new()
	var spots: Array[Vector3] = [Vector3(0, 1, -0.5), Vector3(0, 1, -0.16), Vector3(0, 1, 0.18), Vector3(0, 1, 0.52)]
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.5, -0.05, 0.4]:
			spots.append(Vector3(side * 0.62, 0.62, z))
	for k in spots.size():
		var q := lump_point(spots[k], SHELL_R, noise, 0.03)
		var n := lump_normal(q, SHELL_R)
		var up := Basis.looking_at(-n, Vector3.FORWARD if absf(n.dot(Vector3.UP)) > 0.95 else Vector3.UP)
		var b := up * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, rng.randf_range(-0.2, 0.2))
		plates.append(lump(Vector3(26, 5, 24), seed + 10 + k, Transform3D(b, SHELL_AT + q - n * 1.5), 0.05, [], 4, 6))
	paint(plates, SCUTE, seed + 2)
	add_part(plates)
	# Jungle and palms on top: the "island".
	var jungle := PropBuilder.new()
	for k in 34:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.7, 1.0)
		var r := sqrt(1.0 - y * y)
		var q := lump_point(Vector3(cos(a) * r, y, sin(a) * r), SHELL_R, noise, 0.03)
		canopy(jungle, SHELL_AT + q, rng.randf_range(9.0, 14.0), rng)
	for k in 10:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.6, 0.85)
		var r := sqrt(1.0 - y * y)
		palm(jungle, SHELL_AT + lump_point(Vector3(cos(a) * r, y, sin(a) * r), SHELL_R, noise, 0.03), rng.randf_range(14.0, 20.0), rng)
	jungle.flat_shade()
	shade(jungle, seed + 3)
	add_part(jungle)
	# Flippers and tail, splayed in the water.
	var limbs := PropBuilder.new()
	for side: float in [-1.0, 1.0]:
		limbs.append(lump(Vector3(38, 4, 15), seed + 20 + int(side), Transform3D(Basis(Vector3.UP, side * 0.6) * Basis(Vector3.BACK, side * 0.12), Vector3(side * 88, 0.5, -54)), 0.05))
		limbs.append(lump(Vector3(25, 3.5, 12), seed + 23 + int(side), Transform3D(Basis(Vector3.UP, -side * 0.55), Vector3(side * 70, 0.5, 98)), 0.05))
	limbs.append(lump(Vector3(9, 4, 18), seed + 26, Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 132)), 0.05))
	paint(limbs, SKIN, seed + 4, 0.05, _spots.bind(noise))
	add_part(limbs)
	# The head, chin on the waves, eyes shut tight.
	_head = Node3D.new()
	_head.name = "Head"
	_head.position = Vector3(0, 4, -96)
	_head.rotation.y = 0.22
	get_root().add_child(_head)
	var head := PropBuilder.new()
	head.append(lump(Vector3(19, 12, 22), seed + 30, Transform3D(Basis.IDENTITY, Vector3(0, -1, -6)), 0.04))
	var hr := Vector3(17, 13, 26)
	var hc := Vector3(0, 4, -30)
	var hn := lump_noise(seed + 31)
	head.append(lump(hr, seed + 31, Transform3D(Basis.IDENTITY, hc), 0.04))
	paint(head, SKIN, seed + 5, 0.04, _spots.bind(noise))
	var face := PropBuilder.new()
	# Heavy lids shut over each eye: a skin bulge with a dark, smiling seam.
	for side: float in [-1.0, 1.0]:
		var q := lump_point(Vector3(side * 0.7, 0.42, -0.58), hr, hn, 0.04)
		var n := lump_normal(q, hr)
		var b := Basis.looking_at(-n, Vector3.UP)
		face.ellipsoid(Vector3(6.0, 4.2, 3.4), Transform3D(b, hc + q + n * 0.6), SKIN[1], 4, 8)
		for k in 3:
			var t := (k - 1) * 2.3
			face.ellipsoid(Vector3(1.6, 0.75, 1.0), Transform3D(b, hc + q + n * 3.3 + b.x * t + b.y * (-0.9 + absf(k - 1) * 0.6)), LID, 3, 6)
	var mq := lump_point(Vector3(0, -0.3, -0.95), hr, hn, 0.04)
	face.ellipsoid(Vector3(8, 0.8, 1.6), Transform3D(Basis(Vector3.RIGHT, -0.2), hc + mq + Vector3.FORWARD * 0.6), LID, 3, 10)
	head.append(face)
	add_part(head, &"matte", _head)


## Darker blotches on the turtle's skin.
func _spots(pos: Vector3, _nrm: Vector3, c: Color, noise: FastNoiseLite) -> Color:
	return c.darkened(0.18) if noise.get_noise_2d(pos.x * 0.16, pos.z * 0.16 + pos.y * 0.12) > 0.25 else c


func _process(delta: float) -> void:
	_t += delta
	# A slow breath: the shell swells and settles, the head nods along.
	var b := sin(_t * TAU / BREATH)
	get_root().scale.y = 1.0 + b * RISE
	if _head != null:
		_head.rotation.x = b * 0.015
