@tool
class_name Bell
extends PropBody
## Brass ship's bell hanging in a small wooden frame with a little gable
## roof. Hit it (any take_hit: swipe, dive, cannon...) and it swings as a
## damped pendulum, plays AudioManager `ring_sound` and emits `rung`. The
## frame is solid (Layers.WORLD); a small Area3D around the bell sits on
## Layers.PROPS so Patchy's attack hitboxes find it.

signal rung(strength: float)

@export_range(0.5, 3.0, 0.01) var size := 1.0:
	set(v):
		size = v
		_queue_rebuild()
@export var ring_sound: StringName = &"bell_ring"
## Swing response (rad/s per hit).
@export_range(0.5, 10.0, 0.1) var hit_impulse := 3.2

## Pivot the bell hangs from (rotation.x is the swing angle).
var bell_pivot: Node3D
var _vel := 0.0
var _cooldown := 0.0


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var s := size
	var parts := PropParts.new()
	var mt := parts.matte
	var wood := PropPalette.WOOD_FRAME
	var top := 2.05 * s
	for sx: float in [-1.0, 1.0]:
		mt.chamfer_box(Vector3(0.16, top + 0.1, 0.16) * Vector3(s, 1.0, s), 0.03 * s, Transform3D(Basis.IDENTITY, Vector3(sx * 0.55 * s, (top + 0.1) * 0.5 - 0.1, 0)), wood)
		mt.chamfer_box(Vector3(0.34, 0.12, 0.5) * s, 0.03 * s, Transform3D(Basis.IDENTITY, Vector3(sx * 0.55 * s, 0.05 * s, 0)), wood.darkened(0.12))
		for sz: float in [-1.0, 1.0]:
			mt.beam(Vector3(sx * 0.55 * s, 0.62 * s, 0.0), Vector3(sx * 0.55 * s, 0.1 * s, sz * 0.24 * s), 0.07 * s, 0.07 * s, 0.015 * s, wood.darkened(0.08), Vector3.RIGHT)
	mt.chamfer_box(Vector3(1.4, 0.16, 0.2) * s, 0.03 * s, Transform3D(Basis.IDENTITY, Vector3(0, top, 0)), wood.lightened(0.05))
	# Little gable roof.
	for sz: float in [-1.0, 1.0]:
		var roof := Basis(Vector3.RIGHT, sz * deg_to_rad(32.0))
		mt.chamfer_box(Vector3(1.6, 0.06, 0.48) * s, 0.02 * s, Transform3D(roof, Vector3(0, top + 0.23 * s, sz * 0.19 * s)), PropPalette.HULL_PAINT.darkened(0.05))
	add_mesh(parts.build(), "Frame")
	# The bell itself on a swinging pivot.
	bell_pivot = PropKit.pivot(self, "BellPivot", Transform3D(Basis.IDENTITY, Vector3(0, top - 0.08 * s, 0)))
	var bp := PropParts.new()
	bp.metal.chamfer_box(Vector3(0.36, 0.08, 0.12) * s, 0.015 * s, Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.02 * s), PropPalette.IRON_DARK)
	bp.metal.torus(0.03 * s, 0.065 * s, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.DOWN * 0.1 * s), Palette.BRASS, 12, 5)
	# Lathe profiles run with the solid on the left: down the dark inside,
	# round the lip, then up the polished outside.
	var inner := PackedVector2Array([Vector2(0.0, -0.22), Vector2(0.12, -0.3), Vector2(0.15, -0.46), Vector2(0.21, -0.57), Vector2(0.27, -0.6)])
	var outer := PackedVector2Array([
		Vector2(0.27, -0.6), Vector2(0.3, -0.585), Vector2(0.28, -0.55), Vector2(0.22, -0.48), Vector2(0.185, -0.38),
		Vector2(0.17, -0.25), Vector2(0.15, -0.17), Vector2(0.1, -0.135), Vector2(0.0, -0.13),
	])
	for i in inner.size():
		inner[i] *= s
	for i in outer.size():
		outer[i] *= s
	bp.metal.lathe(inner, 16, Transform3D.IDENTITY, Color("7a5a24"))
	bp.metal.lathe(outer, 16, Transform3D.IDENTITY, Palette.BRASS)
	bp.metal.rod(Vector3.DOWN * 0.22 * s, Vector3.DOWN * 0.48 * s, 0.018 * s, 0.018 * s, PropPalette.IRON_DARK, 5, false)
	bp.metal.sphere(0.05 * s, Transform3D(Basis.IDENTITY, Vector3.DOWN * 0.5 * s), PropPalette.IRON_DARK, 4, 8)
	PropKit.mesh_instance(bell_pivot, bp.build(), "BellMesh")
	# Hit area around the bell (attacks, cannonballs).
	var area := Area3D.new()
	area.collision_layer = Layers.PROPS
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	var cs := CollisionShape3D.new()
	cs.shape = PropKit.cylinder_shape(0.34 * s, 0.6 * s)
	cs.position = Vector3.DOWN * 0.38 * s
	area.add_child(cs)
	PropKit.add_generated(bell_pivot, area, "HitArea")
	# Solid frame.
	for sx: float in [-1.0, 1.0]:
		add_shape(PropKit.box_shape(Vector3(0.2 * s, top, 0.2 * s)), Transform3D(Basis.IDENTITY, Vector3(sx * 0.55 * s, top * 0.5, 0)), "Post")
	add_shape(PropKit.box_shape(Vector3(1.6, 0.4, 0.6) * s), Transform3D(Basis.IDENTITY, Vector3(0, top + 0.15 * s, 0)), "Roof")


## Attack interface: any hit rings the bell.
func take_hit(hit: Dictionary) -> void:
	var dir: Vector3 = hit.get("direction", Vector3.FORWARD)
	var local := global_transform.basis.inverse() * dir
	var push := signf(local.z) if absf(local.z) > 0.1 else 1.0
	ring(push * hit_impulse * (1.0 + 0.25 * float(hit.get("damage", 1)) - 0.25))


func ring(impulse: float = 3.0) -> void:
	_vel += impulse
	if _cooldown <= 0.0 and is_inside_tree():
		_cooldown = 0.15
		var pos := bell_pivot.global_position + Vector3.DOWN * 0.4 * size if bell_pivot != null else global_position
		AudioManager.play(ring_sound, pos, 0.0, 1.0, 0.03)
		VFX.sparkle(self, pos, Color(1.0, 0.86, 0.4), 6, 2.0)
	rung.emit(absf(impulse))


func _physics_process(delta: float) -> void:
	if bell_pivot == null or Engine.is_editor_hint():
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	var a := bell_pivot.rotation.x
	if absf(a) < 0.0005 and absf(_vel) < 0.0005:
		return
	_vel += (-14.0 * sin(a) - 1.1 * _vel) * delta
	bell_pivot.rotation.x = clampf(a + _vel * delta, -1.2, 1.2)
