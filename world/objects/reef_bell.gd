@tool
class_name ReefBell
extends StaticBody3D
## One of Bell Atoll's five bells (docs/ARCHIPELAGO.md): a brass bell under
## a little red cap on a driftwood frame, with its note painted on a plaque
## as a wave with that many crests (note 1, the biggest bell, sounds lowest).
## Hit it with the hook, a cannonball or a ground pound close by and it
## swings and rings its note (`rung`). BellSong lights it while it's part
## of the song being played. Note 0 is the great bell in the belfry.
## Local space: -Z faces the lagoon.

signal rung(bell: ReefBell)
## The great bell's song lit this bell for its note.
signal pulsed(bell: ReefBell)

## Pitch of each note on the reef_bell sound (C D E G A), note 1 first.
const PITCH := [0.75, 0.842, 0.945, 1.124, 1.262]
const GREAT_PITCH := 0.5
const POST_H := 3.6
const WAVE := Color("2f6fb0")
const LIT := Color("ffd166")

@export_range(0, 5) var note := 1:
	set(v):
		note = v
		_rebuild()

var lit := false
var _pivot: Node3D
var _light: OmniLight3D
var _swing := Vector2.ZERO
var _swing_v := Vector2.ZERO
var _cool := 0.0


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"wood")
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"cannon_target")
	add_to_group(&"reef_bell")


## The bell's size (1 for the middle note).
func bell_size() -> float:
	if note == 0:
		return 1.7
	return lerpf(1.25, 0.8, (note - 1) / 4.0)


func pitch() -> float:
	return GREAT_PITCH if note == 0 else PITCH[clampi(note, 1, 5) - 1]


## The middle of the bell (cannon aim, hit sparks).
func get_aim_point() -> Vector3:
	return _pivot.global_position + Vector3.DOWN * 0.7 * bell_size() if _pivot != null else global_position + Vector3.UP * 2.6


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta(&"bell_part", false):
			c.queue_free()
	var s := bell_size()
	var great := note == 0
	# The frame (the great bell hangs in the belfry instead).
	if not great:
		var mb := MeshBuilder.new()
		for side: float in [-1.0, 1.0]:
			mb.cylinder(0.12, 0.15, POST_H, Transform3D(Basis.IDENTITY, Vector3(side * 1.25, POST_H * 0.5, 0)), Palette.WOOD_DARK, 6)
		mb.box(Vector3(3.0, 0.24, 0.26), Transform3D(Basis.IDENTITY, Vector3(0, POST_H, 0)), Palette.WOOD)
		mb.cylinder(0.0, 1.5, 0.9, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(0, POST_H + 0.6, 0)), Color("c8432f"), 4)
		# The plaque with the note's wave, both faces, nailed to the left
		# post at eye level.
		var plaque := Vector3(-1.25, 1.9, 0)
		mb.box(Vector3(1.0, 0.56, 0.08), Transform3D(Basis.IDENTITY, plaque), Color("efe2c4"))
		for face: float in [-1.0, 1.0]:
			_wave(mb, plaque + Vector3(0, 0.03, face * 0.05), 0.8, 0.22, note, face)
			for d in note:
				mb.sphere(0.03, Transform3D(Basis.IDENTITY, plaque + Vector3((d - (note - 1) * 0.5) * 0.1, -0.19, face * 0.05)), WAVE, 3, 5)
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		_part(mi)
		for side: float in [-1.0, 1.0]:
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.16
			cyl.height = POST_H
			cs.shape = cyl
			cs.position = Vector3(side * 1.25, POST_H * 0.5, 0)
			_part(cs)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, POST_H - 0.12 if not great else 0.0, 0)
	_part(_pivot)
	var bm := PropBuilder.new()
	var profile := PackedVector2Array([Vector2(0.62, -1.3), Vector2(0.58, -1.12), Vector2(0.47, -0.75), Vector2(0.37, -0.3), Vector2(0.27, -0.08), Vector2(0.0, 0.0)])
	bm.lathe(profile, 14, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3.ZERO), Color("e8b84a"))
	bm.sphere(0.14 * s, Transform3D(Basis.IDENTITY, Vector3(0, -1.22 * s, 0)), Color("9c7428"), 4, 8)
	bm.cylinder(0.05, 0.05, 0.2, Transform3D(Basis.IDENTITY, Vector3(0, 0.08, 0)), Palette.METAL, 6)
	bm.flat_shade()
	var bell_mi := MeshInstance3D.new()
	bell_mi.mesh = bm.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	_pivot.add_child(bell_mi)
	# A solid bell, and a generous hurtbox round it for the hook's swipe.
	var bell_shape := CollisionShape3D.new()
	var bc := CylinderShape3D.new()
	bc.radius = 0.55 * s
	bc.height = 1.25 * s
	bell_shape.shape = bc
	bell_shape.position = _pivot.position + Vector3.DOWN * 0.65 * s
	_part(bell_shape)
	var hurt := Area3D.new()
	hurt.collision_layer = Layers.INTERACTABLE
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape3D.new()
	var hc := CylinderShape3D.new()
	hc.radius = 1.0 * s + 0.3
	hc.height = (_pivot.position.y if not great else 2.0) + 0.4
	hs.shape = hc
	hs.position = Vector3(0, hc.height * 0.5 - (0.0 if not great else 2.0), 0)
	hurt.add_child(hs)
	_part(hurt)
	_light = OmniLight3D.new()
	_light.light_color = LIT
	_light.light_energy = 0.0
	_light.omni_range = 4.0
	_light.light_specular = 0.0
	_light.position = _pivot.position + Vector3.DOWN * 0.6 * s
	_part(_light)


