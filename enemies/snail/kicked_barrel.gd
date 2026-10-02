class_name KickedBarrel
extends Node3D
## A lit powder barrel skidding across the ground (kicked off a TNT snail).
## Blows up on the first enemy or wall it meets, or when the fuse runs out.

const FUSE := 1.5

var velocity := Vector3.ZERO
var radius := 2.6
var _t := 0.0
var _done := false
var _mesh: MeshInstance3D


func _ready() -> void:
	var bb := MeshBuilder.new()
	bb.cylinder(0.3, 0.3, 0.55, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3.ZERO), Color("c8382c"), 14)
	for x: float in [-0.2, 0.2]:
		bb.cylinder(0.315, 0.315, 0.05, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(x, 0, 0)), Palette.METAL, 14)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = bb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	add_child(_mesh)


func launch(v: Vector3, blast_radius: float) -> void:
	velocity = v
	radius = blast_radius
	look_at(global_position + Player.flat(v).normalized() + Vector3(0.001, 0, 0), Vector3.UP)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	var space := get_world_3d().direct_space_state
	var step := velocity * delta
	# Hug the ground.
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.5, global_position + Vector3.DOWN * 2.0, Layers.WORLD))
	if not down.is_empty():
		global_position.y = (down.position as Vector3).y + 0.32
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + step + step.normalized() * 0.35, Layers.WORLD | Layers.ENEMY | Layers.PROPS)
	q.collide_with_areas = false
	var hit := space.intersect_ray(q)
	if not hit.is_empty() and _t > 0.06:
		_boom()
		return
	global_position += step
	velocity = velocity.move_toward(Vector3.ZERO, 2.5 * delta)
	_mesh.rotation.x += velocity.length() * delta * 3.0
	if _t > FUSE:
		_boom()


func _boom() -> void:
	_done = true
	blast(get_tree().current_scene, global_position, radius, null)
	queue_free()


## Shared explosion: damages Patchy in range, knocks out enemies, breaks
## cracked rock and rings targets (anything with on_cannon_hit).
static func blast(scene: Node, at: Vector3, radius: float, source: Node) -> void:
	VFX.impact(scene, at, Color(1.0, 0.75, 0.35), 14)
	VFX.dust(scene, at, 16, 0.6, Color(0.6, 0.55, 0.5, 0.85), radius, 2.0)
	VFX.ring(scene, at + Vector3.UP * 0.1, radius, 22, Color(1.0, 0.8, 0.5, 0.9))
	AudioManager.play(&"explosion", at, 2.0)
	Events.camera_impulse.emit(0.55)
	var p := GameManager.player as Player
	if p != null and p.global_position.distance_to(at) < radius * 0.85:
		p.health.take_damage(1, at)
	var world := (scene as Node3D).get_world_3d() if scene is Node3D else (GameManager.player as Node3D).get_world_3d()
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PROPS | Layers.INTERACTABLE
	q.collide_with_areas = true
	var told := {}
	for h in world.direct_space_state.intersect_shape(q, 24):
		var n := h.collider as Node
		var receiver := n
		for i in 3:
			if receiver == null or receiver.has_method(&"on_cannon_hit") or receiver.has_method(&"take_hit"):
				break
			receiver = receiver.get_parent()
		if receiver == null or receiver == source or receiver is Player or told.has(receiver):
			continue
		told[receiver] = true
		if receiver.has_method(&"on_cannon_hit"):
			receiver.call(&"on_cannon_hit", null)
		elif receiver.has_method(&"take_hit"):
			receiver.call(&"take_hit", {"damage": 2, "kind": &"explosion", "source": source, "position": at, "direction": Player.flat((receiver as Node3D).global_position - at).normalized()})
