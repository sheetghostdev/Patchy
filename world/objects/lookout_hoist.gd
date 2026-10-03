@tool
class_name LookoutHoist
extends MovingPlatform
## The lookout's hoist (Hat Rock): a wicker basket on ropes from a pulley,
## open on the side facing the rock (local +Z), running between the top of the rock and the brim far below once its
## `gate` is open (the buckle unlatches both). Until then it hangs parked at
## the top. A shortcut back up for anyone who falls.
## The node sits where the basket parks (its floor); `drop` is how far down
## it runs and `pulley` how high above the parked basket the ropes hang from.

@export var drop := 28.0
@export var pulley := 5.0
@export var gate: Gate
@export var basket_size := Vector2(2.6, 2.6)

var _ropes: Array[MeshInstance3D] = []
var _anchor := Vector3.ZERO


func _ready() -> void:
	mode = Mode.PING_PONG
	waypoints = PackedVector3Array([Vector3.ZERO, Vector3.DOWN * drop])
	_build()
	super._ready()
	_anchor = global_position + Vector3.UP * pulley
	if Engine.is_editor_hint():
		return
	active = gate == null or gate.is_open() or (gate.gate_id != &"" and WorldState.is_completed(gate.gate_id))
	if not active and gate != null:
		gate.opened.connect(_start)


func _start() -> void:
	if active:
		return
	# Leave from the top now, whatever the clock says.
	_t = 0.0
	active = true
	AudioManager.play(&"rope_creak", global_position)


func _build() -> void:
	var w := basket_size
	var mb := MeshBuilder.new()
	var wicker := Color("c99a5b")
	mb.box(Vector3(w.x, 0.2, w.y), Transform3D(Basis.IDENTITY, Vector3(0, -0.1, 0)), wicker.darkened(0.25))
	mb.box(Vector3(w.x, 0.7, 0.12), Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -w.y * 0.5 + 0.06)), wicker)
	mb.box(Vector3(w.x + 0.06, 0.1, 0.16), Transform3D(Basis.IDENTITY, Vector3(0, 0.52, -w.y * 0.5 + 0.06)), wicker.darkened(0.15))
	for side: float in [-1.0, 1.0]:
		mb.box(Vector3(0.12, 0.7, w.y), Transform3D(Basis.IDENTITY, Vector3(side * (w.x * 0.5 - 0.06), 0.15, 0)), wicker)
		mb.box(Vector3(0.16, 0.1, w.y + 0.06), Transform3D(Basis.IDENTITY, Vector3(side * (w.x * 0.5 - 0.06), 0.52, 0)), wicker.darkened(0.15))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	# Collision: the floor, and a low rim on three sides; the open side
	# (local +Z) faces the rock, to step in and out.
	for shape: Array in [[Vector3(w.x, 0.2, w.y), Vector3(0, -0.1, 0)], [Vector3(w.x, 0.7, 0.12), Vector3(0, 0.15, -w.y * 0.5 + 0.06)],
			[Vector3(0.12, 0.7, w.y), Vector3(w.x * 0.5 - 0.06, 0.15, 0)], [Vector3(0.12, 0.7, w.y), Vector3(-w.x * 0.5 + 0.06, 0.15, 0)]]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = shape[0]
		cs.shape = box
		cs.position = shape[1]
		add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	var rope_mat := MaterialLibrary.toon(Color(0.72, 0.55, 0.34), &"matte")
	for k in 4:
		var rope := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.04
		cyl.bottom_radius = 0.04
		cyl.height = 1.0
		cyl.radial_segments = 5
		cyl.rings = 1
		rope.mesh = cyl
		rope.material_override = rope_mat
		rope.top_level = true
		rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(rope, false, Node.INTERNAL_MODE_FRONT)
		_ropes.append(rope)


## Parked at the top (where it started).
func is_at_top() -> bool:
	return global_position.distance_to(_origin.origin) < 0.05


func is_at_bottom() -> bool:
	return global_position.distance_to(_origin.origin + Vector3.DOWN * drop) < 0.05


func _process(_delta: float) -> void:
	if _ropes.is_empty():
		return
	var anchor := _anchor if not Engine.is_editor_hint() else global_position + Vector3.UP * pulley
	var w := basket_size * 0.5 - Vector2(0.06, 0.06)
	var k := 0
	for c: Vector2 in [Vector2(-w.x, -w.y), Vector2(w.x, -w.y), Vector2(w.x, w.y), Vector2(-w.x, w.y)]:
		var a := global_transform * Vector3(c.x, 0.55, c.y)
		var d := anchor - a
		var length := d.length()
		var y := d / maxf(length, 0.001)
		var x := y.cross(Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD).normalized()
		_ropes[k].global_transform = Transform3D(Basis(x, y * length, x.cross(y)), (a + anchor) * 0.5)
		k += 1
