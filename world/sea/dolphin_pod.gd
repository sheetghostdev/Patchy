class_name DolphinPod
extends Node3D
## A pod of dolphins in the strait (spec §117, "sea creatures"). They laze
## around their patch of sea with the odd leap; when Patchy sails by they
## race alongside the boat, taking turns to leap clear of the water with a
## splash. They never get in the way: no collision, purely for joy.

@export_range(1, 6) var count := 3
## How far from the pod a passing boat is noticed.
@export_range(5.0, 80.0, 0.5) var escort_range := 28.0
## How far from home they will follow before turning back.
@export_range(10.0, 200.0, 1.0) var leash := 70.0
@export_range(2.0, 30.0, 0.5) var roam_radius := 8.0

const DEPTH := 0.55
const BACK := Color("5d8fb8")
const BELLY := Color("e3eef5")

var _pod: Array[Dictionary] = []
var _escorting := false
var _side := 1.0
var _t := 0.0


func _ready() -> void:
	for i in count:
		var root := Node3D.new()
		var tail := _build_model(root)
		add_child(root)
		var start := global_position + Vector3(cos(i * 2.1) * roam_radius * 0.5, -DEPTH, sin(i * 2.1) * roam_radius * 0.5)
		_pod.append({"node": root, "tail": tail, "pos": start, "vel": Vector3.ZERO, "leap": -1.0,
			"next": randf_range(1.0, 5.0), "phase": randf() * TAU})


func _physics_process(delta: float) -> void:
	if _pod.is_empty():
		return
	_t += delta
	var boat := _driven_boat()
	var center := _pod_center()
	if boat != null and not _escorting and Player.flat(boat.global_position - center).length() < escort_range \
			and _boat_speed(boat) > 3.0:
		_escorting = true
		var right := boat.global_basis.x
		_side = 1.0 if (center - boat.global_position).dot(right) >= 0.0 else -1.0
	if _escorting and (boat == null or Player.flat(boat.global_position - global_position).length() > leash):
		_escorting = false
	for i in _pod.size():
		_update(_pod[i], i, boat, delta)


func is_escorting() -> bool:
	return _escorting


func _update(d: Dictionary, i: int, boat: Node3D, delta: float) -> void:
	var pos: Vector3 = d["pos"]
	var target: Vector3
	var max_speed := 4.0
	if _escorting and boat != null:
		var fwd := -Player.flat(boat.global_basis.z).normalized()
		var right := Vector3(-fwd.z, 0, fwd.x)
		target = boat.global_position + right * _side * (4.5 + 1.8 * i) + fwd * (3.0 - 2.6 * i)
		max_speed = minf(_boat_speed(boat) + 4.0, 16.0)
	else:
		var a := _t * 0.25 + float(d["phase"])
		target = global_position + Vector3(cos(a) * roam_radius, 0, sin(a) * roam_radius * 0.7)
	var to := Player.flat(target - pos)
	var want := to.normalized() * minf(to.length() * 1.5, max_speed)
	var vel: Vector3 = (d["vel"] as Vector3).lerp(want, 1.0 - exp(-delta * 2.0))
	pos += vel * delta
	var surface := WaterVolume.surface_at(get_world_3d(), pos)
	# Leaps: a clean arc out of the water and back in, splashing both ends.
	var leap: float = d["leap"]
	d["next"] = float(d["next"]) - delta
	if leap < 0.0 and float(d["next"]) <= 0.0 and vel.length() > 1.5:
		leap = 0.0
		d["next"] = randf_range(1.6, 3.0) if _escorting else randf_range(4.0, 8.0)
		_splash(Vector3(pos.x, surface, pos.z), 0.8)
	var y := surface - DEPTH + sin(_t * 1.7 + float(d["phase"])) * 0.05
	var pitch := 0.0
	if leap >= 0.0:
		leap += delta / 1.05
		var h := 1.9 if _escorting else 1.4
		y = surface - DEPTH + sin(leap * PI) * h
		pitch = cos(leap * PI) * 0.9
		if leap >= 1.0:
			leap = -1.0
			_splash(Vector3(pos.x, surface, pos.z), 1.0)
	d["leap"] = leap
	pos.y = y
	d["pos"] = pos
	d["vel"] = vel
	var node: Node3D = d["node"]
	node.global_position = pos
	if vel.length() > 0.2:
		var yaw := atan2(-vel.x, -vel.z)
		node.global_rotation = Vector3(pitch, yaw, sin(_t * 1.3 + i) * 0.08)
	var tail: Node3D = d["tail"]
	tail.rotation.x = sin(_t * (6.0 if _escorting else 3.0) + i) * 0.35


