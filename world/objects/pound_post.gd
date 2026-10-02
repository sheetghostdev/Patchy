@tool
class_name PoundPost
extends StaticBody3D
## A wooden mooring post that sticks up out of the ground. Ground-pound it
## (or hit it with something heavy) to drive it down. Used for physical
## puzzles (spec §23, §126): drive in every post to release a chained chest.

signal pounded(post: PoundPost)

@export var post_id: StringName = &""
@export_range(0.4, 3.0, 0.05) var post_height := 1.1

var down := false
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"wood")
	_mesh = MeshInstance3D.new()
	var mb := MeshBuilder.new()
	mb.cylinder(0.32, 0.36, post_height, Transform3D(Basis.IDENTITY, Vector3(0, post_height * 0.5, 0)), Palette.WOOD, 12)
	mb.cylinder(0.36, 0.34, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, post_height, 0)), Palette.WOOD.lightened(0.15), 12)
	mb.torus(0.31, 0.39, Transform3D(Basis.IDENTITY, Vector3(0, post_height * 0.7, 0)), Palette.METAL, 14, 4)
	mb.torus(0.31, 0.39, Transform3D(Basis.IDENTITY, Vector3(0, post_height * 0.25, 0)), Palette.METAL, 14, 4)
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.36
	cyl.height = post_height
	cs.shape = cyl
	cs.position = Vector3(0, post_height * 0.5, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	if not Engine.is_editor_hint() and post_id != &"" and WorldState.is_completed(post_id):
		_set_down(false)


func on_ground_pound(player: Node3D) -> void:
	if down:
		return
	var d := Player.flat(player.global_position - global_position).length()
	if d > 0.9 and player.global_position.y < global_position.y + post_height - 0.2:
		return
	_set_down(true)


func take_hit(hit: Dictionary) -> void:
	if hit.get("kind", &"") in [&"cannon", &"explosion", &"shell"]:
		_set_down(true)


func _set_down(with_fx: bool) -> void:
	down = true
	if post_id != &"":
		WorldState.mark_completed(post_id)
	var target := -post_height + 0.18
	if with_fx:
		AudioManager.play(&"switch_click", global_position)
		AudioManager.play(&"ground_pound_impact", global_position, -6.0)
		VFX.ring(self, global_position, 1.0, 10)
		var tw := create_tween()
		tw.tween_property(self, "position:y", position.y + target, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pounded.emit(self)
	else:
		position.y += target
