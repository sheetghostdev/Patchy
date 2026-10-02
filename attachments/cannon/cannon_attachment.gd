class_name CannonAttachment
extends AttachmentBase
## A stubby brass hand cannon (spec §59).
## - Combat: iron balls at range; even armored crabs get bowled over.
## - Puzzles: bullseye targets open gates.
## - Secrets: cracked rock crumbles to reveal hidden nooks.
## - Traversal: fired mid-air it kicks Patchy upward once per jump (a
##   "cannon hop"), a little extra reach for the brave.
## Aims itself at the nearest target or foe in front; otherwise straight ahead.

const COOLDOWN := 0.55
const SPEED := 26.0
const RANGE := 26.0
const CONE := 0.8
const HOP_SPEED := 7.5

var _cool := 0.0
var _hop_used := false


func _ready() -> void:
	var metal := MeshBuilder.new()
	var wood := MeshBuilder.new()
	wood.cylinder(0.085, 0.08, 0.1, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0)), Palette.WOOD_DARK, 12)
	metal.cylinder(0.075, 0.09, 0.34, Transform3D(Basis.IDENTITY, Vector3(0, -0.26, 0)), Palette.BRASS, 14)
	metal.torus(0.075, 0.105, Transform3D(Basis.IDENTITY, Vector3(0, -0.14, 0)), Palette.BRASS.darkened(0.2), 14, 6)
	metal.torus(0.08, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, -0.43, 0)), Palette.BRASS.lightened(0.1), 14, 6)
	metal.cylinder(0.05, 0.05, 0.02, Transform3D(Basis.IDENTITY, Vector3(0, -0.445, 0)), Color("2b2622"), 10)
	add_mesh(wood, &"matte")
	add_mesh(metal, &"metal")


func pickup_hint() -> String:
	return "Hand cannon! {tool_primary} fires: crack rocks, hit targets, and hop higher mid-air."


func allows_air_action() -> bool:
	return true


func physics_update(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if player != null and player.is_on_floor():
		_hop_used = false


func primary_action() -> void:
	if player == null or _cool > 0.0:
		return
	_cool = COOLDOWN
	var muzzle := player.global_position + Vector3.UP * 1.05 + player.facing * 0.45
	var dir := _aim(muzzle)
	var airborne := player.state_id == &"air"
	if airborne:
		if not _hop_used:
			# Cannon hop: blast down and behind, ride the recoil up.
			_hop_used = true
			dir = (player.facing * 0.55 + Vector3.DOWN).normalized()
			player.velocity.y = maxf(player.velocity.y, HOP_SPEED)
		Events.camera_impulse.emit(0.25)
	else:
		player.set_horizontal_velocity(Player.flat(player.velocity) * 0.3 - Player.flat(dir) * 2.0)
		Events.camera_impulse.emit(0.15)
	var flat_dir := Player.flat(dir)
	if flat_dir.length() > 0.2 and not airborne:
		player.facing = flat_dir.normalized()
	player.play_tool_anim(&"aim", 0.45)
	AudioManager.play(&"cannon_fire", muzzle)
	VFX.dust(get_tree().current_scene, muzzle + dir * 0.3, 6, 0.3, Color(0.9, 0.9, 0.9, 0.75), 0.8, 0.6)
	var ball := Cannonball.new()
	ball.shooter = player
	ball.velocity = dir * SPEED
	get_tree().current_scene.add_child(ball)
	ball.global_position = muzzle


static func _aim_point(t: Node3D) -> Vector3:
	if t.has_method(&"get_aim_point"):
		return t.call(&"get_aim_point")
	return t.global_position + Vector3.UP * 0.4


func _aim(muzzle: Vector3) -> Vector3:
	var face := player.facing
	var stick := Player.flat(player.input.move_dir)
	if stick.length() > 0.3:
		face = stick.normalized()
	var best: Node3D = null
	var best_score := INF
	for n in get_tree().get_nodes_in_group(&"cannon_target") + get_tree().get_nodes_in_group(&"enemy"):
		var t := n as Node3D
		if t == null or not t.visible:
			continue
		var aim_point := _aim_point(t)
		var to := aim_point - muzzle
		var d := to.length()
		if d > RANGE or d < 0.8:
			continue
		var dot := Player.flat(to).normalized().dot(face)
		if dot < CONE:
			continue
		var hit := player.raycast(muzzle, aim_point, Layers.WORLD)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(aim_point) > 1.0:
			continue
		var score := d * (2.0 - dot)
		if score < best_score:
			best_score = score
			best = t
	if best == null:
		return (face + Vector3.UP * 0.05).normalized()
	# Lead the drop: aim a little high over distance.
	var goal := _aim_point(best)
	var dist := muzzle.distance_to(goal)
	var t_flight := dist / SPEED
	goal.y += 0.5 * Cannonball.GRAVITY * t_flight * t_flight
	return (goal - muzzle).normalized()
