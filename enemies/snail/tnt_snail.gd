class_name TNTSnail
extends CharacterBody3D
## The TNT snail (spec §176): a slow, sleepy snail that traded its shell for
## a powder barrel. It inches toward Patchy; get close and the fuse lights
## (sizzle, flashing barrel, two seconds to back off). A swipe or a stomp
## kicks the barrel off: it skids away and blows up on whatever it hits:
## crabs, cracked rock, targets. The shell-less snail just blushes and
## slinks off, a bump away from defeat.

enum State { CRAWL, FUSE, NAKED, DEFEATED }

const GRAVITY := 30.0

@export var sight_radius := 8.0
@export var crawl_speed := 0.9
@export var fuse_radius := 2.6
@export var fuse_time := 2.2
@export var blast_radius := 3.2
@export var wander_radius := 3.5
@export var coin_drop := 3

var state := State.CRAWL
var home := Vector3.ZERO
var _t := 0.0
var _fuse_t := 0.0
var _face := Vector3.FORWARD
var _wander_target := Vector3.ZERO
var _body: Node3D
var _barrel: Node3D
var _spark: MeshInstance3D
var _barrel_mat_flash := 0.0
var _fuse_loop: AudioStreamPlayer3D
var _eye_l: Node3D
var _eye_r: Node3D


func _ready() -> void:
	collision_layer = Layers.ENEMY
	collision_mask = Layers.WORLD | Layers.PROPS
	add_to_group(&"enemy")
	add_to_group(&"stompable")
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.8, 0.9, 1.1)
	cs.shape = box
	cs.position = Vector3(0, 0.45, 0)
	add_child(cs)
	_build_model()
	home = global_position
	_face = -global_basis.z
	global_basis = Basis.IDENTITY
	_pick_wander()


func _build_model() -> void:
	_body = Node3D.new()
	add_child(_body)
	var skin := Color("b6d96a")
	var mb := MeshBuilder.new()
	mb.ellipsoid(Vector3(0.36, 0.22, 0.7), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0.05)), skin, 8, 14)
	mb.ellipsoid(Vector3(0.28, 0.3, 0.3), Transform3D(Basis.IDENTITY, Vector3(0, 0.38, -0.5)), skin.lightened(0.08), 8, 12)
	mb.ellipsoid(Vector3(0.3, 0.06, 0.66), Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0.05)), skin.darkened(0.2), 4, 12)
	mb.box(Vector3(0.14, 0.03, 0.03), Transform3D(Basis.IDENTITY, Vector3(0, 0.33, -0.79)), Color("4a3b2a"))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_body.add_child(mi)
	for side: float in [-1.0, 1.0]:
		var e := Node3D.new()
		e.position = Vector3(side * 0.12, 0.6, -0.55)
		_body.add_child(e)
		var eb := MeshBuilder.new()
		eb.cylinder(0.025, 0.035, 0.32, Transform3D(Basis.IDENTITY, Vector3(0, 0.16, 0)), skin, 6)
		eb.sphere(0.075, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), Color.WHITE, 6, 8)
		eb.sphere(0.035, Transform3D(Basis.IDENTITY, Vector3(0, 0.36, -0.06)), Palette.PUPIL, 4, 6)
		var em := MeshInstance3D.new()
		em.mesh = eb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		e.add_child(em)
		if side < 0.0:
			_eye_l = e
		else:
			_eye_r = e
	_barrel = Node3D.new()
	_barrel.position = Vector3(0, 0.62, 0.2)
	_body.add_child(_barrel)
	var bb := MeshBuilder.new()
	bb.cylinder(0.3, 0.3, 0.55, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3.ZERO), Color("c8382c"), 14)
	for x: float in [-0.2, 0.2]:
		bb.cylinder(0.315, 0.315, 0.05, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(x, 0, 0)), Palette.METAL, 14)
	bb.box(Vector3(0.3, 0.16, 0.02), Transform3D(Basis.IDENTITY, Vector3(0, 0.05, -0.305)), Color("f6e7c8"))
	bb.cylinder(0.015, 0.02, 0.22, Transform3D(Basis.from_euler(Vector3(0.4, 0, 0)), Vector3(0, 0.36, 0.05)), Color("3b2a1e"), 5)
	var bm := MeshInstance3D.new()
	bm.mesh = bb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_barrel.add_child(bm)
	var lab := Label3D.new()
	lab.text = "TNT"
	lab.font_size = 36
	lab.pixel_size = 0.004
	lab.modulate = Color("c8382c")
	lab.outline_size = 0
	lab.position = Vector3(0, 0.05, -0.32)
	lab.rotation_degrees.y = 180.0
	_barrel.add_child(lab)
	_spark = MeshInstance3D.new()
	var sm := MeshBuilder.new()
	sm.sphere(0.06, Transform3D.IDENTITY, Color("ffd36b"), 4, 6)
	_spark.mesh = sm.build(null, MaterialLibrary.toon(Color.WHITE, &"emissive"))
	_spark.position = Vector3(0, 0.48, 0.1)
	_spark.visible = false
	_barrel.add_child(_spark)


