class_name Pelican
extends Node3D
## The pelican (spec §177): a greedy seabird circling the beach. When it
## spots Patchy in the open it hovers, a shadow ring marks the spot, then it
## dives and skims along the sand with its pouch open. A hit scoops three
## coins (never hearts) and knocks Patchy aside. It bobs on the ground for a
## moment after the skim, so swipe it then (or shoot it out of the air) to
## daze it; dazed, it coughs up everything it took. A second hit sends it
## off for good.

enum State { CIRCLE, SPOT, DIVE, SKIM, CLIMB, DAZED, GONE }

@export var circle_radius := 8.0
@export var altitude := 9.0
@export var spot_radius := 13.0
@export var steal_amount := 3
@export var persistent_id: StringName = &""

var state := State.CIRCLE
var home := Vector3.ZERO
var pouch := 0
var _t := 0.0
var _angle := 0.0
var _vel := Vector3.ZERO
var _mark := Vector3.ZERO
var _cool := 3.0
var _hits := 0
var _model: Node3D
var _wing_l: Node3D
var _wing_r: Node3D
var _pouch_mesh: Node3D
var _shadow: MeshInstance3D
var _area: Area3D


func _ready() -> void:
	add_to_group(&"enemy")
	if persistent_id != &"" and WorldState.is_completed(persistent_id):
		queue_free()
		return
	home = global_position
	_build()
	_area = Area3D.new()
	_area.collision_layer = Layers.ENEMY
	_area.collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.75
	cs.shape = sph
	_area.add_child(cs)
	add_child(_area)
	_area.body_entered.connect(_on_body)
	_shadow = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.2
	tm.rings = 24
	tm.ring_segments = 4
	_shadow.mesh = tm
	_shadow.material_override = MaterialLibrary.unshaded(Color(0.2, 0.15, 0.35, 0.55))
	_shadow.top_level = true
	_shadow.visible = false
	add_child(_shadow)
	_angle = randf() * TAU
	global_position = home + Vector3(cos(_angle) * circle_radius, altitude, sin(_angle) * circle_radius)


