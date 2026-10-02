@tool
class_name KelpBed
extends Node3D
## A stand of kelp swaying in the swell (spec §114): tall ribbon fronds
## with little leaf blades, rooted on the seabed, moved by the foliage
## shader's slow "kelp" profile. Decoration only. Deterministic by `seed`.

@export var seed := 1:
	set(v):
		seed = v
		_build()
@export_range(1, 40) var count := 9:
	set(v):
		count = v
		_build()
@export_range(0.5, 10.0, 0.1) var radius := 2.2:
	set(v):
		radius = v
		_build()
@export_range(1.0, 12.0, 0.1) var height := 5.0:
	set(v):
		height = v
		_build()

const BASE := Color("4f7a2f")
const TIP := Color("9ccc54")

var _mesh: MeshInstance3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _mesh != null:
		_mesh.free()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 4421 + 7
	var pb := PropBuilder.new()
	for i in count:
		var a := rng.randf() * TAU
		var root := Vector3(cos(a), 0, sin(a)) * sqrt(rng.randf()) * radius
		var h := height * rng.randf_range(0.6, 1.1)
		var phase := rng.randf()
		var yaw := rng.randf() * TAU
		var side := Vector3(cos(yaw), 0, sin(yaw))
		var n := 10
		var w := 0.16
		var prev_l := -1
		var prev_r := -1
		for k in n + 1:
			var t := float(k) / n
			var p := root + Vector3(sin(t * 5.0 + phase * 6.0) * 0.18, t * h, cos(t * 4.0 + phase * 4.0) * 0.12)
			var col := BASE.lerp(TIP, t)
			var half := side * w * (1.0 - 0.6 * t) * 0.5
			var nrm := side.cross(Vector3.UP).normalized()
			var l := pb.vert(p - half, nrm, col, Vector2(phase, t))
			var r := pb.vert(p + half, nrm, col, Vector2(phase, t))
			if prev_l >= 0:
				pb.quad(prev_l, prev_r, r, l, nrm)
			prev_l = l
			prev_r = r
			# Leaf blades every other segment, alternating sides.
			if k > 0 and k < n and k % 2 == 0:
				var out := side * (1.0 if k % 4 == 0 else -1.0)
				var b0 := pb.vert(p, nrm, col, Vector2(phase, t))
				var b1 := pb.vert(p + out * 0.38 + Vector3.UP * 0.1, nrm, col.lightened(0.1), Vector2(phase, minf(t + 0.05, 1.0)))
				var b2 := pb.vert(p + Vector3.UP * 0.32, nrm, col, Vector2(phase, minf(t + 0.06, 1.0)))
				pb.tri(b0, b1, b2, nrm)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = pb.build(null, PropKit.foliage_material(&"kelp"))
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