func _part(n: Node) -> void:
	n.set_meta(&"bell_part", true)
	add_child(n, false, Node.INTERNAL_MODE_FRONT)


## A wave with `crests` crests across a plaque (centered `at`, `width` wide,
## `height` tall), drawn on its front (+Z, face 1) or back (face -1).
static func _wave(mb: MeshBuilder, at: Vector3, width: float, height: float, crests: int, face: float) -> void:
	var n := maxi(crests, 1) * 8
	var prev := Vector3.ZERO
	for i in n + 1:
		var u := float(i) / n
		var p := at + Vector3((u - 0.5) * width, -cos(u * TAU * maxi(crests, 1)) * height * 0.5, 0)
		if i > 0:
			var mid := (prev + p) * 0.5
			var d := p - prev
			var basis := Basis(Vector3.BACK, atan2(d.y, d.x))
			mb.box(Vector3(d.length() + 0.03, 0.05, 0.02), Transform3D(basis, mid), WAVE)
		prev = p


func take_hit(hit: Dictionary) -> void:
	var from: Vector3 = hit.get("direction", -global_basis.z)
	ring(from)


func on_cannon_hit(ball: Node) -> void:
	var dir := -global_basis.z
	if ball is Node3D:
		dir = Player.flat(global_position - (ball as Node3D).global_position).normalized()
	ring(dir)


func on_ground_pound(player: Node3D) -> void:
	if Player.flat(player.global_position - global_position).length() < 3.2:
		ring(Player.flat(global_position - player.global_position).normalized())


## Swings the bell away from `from_dir` and sounds its note.
func ring(from_dir := Vector3.ZERO) -> void:
	if _cool > 0.0:
		return
	_cool = 0.45
	var local := global_basis.inverse() * from_dir
	_swing_v += Vector2(-local.z, local.x).normalized() * 3.2 if local.length() > 0.01 else Vector2(3.2, 0)
	AudioManager.play(&"reef_bell", get_aim_point(), 2.0 if note == 0 else 0.0, pitch(), 0.0)
	VFX.ring(get_tree().current_scene, get_aim_point(), 1.2 * bell_size(), 16, Color(1, 0.92, 0.6, 0.85))
	rung.emit(self)


## Glows while it's part of the song being played.
func set_lit(on: bool) -> void:
	if lit == on:
		return
	lit = on
	if _light == null:
		return
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 2.2 if on else 0.0, 0.25)
	if on:
		VFX.sparkle(get_tree().current_scene, get_aim_point(), LIT, 14, 3.5)


## A brief glow (the great bell playing the song through the reef bells).
func pulse() -> void:
	pulsed.emit(self)
	if _light == null:
		return
	var tw := create_tween()
	tw.tween_property(_light, "light_energy", 2.6, 0.1)
	tw.tween_property(_light, "light_energy", 2.2 if lit else 0.0, 0.5)
	_swing_v += Vector2(1.6, 0)


func _process(delta: float) -> void:
	_cool = maxf(_cool - delta, 0.0)
	if _pivot == null:
		return
	# A damped spring: the bell swings and settles.
	_swing_v += -_swing * 18.0 * delta
	_swing_v *= maxf(0.0, 1.0 - 2.2 * delta)
	_swing += _swing_v * delta
	_pivot.rotation = Vector3(_swing.x, 0, _swing.y)
