@tool
class_name ParrotTask
extends Interactable
## A world change powered by the flock (spec §65–66): e.g. a fallen log that
## six parrots lift into place as a bridge. Shows "parrots 4 / 6" while
## Patchy is near; with enough parrots, they fly in, grab the object,
## struggle comically, carry it to its destination and fly away. The change
## is permanent (WorldState). Parrots are never consumed.

signal completed(task_id: StringName)

@export var task_id: StringName = &""
@export_range(1, 99) var required_parrots := 6
## The node that gets carried (moved into place).
@export var carried: Node3D
## Where the carried node ends up (its global transform is used).
@export var destination: Node3D
@export_range(0.0, 10.0, 0.1) var lift_height := 2.6
@export_range(0.5, 10.0, 0.1) var carry_time := 2.6
## Visible parrots cap (the requirement can be larger than the show).
@export_range(1, 16) var max_visible_parrots := 8

var _done := false
var _running := false


func _ready() -> void:
	prompt = "{interact} Call the flock"
	radius = 2.6
	super._ready()
	if Engine.is_editor_hint():
		return
	if task_id != &"" and WorldState.is_completed(task_id):
		_done = true
		enabled = false
		if carried != null and destination != null:
			carried.global_transform = destination.global_transform


func can_interact(_player: Node3D) -> bool:
	return enabled and not _done and not _running


func get_prompt() -> String:
	if ParrotManager.get_flock_strength() >= required_parrots:
		return prompt
	return "Needs more parrots"


func on_focus(player: Node3D) -> void:
	super.on_focus(player)
	Events.parrot_requirement_shown.emit(required_parrots, ParrotManager.get_flock_strength(), true)


func on_unfocus() -> void:
	super.on_unfocus()
	Events.parrot_requirement_shown.emit(required_parrots, ParrotManager.get_flock_strength(), false)


func interact(player: Node3D) -> void:
	if ParrotManager.get_flock_strength() < required_parrots:
		AudioManager.play_ui(&"ui_back")
		Events.hud_message.emit("Not enough parrots yet... (%d / %d)" % [ParrotManager.get_flock_strength(), required_parrots], 2.0)
		return
	super.interact(player)
	_run(player as Player)


func _run(player: Player) -> void:
	if carried == null or destination == null:
		push_error("ParrotTask %s needs carried + destination" % name)
		return
	_running = true
	Events.parrot_requirement_shown.emit(required_parrots, ParrotManager.get_flock_strength(), false)
	if player != null:
		var face := Player.flat(carried.global_position - player.global_position).normalized()
		player.set_locked(true, {"anim": &"cheer", "face": face})
	AudioManager.play(&"parrot_squawk", carried.global_position)

	# 1. The flock arrives from the sky and grabs hold.
	var count := mini(required_parrots, max_visible_parrots)
	var birds: Array[Parrot] = []
	var grips: Array[Vector3] = []
	var aabb := _local_extent(carried)
	for i in count:
		var t := (float(i) + 0.5) / count
		var local := Vector3(lerpf(-aabb.x, aabb.x, t), aabb.y + 0.35, (0.35 if i % 2 == 0 else -0.35) * aabb.z)
		grips.append(local)
		var bird := Parrot.new()
		bird.plumage = ((i % 5) as ParrotModel.Plumage)
		get_tree().current_scene.add_child(bird)
		bird.global_position = carried.global_position + Vector3(randf_range(-12, 12), 14.0 + randf() * 6.0, randf_range(-12, 12))
		bird.fly_to(carried.global_transform * local, 11.0)
		birds.append(bird)
	await get_tree().create_timer(1.8, false).timeout

	# 2. Comic struggle: lift, sag, lift.
	for b in birds:
		b.mode = Parrot.Mode.CARRY
	var start := carried.global_transform
	var steps := [0.25, 0.1, 0.45, 0.3, 0.8]
	for h: float in steps:
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void:
			carried.global_transform = Transform3D(start.basis.rotated(Vector3.FORWARD, sin(Time.get_ticks_msec() * 0.02) * 0.03), start.origin + Vector3.UP * v)
			_follow(birds, grips), carried.global_position.y - start.origin.y, h, 0.22).set_trans(Tween.TRANS_SINE)
		await tw.finished
		AudioManager.play(&"wood_creak", carried.global_position, -6.0, randf_range(0.9, 1.1))

	# 3. Carry along an arc to the destination and set it down.
	var from := carried.global_transform
	var to := destination.global_transform
	var tw2 := create_tween()
	tw2.tween_method(func(k: float) -> void:
		var e := smoothstep(0.0, 1.0, k)
		var basis := from.basis.slerp(to.basis, e)
		var pos := from.origin.lerp(to.origin, e) + Vector3.UP * (lift_height * sin(PI * e) + 0.8 * (1.0 - e))
		carried.global_transform = Transform3D(basis, pos)
		_follow(birds, grips), 0.0, 1.0, carry_time)
	await tw2.finished
	var settle := create_tween()
	settle.tween_property(carried, "global_position", to.origin, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await settle.finished
	carried.global_transform = to
	AudioManager.play(&"land_heavy", carried.global_position)
	VFX.ring(self, to.origin, 2.0, 18)
	Events.camera_impulse.emit(0.3)

	# 4. Done: the flock leaves, the world stays changed.
	for b in birds:
		if is_instance_valid(b):
			b.fly_away()
	_done = true
	_running = false
	enabled = false
	if task_id != &"":
		WorldState.mark_completed(task_id)
	Events.world_task_completed.emit(task_id)
	completed.emit(task_id)
	AudioManager.play_stinger(&"stinger_discovery")
	if player != null and player.state_id == &"locked":
		player.set_locked(false)


func _follow(birds: Array[Parrot], grips: Array[Vector3]) -> void:
	for i in birds.size():
		if is_instance_valid(birds[i]):
			birds[i].target = carried.global_transform * grips[i]


## Half extents of the carried object's visual bounds (local space).
static func _local_extent(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	var visuals: Array[VisualInstance3D] = []
	_collect_visuals(n, visuals)
	for vi in visuals:
		var local_box := n.global_transform.affine_inverse() * vi.global_transform * vi.get_aabb()
		box = local_box if first else box.merge(local_box)
		first = false
	if first:
		return Vector3(1.5, 0.4, 0.4)
	return Vector3(maxf(absf(box.position.x), absf(box.end.x)), box.end.y, maxf(absf(box.position.z), absf(box.end.z)))


static func _collect_visuals(n: Node, out: Array[VisualInstance3D]) -> void:
	for c in n.get_children(true):
		if c is VisualInstance3D:
			out.append(c as VisualInstance3D)
		_collect_visuals(c, out)