func _build() -> void:
	_model = Node3D.new()
	add_child(_model)
	var white := Color("f4f1ea")
	var beak := Color("f2a33a")
	var mb := MeshBuilder.new()
	mb.ellipsoid(Vector3(0.42, 0.38, 0.7), Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.1)), white, 8, 14)
	mb.ellipsoid(Vector3(0.26, 0.26, 0.28), Transform3D(Basis.IDENTITY, Vector3(0, 0.32, -0.55)), white, 8, 12)
	mb.cylinder(0.02, 0.1, 0.85, Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), Vector3(0, 0.3, -1.1)), beak, 8)
	mb.ellipsoid(Vector3(0.18, 0.06, 0.08), Transform3D(Basis.IDENTITY, Vector3(0, 0.22, -1.48)), beak.darkened(0.2), 4, 6)
	for side: float in [-1.0, 1.0]:
		mb.sphere(0.06, Transform3D(Basis.IDENTITY, Vector3(side * 0.16, 0.42, -0.7)), Palette.PUPIL, 4, 6)
		mb.sphere(0.025, Transform3D(Basis.IDENTITY, Vector3(side * 0.17, 0.45, -0.74)), Color.WHITE, 3, 4)
	mb.ellipsoid(Vector3(0.22, 0.12, 0.3), Transform3D(Basis.from_euler(Vector3(0.3, 0, 0)), Vector3(0, -0.05, 0.75)), white.darkened(0.08), 5, 8)
	mb.cylinder(0.03, 0.04, 0.3, Transform3D(Basis.IDENTITY, Vector3(0.12, -0.45, 0.2)), beak, 5)
	mb.cylinder(0.03, 0.04, 0.3, Transform3D(Basis.IDENTITY, Vector3(-0.12, -0.45, 0.2)), beak, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_model.add_child(mi)
	# Throat pouch: swells when full of stolen coins.
	_pouch_mesh = Node3D.new()
	_pouch_mesh.position = Vector3(0, 0.12, -1.05)
	_model.add_child(_pouch_mesh)
	var pb := MeshBuilder.new()
	pb.ellipsoid(Vector3(0.12, 0.13, 0.36), Transform3D.IDENTITY, Color("f6c77e"), 6, 10)
	var pm := MeshInstance3D.new()
	pm.mesh = pb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_pouch_mesh.add_child(pm)
	for side: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(side * 0.35, 0.15, 0.0)
		_model.add_child(w)
		var wb := MeshBuilder.new()
		wb.ellipsoid(Vector3(0.75, 0.06, 0.32), Transform3D(Basis.IDENTITY, Vector3(side * 0.7, 0, 0.05)), white, 5, 10)
		wb.ellipsoid(Vector3(0.3, 0.05, 0.22), Transform3D(Basis.IDENTITY, Vector3(side * 1.35, 0, 0.12)), Color("2d2d3a"), 4, 8)
		var wm := MeshInstance3D.new()
		wm.mesh = wb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		w.add_child(wm)
		if side < 0.0:
			_wing_l = w
		else:
			_wing_r = w


func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameManager.player as Player
	match state:
		State.CIRCLE:
			_cool = maxf(_cool - delta, 0.0)
			_angle += delta * 0.55
			var goal := home + Vector3(cos(_angle) * circle_radius, altitude, sin(_angle) * circle_radius)
			_fly_toward(goal, 7.0, delta)
			if _cool <= 0.0 and _can_target(p):
				_enter(State.SPOT)
				_mark = p.global_position
				AudioManager.play(&"parrot_squawk", global_position, 2.0, 0.55)
		State.SPOT:
			# Hover above the mark while the ring tracks Patchy briefly, then locks.
			if _t < 0.6 and p != null:
				_mark = _mark.lerp(p.global_position, 1.0 - exp(-delta * 6.0))
			var over := _mark + Vector3.UP * altitude * 0.8 + Player.flat(global_position - _mark).normalized() * 5.0
			_fly_toward(over, 8.0, delta)
			_shadow.visible = true
			_shadow.global_position = _mark + Vector3.UP * 0.06
			if _t > 1.1:
				_enter(State.DIVE)
		State.DIVE:
			var aim := _mark + Vector3.UP * 0.5
			_vel = _vel.move_toward((aim - global_position).normalized() * 17.0, 60.0 * delta)
			global_position += _vel * delta
			if global_position.distance_to(aim) < 0.8 or global_position.y < aim.y:
				_enter(State.SKIM)
				_shadow.visible = false
		State.SKIM:
			var flat_v := Player.flat(_vel).normalized() * 9.0
			_vel = Vector3(flat_v.x, 0.0, flat_v.z)
			global_position += _vel * delta
			global_position.y = lerpf(global_position.y, _ground_y() + 0.6, 1.0 - exp(-delta * 12.0))
			if _t > 0.55:
				# Bob on the ground a moment: the opening to hit back.
				_vel = Vector3.ZERO
				if _t > 1.5:
					_enter(State.CLIMB)
		State.CLIMB:
			var goal := home + Vector3(cos(_angle) * circle_radius, altitude, sin(_angle) * circle_radius)
			_fly_toward(goal, 8.0, delta)
			if global_position.distance_to(goal) < 1.5:
				_enter(State.CIRCLE)
				_cool = 4.0
		State.DAZED:
			global_position.y = lerpf(global_position.y, _ground_y() + 0.45, 1.0 - exp(-delta * 8.0))
			if _t > 3.2:
				_enter(State.CLIMB)
		State.GONE:
			global_position += Vector3(0.3, 1.0, -0.2).normalized() * 9.0 * delta
			if _t > 3.0:
				queue_free()
	_animate(delta)


func _enter(s: State) -> void:
	state = s
	_t = 0.0


func _can_target(p: Player) -> bool:
	if p == null or not p.state_id in [&"ground", &"air"] or p.health.is_respawning():
		return false
	var d := Player.flat(p.global_position - home).length()
	if d > spot_radius + circle_radius * 0.5:
		return false
	# Only in the open: a roof over Patchy keeps him safe.
	var roof := p.raycast(p.global_position + Vector3.UP * 1.6, p.global_position + Vector3.UP * 12.0, Layers.WORLD)
	return roof.is_empty()


func _fly_toward(goal: Vector3, speed: float, delta: float) -> void:
	var to := goal - global_position
	var want := to.limit_length(speed) if to.length() > 0.05 else Vector3.ZERO
	_vel = _vel.move_toward(want, 14.0 * delta)
	global_position += _vel * delta


func _ground_y() -> float:
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, global_position + Vector3.DOWN * 20.0, Layers.WORLD | Layers.WATER))
	return (hit.position as Vector3).y if not hit.is_empty() else global_position.y - 1.0


