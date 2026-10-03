@tool
class_name RisingDais
extends AnimatableBody3D
## A round stone dais that rises out of the water when its puzzle is solved
## (Bell Atoll's song), carrying whatever stands on it (a chest, a cage).
## The node sits where it ends up; until raised it waits `drop` m below.
## Persistent by `raised_id`.

signal raised

@export var raised_id: StringName = &""
@export var radius := 3.4
@export var drop := 5.0
@export var rise_time := 3.0

var is_raised := false
var _top := Vector3.ZERO


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	sync_to_physics = true
	set_meta(&"surface", &"stone")
	var mb := MeshBuilder.new()
	var stone := Color("d9cbb2")
	mb.cylinder(radius, radius * 1.08, 6.0, Transform3D(Basis.IDENTITY, Vector3(0, -3.0, 0)), stone.darkened(0.1), 16)
	mb.cylinder(radius * 1.06, radius * 1.06, 0.3, Transform3D(Basis.IDENTITY, Vector3(0, -0.15, 0)), stone, 16)
	for k in 8:
		var a := TAU * k / 8.0
		mb.box(Vector3(0.5, 0.18, 0.5), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a), 0, sin(a)) * (radius - 0.4) + Vector3(0, 0.05, 0)), Color("4fa5e8"))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius * 1.06
	cyl.height = 6.0
	cs.shape = cyl
	cs.position = Vector3(0, -3.0, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	_top = position
	if raised_id != &"" and WorldState.is_completed(raised_id):
		is_raised = true
		return
	position = _top + Vector3.DOWN * drop


## Brings it up out of the water (or snaps it there with `animate` off).
func raise(animate := true) -> void:
	if is_raised:
		return
	is_raised = true
	if raised_id != &"":
		WorldState.mark_completed(raised_id)
	if not animate:
		position = _top
		raised.emit()
		return
	AudioManager.play(&"splash_big", global_position + Vector3.UP * drop)
	Events.camera_impulse.emit(0.3)
	var tw := create_tween()
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "position", _top, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished
	VFX.splash(get_tree().current_scene, global_position, 2.0)
	raised.emit()
