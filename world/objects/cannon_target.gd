@tool
class_name CannonTarget
extends StaticBody3D
## A red-and-white bullseye on a post (spec §59 cannon puzzles). A cannonball
## knocks it flat with a "ding"; any Gate listing it opens when all of its
## triggers are down. Persistent by target_id.

signal activated

@export var target_id: StringName = &""

var _board: Node3D
var _down := false


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	var post := MeshBuilder.new()
	post.cylinder(0.08, 0.1, 1.6, Transform3D(Basis.IDENTITY, Vector3(0, 0.8, 0)), Palette.WOOD_DARK, 8)
	var pm := MeshInstance3D.new()
	pm.mesh = post.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(pm, false, Node.INTERNAL_MODE_FRONT)
	_board = Node3D.new()
	_board.position = Vector3(0, 1.6, 0)
	add_child(_board, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var face := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var colors := [Color("e23b2e"), Color("fff4e0"), Color("e23b2e"), Color("fff4e0"), Color("e23b2e")]
	for k in colors.size():
		var r := 0.62 - k * 0.12
		mb.cylinder(r, r, 0.06 + k * 0.012, Transform3D(face, Vector3(0, 0.62, 0)), colors[k], 20)
	var bm := MeshInstance3D.new()
	bm.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_board.add_child(bm)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.3, 2.9, 0.3)
	cs.shape = box
	cs.position = Vector3(0, 1.45, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if Engine.is_editor_hint():
		return
	add_to_group(&"cannon_target")
	if target_id != &"" and WorldState.is_completed(target_id):
		_down = true
		_board.rotation.x = -PI * 0.5
		remove_from_group(&"cannon_target")


## Where to aim: the middle of the bullseye.
func get_aim_point() -> Vector3:
	return _board.global_position + _board.global_basis.y * 0.62


func on_cannon_hit(_ball: Node) -> void:
	if _down:
		return
	_down = true
	remove_from_group(&"cannon_target")
	if target_id != &"":
		WorldState.mark_completed(target_id)
	AudioManager.play(&"bell_ring", global_position + Vector3.UP * 2.0)
	VFX.sparkle(get_tree().current_scene, global_position + Vector3.UP * 2.2, Palette.GOLD, 12)
	var tw := create_tween()
	tw.tween_property(_board, "rotation:x", -PI * 0.5, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	activated.emit()


func is_active() -> bool:
	return _down