func _on_body(body: Node3D) -> void:
	if not body is Player or state not in [State.DIVE, State.SKIM]:
		return
	var p := body as Player
	if p.health.is_flashing():
		return
	var taken := mini(steal_amount, InventoryManager.gold_value)
	if taken > 0:
		InventoryManager.lose_gold(taken)
		pouch += taken
		AudioManager.play(&"coin_03", global_position, 0.0, 0.7)
		Events.hud_message.emit("The pelican snatched %d coins!" % taken, 2.0)
	AudioManager.play(&"parrot_squawk", global_position, 0.0, 0.7)
	# A shove, not a wound: knockback without losing a heart.
	var away := Player.flat(p.global_position - global_position).normalized()
	p.start_jump(&"knockback", 5.0, away * 6.0)
	_enter(State.CLIMB)


func take_hit(hit: Dictionary) -> void:
	if state in [State.CIRCLE, State.CLIMB, State.SPOT] and hit.get("kind", &"") != &"cannon":
		return
	if state == State.GONE:
		return
	_hits += 1
	AudioManager.play(&"crab_hit", global_position, 0.0, 1.3)
	VFX.impact(get_tree().current_scene, global_position, Color.WHITE)
	_shadow.visible = false
	_spill_pouch()
	if _hits >= 2:
		_enter(State.GONE)
		if persistent_id != &"":
			WorldState.mark_completed(persistent_id)
		for i in 3:
			var c := Collectible.new()
			c.kind = "coin"
			c.launched = true
			get_tree().current_scene.add_child(c)
			c.global_position = global_position
		return
	_enter(State.DAZED)


func _spill_pouch() -> void:
	for i in pouch:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		get_tree().current_scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.3
	pouch = 0


func _animate(delta: float) -> void:
	var flat_v := Player.flat(_vel)
	if flat_v.length() > 0.5:
		var yaw := Player.yaw_of(flat_v)
		rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-delta * 6.0))
	var flap := 0.0
	var pitch := 0.0
	match state:
		State.CIRCLE, State.CLIMB:
			flap = sin(_t * 6.0) * 0.6
		State.SPOT:
			flap = sin(_t * 11.0) * 0.8
		State.DIVE:
			flap = -1.1
			pitch = -0.7
		State.SKIM:
			flap = 0.2 + sin(_t * 14.0) * 0.2
		State.DAZED:
			flap = 0.9 + sin(_t * 3.0) * 0.1
			_model.rotation.z = sin(_t * 4.0) * 0.25
		State.GONE:
			flap = sin(_t * 12.0) * 0.8
	_wing_l.rotation.z = flap
	_wing_r.rotation.z = -flap
	_model.rotation.x = lerpf(_model.rotation.x, pitch, 1.0 - exp(-delta * 8.0))
	if state != State.DAZED:
		_model.rotation.z = lerpf(_model.rotation.z, 0.0, 1.0 - exp(-delta * 6.0))
	var full := clampf(float(pouch) / 6.0, 0.0, 1.0)
	_pouch_mesh.scale = Vector3.ONE * (1.0 + full * 0.8)
