@tool
class_name SugarPlug
extends StaticBody3D
## A giant sugar cube jammed in a SteamVent (Teacup Isle). Yank it out with
## the grapple (or knock it loose with a cannonball): it tumbles away,
## dissolves, and the vent blows. Persistent by plug_id.

@export var plug_id: StringName = &""
@export var vent: SteamVent

const SIZE := 1.5

var _mesh: MeshInstance3D
var _gone := false


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"stone")
	_mesh = MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.rounded_box(Vector3.ONE * SIZE, 0.12, Transform3D(Basis(Vector3.UP, 0.3), Vector3(0, SIZE * 0.5, 0)), HorizonTeacupIsle.SUGAR, 2)
	for k in 6:
		mb.box(Vector3(0.12, 0.12, 0.12), Transform3D(Basis(Vector3.UP, k), Vector3(sin(k * 2.3) * 0.5, SIZE + 0.02, cos(k * 1.9) * 0.5)), Color("ffffff"))
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"glossy"))
	add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * SIZE
	cs.shape = box
	cs.position = Vector3(0, SIZE * 0.5, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	add_to_group(&"grapple_pull")
	add_to_group(&"cannon_target")
	if plug_id != &"" and WorldState.is_completed(plug_id):
		_gone = true
		if vent != null:
			vent.open = true
		queue_free()


## Just over the top of the cube: where the grapple bites (aimed from the
## hand, a line of sight that clears the cube's near edge).
func get_anchor_position() -> Vector3:
	return global_position + Vector3.UP * (SIZE + 0.5)


func get_aim_point() -> Vector3:
	return get_anchor_position()


func on_grapple_pull(player: Node3D) -> void:
	_pop(Player.flat(player.global_position - global_position).normalized())


func on_cannon_hit(ball: Node) -> void:
	var away := Vector3.FORWARD
	if ball is Node3D:
		away = Player.flat(global_position - (ball as Node3D).global_position).normalized()
	_pop(away)


func _pop(toward: Vector3) -> void:
	if _gone:
		return
	_gone = true
	if plug_id != &"":
		WorldState.mark_completed(plug_id)
	remove_from_group(&"grapple_pull")
	remove_from_group(&"cannon_target")
	collision_layer = 0
	AudioManager.play(&"crate_break", global_position, -2.0, 1.4)
	if vent != null:
		vent.unplug()
	var tw := create_tween()
	var dest := global_position + toward * 2.2 + Vector3.UP * 0.2
	tw.tween_property(self, "global_position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_mesh, "rotation", Vector3(1.2, 0.8, 0.3), 0.35)
	tw.tween_interval(0.4)
	tw.tween_callback(func() -> void: VFX.dust(get_tree().current_scene, global_position + Vector3.UP * 0.6, 10, 0.5, Color(1, 1, 1, 0.9), 1.4, 1.0))
	tw.tween_property(self, "scale", Vector3.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
