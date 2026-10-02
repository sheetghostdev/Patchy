@tool
class_name CrabBurrow
extends StaticBody3D
## A sandy crab hole where thieves stash stolen treasure (spec §172). Stolen
## coins are never lost: ground-pound the burrow to pop them back out.

@export var starting_stash := 0

var stash_value := 0


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	stash_value = starting_stash
	var mb := MeshBuilder.new()
	mb.ellipsoid(Vector3(0.9, 0.28, 0.9), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), Palette.SAND_DARK, 8, 14)
	mb.cylinder(0.32, 0.4, 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.27, 0)), Color("3b2a1e"), 14)
	for k in 5:
		var a := TAU * k / 5.0
		mb.sphere(0.12, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.75, 0.12, sin(a) * 0.75)), Palette.SAND, 4, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.8
	cyl.height = 0.3
	cs.shape = cyl
	cs.position = Vector3(0, 0.1, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	set_meta(&"surface", &"sand")


func stash(value: int) -> void:
	stash_value += value


func on_ground_pound(_player: Node3D) -> void:
	if stash_value <= 0:
		VFX.dust(self, global_position + Vector3.UP * 0.3, 6, 0.4, Color(0.98, 0.9, 0.7, 0.9), 1.5)
		return
	AudioManager.play(&"shovel_find", global_position)
	VFX.sparkle(self, global_position + Vector3.UP * 0.5, Palette.GOLD, 14)
	var count := stash_value
	stash_value = 0
	for i in count:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		get_tree().current_scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.6
