@tool
class_name CoralCluster
extends Node3D
## A clump of reef life for the seabed (spec §114): a rock crowded with
## branching coral, a brain coral, a sea fan and tube sponges in bright,
## friendly colors, with sea stars and shells scattered around its foot.
## Decoration only (no collision). Deterministic by `seed`.

@export var seed := 1:
	set(v):
		seed = v
		_build()
@export_range(0.4, 3.0, 0.05) var size := 1.0:
	set(v):
		size = v
		_build()

const COLORS := [Color("ff7a8a"), Color("ff9f43"), Color("a66cff"), Color("ffd23f"), Color("3ddc97"), Color("4fc3ff"), Color("ff5fa2")]
const ROCK := Color("7d7466")

var _mesh: MeshInstance3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _mesh != null:
		_mesh.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var mb := MeshBuilder.new()
	var s := size
	mb.ellipsoid(Vector3(0.95, 0.38, 0.85) * s, Transform3D(Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)), Vector3(0, 0.08 * s, 0)), ROCK, 6, 10)
	mb.ellipsoid(Vector3(0.5, 0.3, 0.45) * s, Transform3D(Basis.IDENTITY, Vector3(0.5 * s, 0.1 * s, -0.4 * s)), ROCK.darkened(0.1), 5, 8)
	var top := Vector3(0, 0.38 * s, 0)
	for k in rng.randi_range(2, 3):
		var a := rng.randf() * TAU
		var base := top + Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.45) * s
		_branch(mb, rng, base, Vector3(rng.randf_range(-0.3, 0.3), 1, rng.randf_range(-0.3, 0.3)).normalized(), 0.55 * s, 0.07 * s, _pick(rng), 0)
	# Brain coral: a dome ringed with grooves.
	var bc := top + Vector3(rng.randf_range(-0.5, 0.5), -0.05, rng.randf_range(-0.5, 0.5)) * s
	var bcol: Color = _pick(rng)
	mb.ellipsoid(Vector3(0.34, 0.24, 0.34) * s, Transform3D(Basis.IDENTITY, bc), bcol, 8, 12)
	for k in 3:
		var r := (0.3 - k * 0.08) * s
		mb.torus(r - 0.025 * s, r + 0.01 * s, Transform3D(Basis.IDENTITY, bc + Vector3(0, (0.09 + k * 0.07) * s, 0)), bcol.darkened(0.25), 16, 4)
	# A sea fan standing edge-on to the current.
	var fan := top + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4)) * s
	var fyaw := rng.randf() * TAU
	var fcol: Color = _pick(rng)
	mb.ellipsoid(Vector3(0.5, 0.45, 0.025) * s, Transform3D(Basis.from_euler(Vector3(0, fyaw, 0)), fan + Vector3(0, 0.45, 0) * s), fcol, 6, 12)
	for k in 5:
		var ang := -0.9 + k * 0.45
		var b := Basis.from_euler(Vector3(0, fyaw, ang))
		mb.cylinder(0.012 * s, 0.018 * s, 0.85 * s, Transform3D(b, fan + b * Vector3(0, 0.42 * s, 0)), fcol.darkened(0.3), 4)
	# Tube sponges, open at the top.
	var tc: Color = _pick(rng)
	var tubes := top + Vector3(rng.randf_range(-0.5, 0.5), -0.05, rng.randf_range(-0.5, 0.5)) * s
	for k in rng.randi_range(3, 5):
		var off := Vector3(rng.randf_range(-0.22, 0.22), 0, rng.randf_range(-0.22, 0.22)) * s
		var h := rng.randf_range(0.25, 0.6) * s
		var r := rng.randf_range(0.05, 0.08) * s
		mb.cylinder(r, r * 1.15, h, Transform3D(Basis.IDENTITY, tubes + off + Vector3(0, h * 0.5, 0)), tc, 8)
		mb.cylinder(r * 0.7, r * 0.7, 0.02, Transform3D(Basis.IDENTITY, tubes + off + Vector3(0, h + 0.005, 0)), tc.darkened(0.55), 8)
	# Sea stars and scallop shells on the sand around it.
	for k in rng.randi_range(2, 4):
		var a := rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * rng.randf_range(1.0, 1.6) * s
		if rng.randf() < 0.6:
			var star: Color = [Color("ff7043"), Color("ffb74d"), Color("e84a5f")][rng.randi() % 3]
			var yaw := rng.randf() * TAU
			for arm in 5:
				var aa := yaw + TAU * arm / 5.0
				mb.ellipsoid(Vector3(0.05, 0.025, 0.14) * s, Transform3D(Basis.from_euler(Vector3(0, aa, 0)), p + Vector3(sin(aa), 0.02, cos(aa)) * 0.11 * s), star, 4, 6)
		else:
			var yaw2 := rng.randf() * TAU
			mb.ellipsoid(Vector3(0.12, 0.04, 0.1) * s, Transform3D(Basis.from_euler(Vector3(0.2, yaw2, 0)), p + Vector3(0, 0.03, 0)), Color("fbe3d0"), 4, 8)
			for rib in 4:
				mb.box(Vector3(0.012, 0.012, 0.18) * s, Transform3D(Basis.from_euler(Vector3(0.2, yaw2 + (rib - 1.5) * 0.3, 0)), p + Vector3(0, 0.06, 0) * s), Color("e8b89a"))
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)


func _pick(rng: RandomNumberGenerator) -> Color:
	return COLORS[rng.randi() % COLORS.size()]


## Branching coral: a tube that forks twice, each tip rounded off.
func _branch(mb: MeshBuilder, rng: RandomNumberGenerator, from: Vector3, dir: Vector3, length: float, radius: float, color: Color, depth: int) -> void:
	var to := from + dir * length
	mb.tube(PackedVector3Array([from, from.lerp(to, 0.5) + Vector3(rng.randf_range(-0.03, 0.03), 0, rng.randf_range(-0.03, 0.03)), to]),
		PackedFloat32Array([radius, radius * 0.9, radius * 0.8]), color, 6, false)
	if depth >= 2:
		mb.sphere(radius * 1.1, Transform3D(Basis.IDENTITY, to), color.lightened(0.15), 4, 6)
		return
	for k in rng.randi_range(2, 3):
		var nd := (dir + Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.0, 0.4), rng.randf_range(-0.7, 0.7))).normalized()
		_branch(mb, rng, to, nd, length * 0.7, radius * 0.72, color, depth + 1)
