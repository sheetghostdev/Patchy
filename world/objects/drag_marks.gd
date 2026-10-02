@tool
class_name DragMarks
extends Node3D
## Where the crabs dragged something heavy (spec §103: "follow the drag
## marks"): two scraped grooves with little berms of pushed-up sand, and
## the scuttling footprints of the haulers on either side. `points` are
## local and should sit on the ground (the builder places them).

@export var points: PackedVector3Array = PackedVector3Array():
	set(v):
		points = v
		_build()
## Distance between the two grooves (the boat's keel and bilge).
@export_range(0.2, 3.0, 0.05) var gap := 0.9
@export var groove_color := Color("c4a066")
@export var berm_color := Color("fbecc0")
@export var footprints := true
@export var seed := 1

var _mesh: MeshInstance3D


func _ready() -> void:
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _mesh != null:
		_mesh.free()
		_mesh = null
	if points.size() < 2:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var path := _resample(0.5)
	var mb := MeshBuilder.new()
	var wobble := 0.0
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var dir := (b - a)
		if dir.length() < 0.01:
			continue
		var side := Vector3(-dir.z, 0, dir.x).normalized()
		var next_wobble := clampf(wobble + rng.randf_range(-0.04, 0.04), -0.12, 0.12)
		for s: float in [-0.5, 0.5]:
			var o0 := side * (s * gap + wobble)
			var o1 := side * (s * gap + next_wobble)
			_strip(mb, a + o0, b + o1, 0.15, 0.012, groove_color)
			for berm: float in [-0.11, 0.11]:
				_strip(mb, a + o0 + side * berm, b + o1 + side * berm, 0.06, 0.03, berm_color)
		wobble = next_wobble
		if footprints and i % 2 == 0:
			for s: float in [-1.0, 1.0]:
				var at := a.lerp(b, rng.randf()) + side * s * (gap * 0.5 + rng.randf_range(0.35, 0.6))
				for k in 3:
					var p := at + dir.normalized() * (k - 1) * 0.07 + side * s * (k % 2) * 0.05
					mb.ellipsoid(Vector3(0.035, 0.008, 0.05), Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP), p + Vector3.UP * 0.01), groove_color.darkened(0.12), 3, 5)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)


func _strip(mb: MeshBuilder, a: Vector3, b: Vector3, width: float, height: float, color: Color) -> void:
	var d := b - a
	mb.box(Vector3(width, height, d.length() + 0.04), Transform3D(Basis.looking_at(d.normalized(), Vector3.UP), (a + b) * 0.5 + Vector3.UP * height * 0.5), color)


## The path re-sampled every `step` meters.
func _resample(step: float) -> PackedVector3Array:
	var out := PackedVector3Array([points[0]])
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var n := maxi(int(ceil(a.distance_to(b) / step)), 1)
		for k in n:
			out.append(a.lerp(b, float(k + 1) / n))
	return out