func _physics_process(delta: float) -> void:
	_t += delta
	var p := GameManager.player as Player
	match state:
		State.CRAWL:
			_crawl(p, delta)
			if p != null and p.state_id != &"locked" and p.global_position.distance_to(global_position) < fuse_radius:
				_light_fuse()
		State.FUSE:
			_crawl(p, delta)
			_fuse_t -= delta
			_spark.visible = true
			_spark.scale = Vector3.ONE * (0.8 + randf() * 0.6)
			var rate := lerpf(4.0, 18.0, 1.0 - _fuse_t / fuse_time)
			_barrel.scale = Vector3.ONE * (1.0 + 0.08 * maxf(sin(_t * rate), 0.0))
			if _fuse_t <= 0.0:
				_explode(_barrel.global_position)
				_go_naked()
		State.NAKED:
			# Mortified without its barrel: slinks away from Patchy.
			if p != null:
				var away := Player.flat(global_position - p.global_position).normalized()
				_face = Player.rotate_dir_toward(_face, away, 2.0 * delta)
			var v := _face * crawl_speed * 1.4
			velocity.x = v.x
			velocity.z = v.z
		State.DEFEATED:
			return
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	move_and_slide()
	rotation.y = lerp_angle(rotation.y, Player.yaw_of(_face), 1.0 - exp(-delta * 6.0))
	# Inching squash-and-stretch, eye stalks wobbling.
	_body.scale = Vector3(1.0, 1.0 + sin(_t * 4.0) * 0.05, 1.0 - sin(_t * 4.0) * 0.06)
	if _eye_l != null:
		_eye_l.rotation.z = sin(_t * 2.3) * 0.2
		_eye_r.rotation.z = -sin(_t * 2.1 + 1.0) * 0.2


func _crawl(p: Player, delta: float) -> void:
	var goal := _wander_target
	if p != null and p.global_position.distance_to(global_position) < sight_radius and absf(p.global_position.y - global_position.y) < 2.5:
		goal = p.global_position
	var to := Player.flat(goal - global_position)
	if goal == _wander_target and to.length() < 0.4:
		_pick_wander()
	if to.length() > 0.1:
		var turn := 3.2 if state == State.FUSE else 1.6
		_face = Player.rotate_dir_toward(_face, to.normalized(), turn * delta)
	var v := _face * crawl_speed
	velocity.x = v.x
	velocity.z = v.z


func _pick_wander() -> void:
	var a := randf() * TAU
	_wander_target = home + Vector3(cos(a), 0, sin(a)) * randf_range(0.8, wander_radius)


func _light_fuse() -> void:
	state = State.FUSE
	_fuse_t = fuse_time
	_fuse_loop = AudioManager.create_loop(&"snail_fuse_loop", self, -4.0)
	if _fuse_loop != null and _fuse_loop.stream != null:
		_fuse_loop.play()


func _stop_fuse() -> void:
	_spark.visible = false
	if _fuse_loop != null and is_instance_valid(_fuse_loop):
		_fuse_loop.queue_free()
		_fuse_loop = null


## Swipes, dives and stomps knock the barrel off; it skids away lit.
func take_hit(hit: Dictionary) -> void:
	var kind: StringName = hit.get("kind", &"swipe")
	match state:
		State.CRAWL, State.FUSE:
			if kind in [&"explosion", &"cannon"]:
				_explode(_barrel.global_position)
				_go_naked()
				return
			var dir: Vector3 = Player.flat(hit.get("direction", -_face))
			if dir.length() < 0.1:
				dir = -_face
			_kick_barrel(dir.normalized())
		State.NAKED:
			_defeat()


func on_ground_pound(player: Node3D) -> void:
	take_hit({"kind": &"ground_pound", "direction": Player.flat(global_position - player.global_position).normalized()})


func _kick_barrel(dir: Vector3) -> void:
	_stop_fuse()
	var keg := KickedBarrel.new()
	get_tree().current_scene.add_child(keg)
	keg.global_position = _barrel.global_position
	keg.launch(dir * 9.5, blast_radius)
	AudioManager.play(&"hook_hit", global_position)
	_barrel.visible = false
	_go_naked()


func _go_naked() -> void:
	_stop_fuse()
	_barrel.visible = false
	state = State.NAKED
	_t = 0.0


func _explode(at: Vector3) -> void:
	_stop_fuse()
	KickedBarrel.blast(get_tree().current_scene, at, blast_radius, self)


func _defeat() -> void:
	state = State.DEFEATED
	collision_layer = 0
	remove_from_group(&"enemy")
	remove_from_group(&"stompable")
	AudioManager.play(&"crab_defeat", global_position, 0.0, 1.3)
	VFX.impact(get_tree().current_scene, global_position + Vector3.UP * 0.4)
	for i in coin_drop:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		get_tree().current_scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.5
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1.3, 0.05, 1.3), 0.25)
	tw.tween_callback(queue_free)