func _splash(at: Vector3, size: float) -> void:
	VFX.splash(get_tree().current_scene, at, size)
	AudioManager.play(&"splash_small", at, -6.0, randf_range(0.9, 1.15))


func _pod_center() -> Vector3:
	var c := Vector3.ZERO
	for d in _pod:
		c += d["pos"]
	return c / _pod.size()


func _driven_boat() -> Node3D:
	for n in get_tree().get_nodes_in_group(&"boat"):
		if n.get(&"driver") != null:
			return n as Node3D
	return null


func _boat_speed(boat: Node3D) -> float:
	var s: Variant = boat.get(&"_speed")
	return absf(float(s)) if s != null else 0.0


## A friendly 1.8 m dolphin facing -Z; returns the tail pivot.
func _build_model(root: Node3D) -> Node3D:
	var mb := MeshBuilder.new()
	mb.ellipsoid(Vector3(0.3, 0.28, 0.8), Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.05)), BACK, 10, 16)
	mb.ellipsoid(Vector3(0.24, 0.18, 0.66), Transform3D(Basis.IDENTITY, Vector3(0, -0.1, -0.12)), BELLY, 8, 14)
	mb.sphere(0.24, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.62)), BACK, 8, 12)
	mb.ellipsoid(Vector3(0.09, 0.07, 0.24), Transform3D(Basis.IDENTITY, Vector3(0, -0.06, -0.92)), BELLY.darkened(0.08), 6, 10)
	mb.ellipsoid(Vector3(0.05, 0.012, 0.012), Transform3D(Basis.from_euler(Vector3(0, 0, 0)), Vector3(0, -0.1, -0.86)), BACK.darkened(0.5), 3, 5)
	for side: float in [-1.0, 1.0]:
		mb.sphere(0.05, Transform3D(Basis.IDENTITY, Vector3(side * 0.17, 0.08, -0.72)), Palette.EYE_WHITE, 5, 7)
		mb.sphere(0.028, Transform3D(Basis.IDENTITY, Vector3(side * 0.19, 0.08, -0.75)), Palette.PUPIL, 4, 5)
		mb.ellipsoid(Vector3(0.22, 0.03, 0.1), Transform3D(Basis.from_euler(Vector3(0, side * 0.5, side * -0.5)), Vector3(side * 0.32, -0.14, -0.3)), BACK.darkened(0.08), 4, 8)
	# Dorsal fin, swept back.
	mb.ellipsoid(Vector3(0.035, 0.26, 0.18), Transform3D(Basis.from_euler(Vector3(0.65, 0, 0)), Vector3(0, 0.38, 0.12)), BACK.darkened(0.1), 4, 8)
	var body := MeshInstance3D.new()
	body.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	root.add_child(body)
	var tail := Node3D.new()
	tail.position = Vector3(0, 0, 0.6)
	root.add_child(tail)
	var tb := MeshBuilder.new()
	tb.ellipsoid(Vector3(0.13, 0.15, 0.36), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.25)), BACK, 6, 10)
	for side: float in [-1.0, 1.0]:
		tb.ellipsoid(Vector3(0.24, 0.025, 0.1), Transform3D(Basis.from_euler(Vector3(0, side * 0.5, 0)), Vector3(side * 0.18, 0, 0.62)), BACK.darkened(0.12), 4, 8)
	var tm := MeshInstance3D.new()
	tm.mesh = tb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	tail.add_child(tm)
	return tail
