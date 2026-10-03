@tool
class_name SongStone
extends StaticBody3D
## The sailor's song carved in stone by Bell Atoll's belfry: a row of waves,
## each with as many crests as the note of the bell to ring (the same waves
## are painted on the bells' plaques), read left to right.

@export var song := PackedInt32Array([4, 3, 5, 2, 1]):
	set(v):
		song = v
		_rebuild()
@export var title := "The Sailor's Song"


func _ready() -> void:
	collision_layer = Layers.WORLD
	collision_mask = 0
	set_meta(&"surface", &"stone")
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta(&"stone_part", false):
			c.queue_free()
	var w := 4.8
	var mb := MeshBuilder.new()
	var stone := Color("d9cbb2")
	mb.box(Vector3(w + 0.6, 0.5, 1.0), Transform3D(Basis.IDENTITY, Vector3(0, 0.25, 0)), stone.darkened(0.15))
	mb.box(Vector3(w, 2.0, 0.45), Transform3D(Basis.IDENTITY, Vector3(0, 1.5, 0)), stone)
	mb.box(Vector3(w + 0.2, 0.25, 0.55), Transform3D(Basis.IDENTITY, Vector3(0, 2.6, 0)), stone.darkened(0.08))
	var cell := (w - 0.4) / maxi(song.size(), 1)
	for i in song.size():
		# Read from the front (-Z), where +X is on the reader's left.
		var at := Vector3(w * 0.5 - 0.2 - cell * (i + 0.5), 1.25, -0.24)
		ReefBell._wave(mb, at, cell * 0.8, 0.42, song[i], -1.0)
		# A dot under each wave for the count, in case the eye slips.
		for d in song[i]:
			mb.sphere(0.045, Transform3D(Basis.IDENTITY, at + Vector3((d - (song[i] - 1) * 0.5) * 0.14, -0.42, 0)), ReefBell.WAVE, 3, 5)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_part(mi)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w + 0.6, 2.75, 1.0)
	cs.shape = box
	cs.position = Vector3(0, 1.375, 0)
	_part(cs)
	var label := Label3D.new()
	label.text = title
	label.font_size = 64
	label.pixel_size = 0.004
	label.modulate = Color("5b3a22")
	label.outline_size = 0
	label.position = Vector3(0, 2.1, -0.235)
	label.rotation.y = PI
	_part(label)


func _part(n: Node) -> void:
	n.set_meta(&"stone_part", true)
	add_child(n, false, Node.INTERNAL_MODE_FRONT)
