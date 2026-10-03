@tool
class_name ReefGull
extends Node3D
## A seagull loafing on a rock (Bell Atoll): it bobs and looks about, and
## when someone plays a wrong note it throws its head back and laughs,
## flapping. Purely for show (and the laugh).

const WHITE := Color("f6f4ee")
const GREY := Color("9aa3ad")
const BEAK := Color("f2b632")

var _body: Node3D
var _head: Node3D
var _wings: Array[Node3D] = []
var _t := 0.0
var _laugh := 0.0
var _phase := 0.0


func _ready() -> void:
	_phase = fposmod(global_position.x * 0.37 + global_position.z * 0.11, TAU) if is_inside_tree() else 0.0
	_body = Node3D.new()
	add_child(_body, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	mb.sphere(0.22, Transform3D(Basis.from_scale(Vector3(0.85, 0.8, 1.35)), Vector3(0, 0.32, 0)), WHITE, 6, 10)
	mb.cylinder(0.03, 0.03, 0.22, Transform3D(Basis.IDENTITY, Vector3(-0.07, 0.11, 0.02)), BEAK.darkened(0.2), 4)
	mb.cylinder(0.03, 0.03, 0.22, Transform3D(Basis.IDENTITY, Vector3(0.07, 0.11, 0.02)), BEAK.darkened(0.2), 4)
	mb.box(Vector3(0.18, 0.04, 0.22), Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, 0.34, 0.33)), GREY.darkened(0.2))
	var bm := MeshInstance3D.new()
	bm.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_body.add_child(bm)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.48, -0.2)
	_body.add_child(_head)
	var hb := MeshBuilder.new()
	hb.sphere(0.12, Transform3D.IDENTITY, WHITE, 6, 8)
	hb.cylinder(0.0, 0.045, 0.16, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, -0.02, -0.17)), BEAK, 5)
	for side: float in [-1.0, 1.0]:
		hb.sphere(0.022, Transform3D(Basis.IDENTITY, Vector3(side * 0.08, 0.03, -0.07)), Color("1d1b22"), 3, 4)
	var hm := MeshInstance3D.new()
	hm.mesh = hb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_head.add_child(hm)
	for side: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(side * 0.16, 0.38, 0.0)
		_body.add_child(w)
		var wb := MeshBuilder.new()
		wb.triangle(Vector3.ZERO, Vector3(side * 0.05, 0, 0.4), Vector3(side * 0.42, -0.02, 0.18), GREY, true)
		wb.triangle(Vector3(side * 0.42, -0.02, 0.18), Vector3(side * 0.05, 0, 0.4), Vector3(side * 0.36, -0.03, 0.42), Color("2b2a30"), true)
		var wm := MeshInstance3D.new()
		wm.mesh = wb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		w.add_child(wm)
		_wings.append(w)


func laugh() -> void:
	_laugh = 1.6 + randf() * 0.3


func is_laughing() -> bool:
	return _laugh > 0.0


func _process(delta: float) -> void:
	if _body == null:
		return
	_t += delta
	if _laugh > 0.0:
		_laugh -= delta
		# Head back, beak to the sky, cackling; wings flapping, hopping.
		var k := sin(_t * 26.0)
		_head.rotation = Vector3(0.7 + k * 0.25, 0, 0)
		_body.position.y = absf(sin(_t * 9.0)) * 0.12
		for i in _wings.size():
			_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * (-0.6 + sin(_t * 20.0) * 0.7)
		return
	# Loafing: a slow bob and a look round now and then.
	_body.position.y = 0.0
	_head.rotation = Vector3(sin(_t * 1.1 + _phase) * 0.12, sin(_t * 0.37 + _phase) * 0.9, 0)
	for i in _wings.size():
		_wings[i].rotation.z = 0.0
