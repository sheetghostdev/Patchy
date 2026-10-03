@tool
class_name PinwheelLift
extends Node3D
## Pinwheel Isle's screw lifts (docs/ARCHIPELAGO.md): a red-and-white pole
## with a wooden screw thread, a big pinwheel at the top and a round
## platform at the bottom. Get the wheel spinning (a cannonball, a yank of
## the grapple, or the hook if you can reach it) and the platform
## corkscrews up the pole while it spins; as the wheel runs down it sinks
## back. Stand on the platform and spin the wheel above you to ride up.
## The node sits at the platform's lowest stop (its top surface); the wheel
## faces the node's -Z.

signal spun

const PITCH := 9.0
const RISE := 2.4
const FALL := 1.3
## Seconds a full spin lasts.
const SPIN_TIME := 11.0
const PLATFORM_R := 1.8

@export var travel := 6.0:
	set(v):
		travel = v
		_rebuild()
@export var pole_extra := 4.0:
	set(v):
		pole_extra = v
		_rebuild()
@export var wheel_radius := 2.6:
	set(v):
		wheel_radius = v
		_rebuild()
## Picks the blades' colors.
@export var colors := 0

## How hard the wheel is spinning, 0..1.
var power := 0.0
## The platform's height above its lowest stop.
var height := 0.0
var platform: AnimatableBody3D
var _wheel: Node3D
var _spinner: Node3D
var _turn := 0.0
var _was_top := false


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"cannon_target")
	add_to_group(&"grapple_pull")
	add_to_group(&"pinwheel_lift")


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta(&"lift_part", false):
			c.queue_free()
	var pole_h := travel + pole_extra + 0.3
	# The pole and its screw thread.
	var mb := PropBuilder.new()
	HorizonPinwheelIsle._pole(mb, Vector3.DOWN * 0.3, pole_h, 0.42)
	var pts := PackedVector3Array()
	var turns := maxf((travel + 0.6) / PITCH, 0.5)
	var n := int(turns * 16.0)
	for i in n + 1:
		var t := float(i) / n
		var a := t * TAU * turns
		pts.append(Vector3(cos(a) * 0.5, -0.2 + t * (travel + 0.6), sin(a) * 0.5))
	mb.tube(pts, PackedFloat32Array([0.12]), HorizonPinwheelIsle.WOOD, 4, false)
	mb.flat_shade()
	var pole_mi := MeshInstance3D.new()
	pole_mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_part(pole_mi)
	# Solid to Patchy, but not to aim rays (grapple, cannon) that skim it.
	var pole_body := StaticBody3D.new()
	pole_body.collision_layer = Layers.PROPS
	pole_body.collision_mask = 0
	var pcs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = pole_h
	pcs.shape = cyl
	pcs.position = Vector3(0, pole_h * 0.5 - 0.3, 0)
	pole_body.add_child(pcs)
	_part(pole_body)
	# The platform.
	platform = AnimatableBody3D.new()
	platform.collision_layer = Layers.WORLD
	platform.collision_mask = 0
	platform.sync_to_physics = true
	platform.set_meta(&"surface", &"wood")
	var dm := MeshBuilder.new()
	var wood := Color("b58456")
	dm.cylinder(PLATFORM_R, PLATFORM_R, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, -0.25, 0)), wood, 16)
	dm.cylinder(PLATFORM_R + 0.08, PLATFORM_R + 0.08, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, -0.06, 0)), wood.darkened(0.25), 16)
	for k in 6:
		var a := TAU * k / 6.0
		dm.box(Vector3(0.08, 0.02, PLATFORM_R * 2.0 - 0.2), Transform3D(Basis(Vector3.UP, a), Vector3(0, 0.005, 0)), wood.darkened(0.2))
	dm.cylinder(0.62, 0.66, 0.6, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Color("8a6a46"), 10)
	var dmi := MeshInstance3D.new()
	dmi.mesh = dm.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	platform.add_child(dmi)
	var dcs := CollisionShape3D.new()
	var dcyl := CylinderShape3D.new()
	dcyl.radius = PLATFORM_R
	dcyl.height = 0.5
	dcs.shape = dcyl
	dcs.position = Vector3(0, -0.25, 0)
	platform.add_child(dcs)
	_part(platform)
	# The wheel at the top, out front of the pole.
	_spinner = Node3D.new()
	_spinner.position = Vector3(0, pole_h - 0.3 + 0.3, -0.9)
	_part(_spinner)
	_wheel = Node3D.new()
	_spinner.add_child(_wheel)
	var wm := MeshInstance3D.new()
	wm.mesh = HorizonPinwheelIsle.wheel_mesh(wheel_radius, colors).build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_wheel.add_child(wm)
	var axle := MeshBuilder.new()
	axle.cylinder(0.12, 0.12, 1.0, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0, 0.5)), Palette.METAL, 6)
	var am := MeshInstance3D.new()
	am.mesh = axle.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	_spinner.add_child(am)
	var hurt := Area3D.new()
	hurt.collision_layer = Layers.INTERACTABLE
	hurt.collision_mask = 0
	hurt.monitoring = false
	var hs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = wheel_radius * 0.75
	hs.shape = sph
	hurt.add_child(hs)
	_spinner.add_child(hurt)
	_place_platform()


func _part(n: Node) -> void:
	n.set_meta(&"lift_part", true)
	add_child(n, false, Node.INTERNAL_MODE_FRONT)


## The wheel's hub (where the cannon aims and the grapple bites).
func get_aim_point() -> Vector3:
	return _spinner.global_position if _spinner != null else global_position + Vector3.UP * (travel + pole_extra)


func get_anchor_position() -> Vector3:
	return get_aim_point()


## The platform's top surface, where Patchy stands.
func platform_top() -> Vector3:
	return global_position + Vector3.UP * height


func is_at_top() -> bool:
	return height >= travel - 0.01


## Gives the wheel a turn: `amount` of a full spin (more spins faster).
func spin(amount := 0.65) -> void:
	power = minf(power + amount, 1.0)
	AudioManager.play(&"wood_creak", get_aim_point(), -2.0, 1.4)
	AudioManager.play(&"sail_flap", get_aim_point(), -4.0, 1.3)
	spun.emit()


func on_cannon_hit(_ball: Node) -> void:
	spin(0.75)


func on_grapple_pull(_player: Node3D) -> void:
	spin(0.75)


func take_hit(_hit: Dictionary) -> void:
	spin(0.5)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or platform == null:
		return
	if power > 0.0:
		height = minf(height + RISE * power * delta, travel)
		power = maxf(power - delta / SPIN_TIME, 0.0)
	else:
		height = maxf(height - FALL * delta, 0.0)
	var top := is_at_top()
	if top and not _was_top:
		AudioManager.play(&"switch_click", platform_top(), -4.0, 0.9)
	_was_top = top
	_place_platform()


func _place_platform() -> void:
	if platform == null:
		return
	platform.transform = Transform3D(Basis(Vector3.UP, height / PITCH * TAU), Vector3.UP * height)


func _process(delta: float) -> void:
	if _wheel == null:
		return
	# A lazy turn in the breeze, a whirl when spun.
	_turn += delta * (0.5 + 11.0 * power)
	_wheel.rotation.z = _turn
