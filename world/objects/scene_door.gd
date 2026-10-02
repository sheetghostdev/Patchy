@tool
class_name SceneDoor
extends Interactable
## A door (or hatch, or ladder) to another scene (spec §181). "[E] Enter":
## Patchy turns to it and the iris closes on the door; the next scene puts
## him at the spawn point with the matching id.

@export_file("*.tscn") var target_scene := ""
@export var spawn_id: StringName = &""
@export var label := "Enter"
@export var door_size := Vector2(1.4, 2.3):
	set(v):
		door_size = v
		_build()
## Draw a wooden door with a frame (off for invisible exits).
@export var show_door := true:
	set(v):
		show_door = v
		_build()

var _visual: Node3D


func _ready() -> void:
	prompt = "{interact} %s" % label
	radius = 1.6
	super._ready()
	_build()


func _build() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.free()
		_visual = null
	if not show_door:
		return
	_visual = Node3D.new()
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var w := door_size.x
	var h := door_size.y
	mb.box(Vector3(w, h, 0.12), Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5, 0)), Palette.WOOD_DARK)
	for k in 4:
		var x := -w * 0.5 + (k + 0.5) * w / 4.0
		mb.box(Vector3(0.03, h - 0.1, 0.13), Transform3D(Basis.IDENTITY, Vector3(x, h * 0.5, 0.005)), Palette.WOOD_DARK.darkened(0.25))
	for y: float in [0.25, 0.75]:
		mb.box(Vector3(w - 0.08, 0.12, 0.16), Transform3D(Basis.IDENTITY, Vector3(0, h * y, 0.01)), Palette.METAL)
	mb.box(Vector3(0.16, h + 0.16, 0.2), Transform3D(Basis.IDENTITY, Vector3(-w * 0.5 - 0.08, h * 0.5, 0)), Palette.WOOD)
	mb.box(Vector3(0.16, h + 0.16, 0.2), Transform3D(Basis.IDENTITY, Vector3(w * 0.5 + 0.08, h * 0.5, 0)), Palette.WOOD)
	mb.box(Vector3(w + 0.32, 0.16, 0.2), Transform3D(Basis.IDENTITY, Vector3(0, h + 0.08, 0)), Palette.WOOD)
	mb.sphere(0.06, Transform3D(Basis.IDENTITY, Vector3(w * 0.3, h * 0.48, 0.1)), Palette.BRASS, 4, 6)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_visual.add_child(mi)
	# The closed door is solid.
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.32, h + 0.16, 0.2)
	cs.shape = box
	cs.position = Vector3(0, (h + 0.16) * 0.5, 0)
	body.add_child(cs)
	_visual.add_child(body)


func interact(player: Node3D) -> void:
	super.interact(player)
	if target_scene == "" or SceneTransition.is_busy():
		return
	var p := player as Player
	if p != null:
		p.set_locked(true, {"anim": &"walk", "face": -global_basis.z})
	AudioManager.play(&"door_open", global_position)
	SceneTransition.change_scene(target_scene, spawn_id)
