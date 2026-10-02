class_name PropDebris
extends RigidBody3D
## A short-lived tumbling fragment (crate planks, barrel staves, hoops). A
## dynamic prop on Layers.PROPS (the camera ignores it) that collides with
## the world and other props, but has a collision exception with the player
## (GameManager.player) so planks never snag Patchy's capsule. After
## `lifetime` seconds it shrinks away and frees itself.

const GROUP := &"prop_debris"

static var _physics_material: PhysicsMaterial

var lifetime := 2.5
var _visual: MeshInstance3D


## Spawns `count` fragments around `origin` (global transform of the broken
## prop's center). `pieces` holds [Mesh, Vector3 box_size] pairs that are
## cycled through. `push` biases the throw (e.g. away from the attacker).
## Fragments are added deferred to the current scene, so this is safe to
## call from physics callbacks.
static func burst(context: Node, origin: Transform3D, pieces: Array, count: int, push: Vector3, rng: RandomNumberGenerator, spread: float = 0.4, speed: float = 3.5, life: float = 2.5) -> Array[PropDebris]:
	var out: Array[PropDebris] = []
	if context == null or not context.is_inside_tree() or pieces.is_empty():
		return out
	var tree := context.get_tree()
	var root: Node = tree.current_scene if tree.current_scene != null else tree.root
	if _physics_material == null:
		_physics_material = PhysicsMaterial.new()
		_physics_material.bounce = 0.25
		_physics_material.friction = 0.8
	var player := GameManager.player as PhysicsBody3D
	for i in count:
		var spec: Array = pieces[i % pieces.size()]
		var d := PropDebris.new()
		d.name = "Debris"
		d.top_level = true
		d.collision_layer = Layers.PROPS
		d.collision_mask = Layers.WORLD | Layers.PROPS
		if player != null and is_instance_valid(player):
			d.add_collision_exception_with(player)
		d.mass = 0.35
		d.physics_material_override = _physics_material
		d.lifetime = life * rng.randf_range(0.85, 1.15)
		var mi := MeshInstance3D.new()
		mi.mesh = spec[0]
		d.add_child(mi)
		d._visual = mi
		var cs := CollisionShape3D.new()
		cs.shape = PropKit.box_shape((spec[1] as Vector3).max(Vector3.ONE * 0.03))
		d.add_child(cs)
		var a := TAU * (float(i) + rng.randf_range(-0.3, 0.3)) / count
		var out_dir := Vector3(cos(a), 0.0, sin(a))
		var offset := out_dir * spread * rng.randf_range(0.3, 1.0) + Vector3.UP * spread * rng.randf_range(-0.4, 0.9)
		var rot := Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		d.transform = Transform3D(origin.basis * rot, origin * offset)
		d.linear_velocity = (origin.basis * out_dir) * speed * rng.randf_range(0.6, 1.2) + Vector3.UP * rng.randf_range(3.0, 5.5) + push
		d.angular_velocity = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 9.0
		d.add_to_group(GROUP)
		root.add_child.call_deferred(d)
		out.append(d)
	return out


func _ready() -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(lifetime - 0.4, 0.05))
	tw.tween_property(_visual, "scale", Vector3.ONE * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
