@tool
class_name CrackedRock
extends StaticBody3D
## Rock with a glaring crack (spec §59): a cannonball (or another blast)
## shatters it to reveal what it hid. Persistent by rock_id.

signal shattered

@export var rock_id: StringName = &""
@export var size := Vector3(3.0, 3.0, 1.2):
	set(v):
		size = v
		_rebuild()
## What it's made of: cracked rock, or a wall of sugar cubes (Teacup Isle).
@export_enum("rock", "sugar") var look := "rock":
	set(v):
		look = v
		_rebuild()

var _mesh: MeshInstance3D
var _col: CollisionShape3D


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"stone")
	_rebuild()
	if Engine.is_editor_hint():
		return
	if rock_id != &"" and WorldState.is_completed(rock_id):
		queue_free()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _mesh == null:
		_mesh = MeshInstance3D.new()
		add_child(_mesh, false, Node.INTERNAL_MODE_FRONT)
		_col = CollisionShape3D.new()
		add_child(_col, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var rock := Color("bba78c")
	if look == "sugar":
		# Cubes stacked like bricks.
		var cube := 1.0
		var rows := maxi(1, int(round(size.y / cube)))
		var cols := maxi(1, int(round(size.x / cube)))
		for r in rows:
			for c in cols + 1:
				var x := -size.x * 0.5 + (c + (0.5 if r % 2 == 0 else 0.0)) * size.x / cols
				if x - cube * 0.5 < -size.x * 0.5 - 0.01 or x + cube * 0.5 > size.x * 0.5 + 0.01:
					continue
				mb.rounded_box(Vector3(cube * 0.96, cube * 0.96, size.z), 0.1, Transform3D(Basis(Vector3.UP, sin(r * 3.1 + c) * 0.06), Vector3(x, (r + 0.5) * size.y / rows, 0)), HorizonTeacupIsle.SUGAR.darkened(fposmod(r * 0.37 + c * 0.21, 1.0) * 0.06), 1)
		rock = HorizonTeacupIsle.SUGAR
	else:
		mb.rounded_box(size, minf(0.35, size.y * 0.2), Transform3D(Basis.IDENTITY, Vector3(0, size.y * 0.5, 0)), rock, 2)
	# The tell: a dark zigzag crack on both faces, wide enough to read at range.
	var pts := [Vector2(-0.05, 0.92), Vector2(0.12, 0.66), Vector2(-0.1, 0.45), Vector2(0.08, 0.22), Vector2(-0.04, 0.05)]
	for side: float in [-1.0, 1.0]:
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var pa := Vector3(a.x * size.x, a.y * size.y, side * (size.z * 0.5 + 0.01))
			var pb := Vector3(b.x * size.x, b.y * size.y, side * (size.z * 0.5 + 0.01))
			var mid := (pa + pb) * 0.5
			var len := pa.distance_to(pb)
			var ang := atan2(pb.x - pa.x, pb.y - pa.y)
			mb.box(Vector3(0.09, len + 0.06, 0.03), Transform3D(Basis.from_euler(Vector3(0, 0, -ang)), mid), Color("3d3026"))
		mb.box(Vector3(size.x * 0.22, 0.06, 0.03), Transform3D(Basis.from_euler(Vector3(0, 0, 0.4)), Vector3(size.x * 0.14, size.y * 0.55, side * (size.z * 0.5 + 0.01))), Color("3d3026"))
	_mesh.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	var box := BoxShape3D.new()
	box.size = size
	_col.shape = box
	_col.position = Vector3(0, size.y * 0.5, 0)


func on_cannon_hit(_ball: Node) -> void:
	shatter()


func shatter() -> void:
	if rock_id != &"":
		WorldState.mark_completed(rock_id)
	var scene := get_tree().current_scene
	AudioManager.play(&"explosion", global_position, -3.0, 0.8)
	VFX.dust(scene, global_position + Vector3.UP * size.y * 0.5, 16, 0.6, Color(0.8, 0.74, 0.64, 0.9), size.x, 1.5)
	Events.camera_impulse.emit(0.35)
	for i in 10:
		var chunk := MeshInstance3D.new()
		var cb := MeshBuilder.new()
		cb.box(Vector3.ONE * randf_range(0.25, 0.55), Transform3D.IDENTITY, (HorizonTeacupIsle.SUGAR if look == "sugar" else Color("bba78c")).darkened(randf() * 0.2))
		chunk.mesh = cb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		scene.add_child(chunk)
		chunk.global_position = global_position + Vector3(randf_range(-0.4, 0.4) * size.x, randf() * size.y, 0)
		var dest := chunk.global_position + Vector3(randf_range(-2.5, 2.5), -0.2, randf_range(-2.5, 2.5))
		dest.y = global_position.y + 0.15
		var tw := chunk.create_tween()
		tw.tween_property(chunk, "global_position", dest, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(chunk, "rotation", Vector3(randf() * 6, randf() * 6, randf() * 6), 0.5)
		tw.tween_interval(1.5)
		tw.tween_property(chunk, "scale", Vector3.ZERO, 0.4)
		tw.tween_callback(chunk.queue_free)
	shattered.emit()
	queue_free()
