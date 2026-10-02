class_name Cannonball
extends Node3D
## A chunky iron ball from the hand cannon. Simple ballistic flight with
## swept ray collision; bursts on impact, hitting everything nearby.

const GRAVITY := 9.0
const LIFETIME := 2.6
const BLAST_RADIUS := 1.5

var velocity := Vector3.ZERO
var shooter: Node3D
## Enemy shots hurt Patchy in the blast and spare other enemies.
var hurts_player := false
var _t := 0.0
var _mesh: MeshInstance3D


func _ready() -> void:
	var mb := MeshBuilder.new()
	mb.sphere(0.17, Transform3D.IDENTITY, Color("3a3f4a"), 8, 12)
	mb.sphere(0.05, Transform3D(Basis.IDENTITY, Vector3(0.07, 0.08, -0.08)), Color("8d96a8"), 4, 6)
	_mesh = MeshInstance3D.new()
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	add_child(_mesh)


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > LIFETIME:
		queue_free()
		return
	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD | Layers.ENEMY | Layers.PROPS | Layers.INTERACTABLE)
	q.collide_with_areas = true
	if shooter is CollisionObject3D:
		q.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		_burst(hit.position)
		return
	global_position = to
	_mesh.rotation += Vector3(9.0, 4.0, 0.0) * delta


func _burst(at: Vector3) -> void:
	var scene := get_tree().current_scene
	VFX.impact(scene, at, Color(1.0, 0.8, 0.45), 10)
	VFX.dust(scene, at, 8, 0.45, Color(0.85, 0.82, 0.78, 0.8), 1.8, 1.2)
	AudioManager.play(&"explosion", at, -7.0, 1.5)
	Events.camera_impulse.emit(0.2)
	var shape := SphereShape3D.new()
	shape.radius = BLAST_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, at)
	q.collision_mask = Layers.WORLD | Layers.ENEMY | Layers.PROPS | Layers.INTERACTABLE
	q.collide_with_areas = true
	var told := {}
	if hurts_player:
		var p := GameManager.player as Player
		if p != null and p.global_position.distance_to(at) < BLAST_RADIUS + 0.3:
			p.health.take_damage(1, at)
	for h in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var n := h.collider as Node
		var receiver := n
		for i in 3:
			if receiver == null or receiver.has_method(&"on_cannon_hit") or receiver.has_method(&"take_hit"):
				break
			receiver = receiver.get_parent()
		if receiver == null or receiver == shooter or told.has(receiver):
			continue
		if hurts_player and (receiver.is_in_group(&"enemy") or receiver is Player):
			continue
		told[receiver] = true
		if receiver.has_method(&"on_cannon_hit"):
			receiver.call(&"on_cannon_hit", self)
		elif receiver.has_method(&"take_hit"):
			var dir := Player.flat(velocity).normalized()
			receiver.call(&"take_hit", {"damage": 2, "kind": &"cannon", "source": shooter, "position": at, "direction": dir})
	queue_free()
