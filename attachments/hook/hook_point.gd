@tool
class_name HookPoint
extends Area3D
## An authored hook anchor (ring, beam hook, chain loop). Valid points are
## advertised clearly (spec §55: prefer authored targets): a bright ring
## that gently pulses when Patchy is in range.

signal hooked(player: Node3D)
signal released(player: Node3D)

enum Kind { RING, BEAM, CHAIN }

@export var kind := Kind.RING:
	set(v):
		kind = v
		_rebuild()
@export var enabled := true
## Too far or too heavy for the hook: only the grapple can reach it. Drawn
## as a dark iron ring.
@export var grapple_only := false:
	set(v):
		grapple_only = v
		_rebuild()
## What a grapple zip does on arrival: swing from it, or hop up past it
## (for rings mounted just above a ledge).
@export_enum("swing", "hop") var grapple_arrival := "swing"
## Draw a hanging rope/chain up to this height above the anchor (0 = none).
@export_range(0.0, 20.0, 0.1) var hang_length := 1.2:
	set(v):
		hang_length = v
		_rebuild()

var _visual: Node3D
var _ring_mat: StandardMaterial3D
var _highlight := 0.0


func _ready() -> void:
	collision_layer = Layers.GRAPPLE_POINT
	collision_mask = 0
	monitorable = true
	monitoring = false
	add_to_group(&"hook_point")
	if get_child_count() == 0 or not has_node("Shape"):
		var cs := CollisionShape3D.new()
		cs.name = "Shape"
		var sph := SphereShape3D.new()
		sph.radius = 0.45
		cs.shape = sph
		add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_rebuild()


func get_anchor_position() -> Vector3:
	return global_position


func can_attach(_player: Node3D) -> bool:
	return enabled and not grapple_only


func can_grapple() -> bool:
	return enabled


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _ring_mat == null:
		return
	var p := GameManager.player
	var near := false
	if p != null:
		var reach := 5.5
		if InventoryManager.equipped_attachment == &"grapple":
			reach = GrappleAttachment.RANGE
		near = enabled and p.global_position.distance_to(global_position) < reach
	_highlight = move_toward(_highlight, 1.0 if near else 0.0, delta * 4.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.008)
	_ring_mat.emission_energy_multiplier = 0.25 + _highlight * (0.6 + 0.6 * pulse)


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.albedo_color = Color(1.0, 0.78, 0.25) if not grapple_only else Color(0.5, 0.56, 0.66)
	_ring_mat.metallic = 0.6
	_ring_mat.roughness = 0.35
	_ring_mat.emission_enabled = true
	_ring_mat.emission = Color(1.0, 0.7, 0.2) if not grapple_only else Color(0.45, 0.75, 1.0)
	_ring_mat.emission_energy_multiplier = 0.25
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.26
	torus.outer_radius = 0.38
	torus.rings = 24
	torus.ring_segments = 10
	ring.mesh = torus
	ring.material_override = _ring_mat
	match kind:
		Kind.RING:
			ring.rotation = Vector3(PI * 0.5, 0.0, 0.0)
		Kind.BEAM:
			ring.rotation = Vector3(PI * 0.5, 0.0, PI * 0.5)
		Kind.CHAIN:
			ring.scale = Vector3.ONE * 0.8
	_visual.add_child(ring)
	if hang_length > 0.01:
		var rope := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.045
		cyl.bottom_radius = 0.045
		cyl.height = hang_length
		cyl.radial_segments = 6
		rope.mesh = cyl
		var rope_mat := StandardMaterial3D.new()
		rope_mat.albedo_color = Color(0.62, 0.45, 0.27)
		rope.material_override = rope_mat
		rope.position = Vector3(0.0, 0.38 + hang_length * 0.5, 0.0)
		_visual.add_child(rope)
