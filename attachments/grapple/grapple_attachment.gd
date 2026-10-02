class_name GrappleAttachment
extends AttachmentBase
## A three-pronged grappling claw on a long rope (spec §56).
## - Traversal: fire at a ring or grapple point (even far, dark iron ones the
##   hook can't reach) to be reeled in; swing on arrival or pop up over the
##   ledge it's mounted on. Works in mid-air.
## - Combat: yank crabs off their feet and onto their backs.
## - Puzzles and secrets: anything in the "grapple_pull" group with an
##   on_grapple_pull() method can be dragged closer (crates, levers, loot).
## Targets are picked automatically from what Patchy faces or the camera
## looks at, so it never needs a reticle.

const RANGE := 22.0
const PULL_RANGE := 14.0
const CLAW_SPEED := 70.0
## Cosine of the targeting cone around Patchy's facing / the camera.
const CONE := 0.55

enum Phase { IDLE, OUT, HELD, BACK }

var _phase := Phase.IDLE
var _claw := Vector3.ZERO
var _target: Node3D = null
var _kind: StringName = &""
var _miss_point := Vector3.ZERO
var _mounted: Node3D
var _head: MeshInstance3D
var _rope: MeshInstance3D


func _ready() -> void:
	_mounted = Node3D.new()
	add_child(_mounted)
	var mi := MeshInstance3D.new()
	mi.mesh = _claw_mesh(true)
	_mounted.add_child(mi)
	_head = MeshInstance3D.new()
	_head.mesh = _claw_mesh(false)
	_head.top_level = true
	_head.visible = false
	add_child(_head)
	_rope = MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 1.0
	cyl.radial_segments = 6
	cyl.rings = 1
	_rope.mesh = cyl
	_rope.material_override = MaterialLibrary.toon(Color(0.72, 0.55, 0.34), &"matte")
	_rope.top_level = true
	_rope.visible = false
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)


## The claw: a brass collar and three hooked steel prongs. Mounted on the
## hand it points down the forearm (-Y); in flight it points along -Z.
static func _claw_mesh(mounted: bool) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var base := Basis.IDENTITY if mounted else Basis.from_euler(Vector3(-PI * 0.5, 0, 0))
	var xf := func(pos: Vector3) -> Transform3D:
		return Transform3D(base, base * pos)
	mb.cylinder(0.07, 0.06, 0.1, xf.call(Vector3(0, -0.05, 0)), Palette.BRASS, 10)
	mb.cylinder(0.035, 0.035, 0.12, xf.call(Vector3(0, -0.15, 0)), Palette.HOOK_METAL, 8)
	for k in 3:
		var a := TAU * k / 3.0
		var out := Vector3(cos(a), 0, sin(a))
		var pts := PackedVector3Array()
		for j in 6:
			var t := float(j) / 5.0
			var r := 0.03 + sin(t * PI * 0.8) * 0.11
			pts.append(base * (out * r + Vector3(0, -0.2 - t * 0.17 + pow(t, 3.0) * 0.08, 0)))
		var radii := PackedFloat32Array([0.028, 0.026, 0.023, 0.02, 0.016, 0.01])
		mb.tube(pts, radii, Palette.HOOK_METAL, 6)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))


func pickup_hint() -> String:
	return "Grapple! {tool_primary} reels you to rings and iron points, even mid-air. It yanks crabs too."


func allows_air_action() -> bool:
	return true


func unequip() -> void:
	super.unequip()
	_reset()


func _hand() -> Vector3:
	return global_position + global_basis.y * -0.25


func primary_action() -> void:
	if player == null or _phase != Phase.IDLE:
		return
	var hand := _hand()
	var pick := _pick_target(hand)
	_target = pick.get("node")
	_kind = pick.get("kind", &"miss")
	var aim := _aim_dirs(hand)[0] as Vector3
	_miss_point = hand + aim * 9.0 + Vector3.UP * 0.6
	var hit := player.raycast(hand, _miss_point, Layers.WORLD)
	if not hit.is_empty():
		_miss_point = hit.position
	_claw = hand
	_phase = Phase.OUT
	player.play_tool_anim(&"aim", 0.4)
	if _target != null:
		var to := Player.flat(_target.global_position - player.global_position)
		if to.length() > 0.2:
			player.facing = to.normalized()
	AudioManager.play(&"grapple_fire", hand)
	_mounted.visible = false
	_head.visible = true
	_rope.visible = true


