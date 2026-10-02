@tool
class_name ShipPartPickup
extends Area3D
## A piece of Patchy's ship (spec §78–82): the main story currency. Big,
## glowing and impossible to miss; collecting it is a celebration and it
## shows up on the rebuilt ship later. Persistent by part_id.

@export var part_id: StringName = &"compass"
@export var display_name := "Ship's Compass"

var _visual: Node3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = Layers.COLLECTIBLE
	collision_mask = Layers.PLAYER
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.0
	cs.shape = sph
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	_visual = Node3D.new()
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var gl := MeshBuilder.new()
	# A chunky brass compass: case, glass dome, star and needle.
	var upright := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	mb.cylinder(0.6, 0.6, 0.18, Transform3D(upright, Vector3.ZERO), Palette.BRASS, 24)
	mb.torus(0.55, 0.68, Transform3D(upright, Vector3.ZERO), Palette.BRASS.lightened(0.15), 24, 6)
	mb.torus(0.07, 0.13, Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0)), Palette.BRASS, 12, 6)
	gl.cylinder(0.5, 0.5, 0.02, Transform3D(upright, Vector3(0, 0, -0.1)), Color("fff3d6"), 24)
	gl.box(Vector3(0.08, 0.8, 0.03), Transform3D(Basis.from_euler(Vector3(0, 0, 0.5)), Vector3(0, 0, -0.12)), Palette.COAT)
	gl.box(Vector3(0.8, 0.08, 0.03), Transform3D(Basis.from_euler(Vector3(0, 0, 0.5)), Vector3(0, 0, -0.12)), Palette.HAT)
	var mesh := ArrayMesh.new()
	mb.build(mesh, MaterialLibrary.toon(Color.WHITE, &"metal"))
	gl.build(mesh, MaterialLibrary.toon(Color.WHITE, &"glossy"))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_visual.add_child(mi)
	var light := OmniLight3D.new()
	light.light_specular = 0.0  # no cel glint discs on nearby walls
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 1.4
	light.omni_range = 4.0
	_visual.add_child(light)
	if Engine.is_editor_hint():
		return
	if InventoryManager.has_ship_part(part_id):
		queue_free()
		return
	add_to_group(&"look_at_target")
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	_t += delta
	if _visual != null and not _taken:
		_visual.rotation.y = _t * 1.4
		_visual.position.y = 0.4 + sin(_t * 2.0) * 0.15


func _on_body(body: Node3D) -> void:
	if _taken or not body is Player:
		return
	_taken = true
	var p := body as Player
	InventoryManager.add_ship_part(part_id)
	AudioManager.play(&"treasure_big", global_position)
	AudioManager.play_stinger(&"stinger_treasure")
	VFX.sparkle(self, global_position + Vector3.UP * 0.5, Palette.GOLD, 30, 6.0)
	Events.hud_message.emit("Recovered: %s!" % display_name, 3.0)
	if p.state_id == &"ground":
		p.set_locked(true, {"anim": &"cheer"})
	var tw := create_tween()
	tw.tween_property(_visual, "position:y", 2.4, 0.5).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(_visual, "scale", Vector3.ONE * 1.4, 0.5)
	tw.tween_property(_visual, "scale", Vector3.ZERO, 0.3)
	await tw.finished
	await get_tree().create_timer(0.6, false).timeout
	if is_instance_valid(p) and p.state_id == &"locked":
		p.set_locked(false)
	queue_free()
