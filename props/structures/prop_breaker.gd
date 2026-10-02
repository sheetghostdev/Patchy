class_name PropBreaker
## Shared "smash it" logic for breakable props (BreakableProp subclasses and
## PhysicsCrate): tumbling debris, dust, sound, contents and persistence.


## Breaks `prop` (whose visual center is `center`, world space): spawns
## `count` fragments from `pieces` ([Mesh, Vector3 box_size] pairs), puffs
## dust, plays `sound`, spawns `contents_count` x `contents` next to it and
## marks `persistent_id` completed in WorldState. Does not free the prop.
static func shatter(prop: Node3D, center: Vector3, hit: Dictionary, pieces: Array, count: int, sound: StringName, contents: PackedScene = null, contents_count: int = 0, persistent_id: StringName = &"") -> void:
	if prop == null or not prop.is_inside_tree():
		return
	var from: Vector3 = hit.get("position", center - Vector3.UP)
	var away := center - from
	away.y = 0.0
	var push := away.normalized() * 2.0 if away.length_squared() > 0.0001 else Vector3.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(prop.get_instance_id())
	var spread := maxf((center - prop.global_position).length() * 0.7, 0.25)
	PropDebris.burst(prop, Transform3D(prop.global_transform.basis.orthonormalized(), center), pieces, count, push, rng, spread)
	VFX.dust(prop, center, 10, 0.55, Color(0.95, 0.88, 0.72, 0.85), 2.4, 0.6)
	VFX.ring(prop, Vector3(center.x, prop.global_position.y, center.z), 1.1, 12, Color(0.95, 0.9, 0.78, 0.75))
	AudioManager.play(sound, center)
	spawn_contents(prop, center, contents, contents_count, rng)
	if persistent_id != &"":
		WorldState.mark_completed(persistent_id)


## Spawns items next to `prop` (siblings). Items with
## `launch(velocity: Vector3)` get it called (deferred); RigidBody3D items get
## a linear velocity instead.
static func spawn_contents(prop: Node3D, center: Vector3, contents: PackedScene, contents_count: int, rng: RandomNumberGenerator) -> void:
	if contents == null or contents_count <= 0:
		return
	var parent := prop.get_parent()
	if parent == null:
		return
	var parent_xf := (parent as Node3D).global_transform if parent is Node3D else Transform3D.IDENTITY
	for i in contents_count:
		var item := contents.instantiate()
		var a := TAU * float(i) / contents_count + rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(a), 0.0, sin(a))
		var r := 0.0 if contents_count == 1 else 0.25
		var gpos := center + dir * r + Vector3.UP * 0.2
		var vel := dir * rng.randf_range(1.0, 2.5) + Vector3.UP * rng.randf_range(4.0, 6.0)
		if item is Node3D:
			(item as Node3D).transform = parent_xf.affine_inverse() * Transform3D(Basis.IDENTITY, gpos)
		if item is RigidBody3D:
			(item as RigidBody3D).linear_velocity = vel
		parent.add_child.call_deferred(item)
		if item.has_method(&"launch"):
			item.call_deferred(&"launch", vel)


## Little squash on `vis` for hits that don't break anything.
static func bonk(owner_node: Node, vis: Node3D) -> Tween:
	if vis == null or not owner_node.is_inside_tree():
		return null
	vis.scale = Vector3.ONE
	var tw := owner_node.create_tween()
	tw.tween_property(vis, "scale", Vector3(1.08, 0.9, 1.08), 0.06)
	tw.tween_property(vis, "scale", Vector3(0.97, 1.04, 0.97), 0.08)
	tw.tween_property(vis, "scale", Vector3.ONE, 0.1)
	return tw