func physics_update(delta: float) -> void:
	if player == null:
		return
	match _phase:
		Phase.IDLE:
			return
		Phase.OUT:
			var goal := _goal()
			_claw = _claw.move_toward(goal, CLAW_SPEED * delta)
			if _claw.distance_to(goal) < 0.05:
				_arrive()
		Phase.HELD:
			if _target == null or not is_instance_valid(_target) or not player.state_id in [&"grapple", &"swing"]:
				_phase = Phase.BACK
			else:
				_claw = _goal()
		Phase.BACK:
			var hand := _hand()
			_claw = _claw.move_toward(hand, CLAW_SPEED * 1.3 * delta)
			if _claw.distance_to(hand) < 0.1:
				_reset()
				return
	_update_rope()


func _goal() -> Vector3:
	if _target != null and is_instance_valid(_target):
		if _target.has_method(&"get_anchor_position"):
			return _target.call(&"get_anchor_position")
		return _target.global_position + Vector3.UP * 0.4
	return _miss_point


func _arrive() -> void:
	match _kind:
		&"zip":
			AudioManager.play(&"grapple_hit", _claw)
			player.change_state(&"grapple", {"anchor": _target})
			_phase = Phase.HELD
		&"pull":
			AudioManager.play(&"grapple_hit", _claw)
			player.play_tool_anim(&"pull", 0.45)
			if is_instance_valid(_target):
				_target.call(&"on_grapple_pull", player)
			_phase = Phase.BACK
		_:
			AudioManager.play(&"hook_hit", _claw, -6.0)
			_phase = Phase.BACK


func _update_rope() -> void:
	var a := _hand()
	var b := _claw
	var length := a.distance_to(b)
	if length < 0.05:
		_rope.visible = false
		return
	_rope.visible = true
	var y := (b - a) / length
	var side := Vector3.UP if absf(y.y) < 0.98 else Vector3.RIGHT
	var x := y.cross(side).normalized()
	var z := x.cross(y)
	_rope.global_transform = Transform3D(Basis(x, y * length, z), (a + b) * 0.5)
	var fwd := -y if _phase == Phase.BACK else y
	_head.global_transform = Transform3D(Basis.looking_at(fwd, side), b)


func _reset() -> void:
	_phase = Phase.IDLE
	_target = null
	if _head != null:
		_head.visible = false
		_rope.visible = false
		_mounted.visible = true


## [primary aim, secondary aim]: Patchy's facing (or stick) and the camera.
func _aim_dirs(_hand_pos: Vector3) -> Array:
	var face := player.facing
	var stick := Player.flat(player.input.move_dir)
	if stick.length() > 0.3:
		face = stick.normalized()
	var cam := Player.flat(-player.get_camera_basis().z).normalized()
	return [face, cam if cam.length() > 0.1 else face]


func _pick_target(hand: Vector3) -> Dictionary:
	var aims := _aim_dirs(hand)
	var best := {}
	var best_score := INF
	var candidates: Array = []
	for n in get_tree().get_nodes_in_group(&"hook_point"):
		if n.has_method(&"can_grapple") and n.call(&"can_grapple"):
			candidates.append([n, &"zip", RANGE])
	for n in get_tree().get_nodes_in_group(&"enemy") + get_tree().get_nodes_in_group(&"grapple_pull"):
		if n.has_method(&"on_grapple_pull"):
			candidates.append([n, &"pull", PULL_RANGE])
	for c in candidates:
		var node := c[0] as Node3D
		var kind: StringName = c[1]
		var pos: Vector3 = node.call(&"get_anchor_position") if node.has_method(&"get_anchor_position") else node.global_position + Vector3.UP * 0.4
		var to := pos - hand
		var d := to.length()
		if d > float(c[2]) or d < 1.2:
			continue
		var flat_to := Player.flat(to)
		var dot := 1.0
		if flat_to.length() > 2.5:
			var fd := flat_to.normalized()
			dot = maxf(fd.dot(aims[0]), fd.dot(aims[1]))
			if dot < CONE:
				continue
		if kind == &"zip" and pos.y < player.global_position.y - 2.0:
			continue
		var hit := player.raycast(hand, pos, Layers.WORLD)
		if not hit.is_empty() and (hit.position as Vector3).distance_to(pos) > 0.8:
			continue
		var score := d * (2.2 - dot) + (2.0 if kind == &"pull" else 0.0)
		if score < best_score:
			best_score = score
			best = {"node": node, "kind": kind}
	return best
