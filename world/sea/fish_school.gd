class_name FishSchool
extends Node3D
## A school of little reef fish (spec §114: "keep areas dense"): they mill
## about in loose rings around their spot and dart away from Patchy when he
## swims into them, then drift back. One MultiMesh, no collision.

@export_range(1, 64) var count := 14
@export_range(0.5, 12.0, 0.1) var radius := 2.6
@export_range(0.0, 4.0, 0.05) var spread_height := 1.2
@export_range(0.1, 3.0, 0.05) var speed := 0.7
@export var body_color := Color("ffd23f")
@export var stripe_color := Color("2f8fe8")

var _mm: MultiMesh
var _fish: Array[Dictionary] = []
var _flee := Vector3.ZERO
var _t := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 13.0 + global_position.z * 7.0)
	for i in count:
		_fish.append({"r": radius * rng.randf_range(0.45, 1.0), "h": rng.randf_range(-spread_height, spread_height) * 0.5,
			"ph": rng.randf() * TAU, "w": speed * rng.randf_range(0.8, 1.2) * (1.0 if rng.randf() < 0.85 else -1.0)})
	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.mesh = _fish_mesh()
	_mm.instance_count = count
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_update(0.0)


func _process(delta: float) -> void:
	_t += delta
	_update(delta)


func _update(delta: float) -> void:
	# Scatter away from Patchy, then drift home.
	var p := GameManager.player as Node3D
	var want := Vector3.ZERO
	if p != null:
		var away := global_position + _flee - p.global_position
		if away.length() < radius + 1.5:
			want = away.normalized() * (radius + 2.5)
	_flee = _flee.lerp(want, 1.0 - exp(-delta * (3.0 if want != Vector3.ZERO else 0.6)))
	for i in _fish.size():
		var f := _fish[i]
		var a: float = _t * float(f["w"]) + float(f["ph"])
		var r: float = f["r"]
		var local := Vector3(cos(a) * r, float(f["h"]) + sin(_t * 0.9 + float(f["ph"])) * 0.25, sin(a) * r * 0.75) + _flee
		var vel := Vector3(-sin(a) * r, 0, cos(a) * r * 0.75) * float(f["w"])
		var basis := Basis.looking_at(vel.normalized() if vel.length() > 0.001 else Vector3.FORWARD, Vector3.UP)
		basis = basis * Basis.from_euler(Vector3(0, sin(_t * 9.0 + float(f["ph"])) * 0.18, 0))
		_mm.set_instance_transform(i, Transform3D(basis, local))


## A plump little fish facing -Z: body, stripe, tail and fins.
func _fish_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	mb.ellipsoid(Vector3(0.07, 0.11, 0.16), Transform3D.IDENTITY, body_color, 6, 10)
	mb.ellipsoid(Vector3(0.072, 0.1, 0.035), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.02)), stripe_color, 5, 8)
	mb.triangle(Vector3(0, 0, 0.12), Vector3(0, 0.1, 0.27), Vector3(0, -0.1, 0.27), stripe_color, true)
	mb.triangle(Vector3(0, 0.1, -0.02), Vector3(0, 0.17, 0.08), Vector3(0, 0.08, 0.1), body_color.darkened(0.15), true)
	for side: float in [-1.0, 1.0]:
		mb.sphere(0.022, Transform3D(Basis.IDENTITY, Vector3(side * 0.05, 0.03, -0.1)), Color.WHITE, 3, 5)
		mb.sphere(0.012, Transform3D(Basis.IDENTITY, Vector3(side * 0.06, 0.03, -0.115)), Palette.PUPIL, 3, 4)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
