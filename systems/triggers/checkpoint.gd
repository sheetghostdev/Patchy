@tool
class_name Checkpoint
extends Area3D
## A small flagpole with Patchy's banner (spec §96). Touch it to raise the
## flag; falling or running out of hearts returns you here.

@export var checkpoint_id: StringName = &""
## Respawn facing (degrees around Y; 0 = -Z).
@export var respawn_yaw := 0.0

var _flag: Node3D
var _active := false


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = 3.0
	cs.shape = cyl
	cs.position = Vector3(0, 1.5, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_build()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		Events.checkpoint_reached.connect(_on_any_checkpoint)


func _build() -> void:
	var pole := MeshBuilder.new()
	pole.cylinder(0.05, 0.06, 2.6, Transform3D(Basis.IDENTITY, Vector3(0, 1.3, 0)), Palette.WOOD_DARK, 8)
	pole.sphere(0.09, Transform3D(Basis.IDENTITY, Vector3(0, 2.65, 0)), Palette.BRASS, 6, 8)
	pole.cylinder(0.32, 0.38, 0.2, Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)), Palette.STONE, 12)
	var mi := MeshInstance3D.new()
	mi.mesh = pole.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	_flag = Node3D.new()
	_flag.position = Vector3(0, 0.7, 0)
	add_child(_flag, false, Node.INTERNAL_MODE_FRONT)
	var cloth := MeshBuilder.new()
	cloth.rounded_box(Vector3(0.8, 0.5, 0.03), 0.02, Transform3D(Basis.IDENTITY, Vector3(0.45, 0, 0)), Palette.COAT, 1)
	cloth.sphere(0.12, Transform3D(Basis.from_scale(Vector3(1, 1, 0.3)), Vector3(0.45, 0.02, 0.0)), Palette.SHIRT, 6, 8)
	cloth.box(Vector3(0.2, 0.05, 0.05), Transform3D(Basis.IDENTITY, Vector3(0.45, 0.13, 0)), Palette.HAT)
	var fm := MeshInstance3D.new()
	fm.mesh = cloth.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_flag.add_child(fm)


func _process(_delta: float) -> void:
	if _flag != null and _active:
		_flag.rotation.y = sin(Time.get_ticks_msec() * 0.004) * 0.15


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or _active:
		return
	var xform := Transform3D(Basis(Vector3.UP, deg_to_rad(respawn_yaw)), global_position + Vector3.UP * 0.1)
	GameManager.set_checkpoint(checkpoint_id if checkpoint_id != &"" else StringName(name), xform)
	_raise()


func _raise() -> void:
	_active = true
	AudioManager.play(&"checkpoint", global_position)
	VFX.sparkle(self, global_position + Vector3.UP * 2.4, Palette.GOLD, 12)
	var tw := create_tween()
	tw.tween_property(_flag, "position:y", 2.2, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_any_checkpoint(id: StringName) -> void:
	# Lower this flag when another checkpoint becomes active.
	var mine := checkpoint_id if checkpoint_id != &"" else StringName(name)
	if id != mine and _active:
		_active = false
		create_tween().tween_property(_flag, "position:y", 0.7, 0.4)
