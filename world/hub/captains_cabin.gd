class_name CaptainsCabin
extends Node3D
## The captain's cabin in the wreck of the Patchy (spec §79–84): the hub
## where progress is on display. It rebuilds itself from the managers every
## visit:
##  - a gold pile that grows with Patchy's riches;
##  - a pedestal per unique treasure (gems in their colors, goblets,
##    crowns, relics);
##  - a perch with every rescued parrot;
##  - the recovered ship parts on the shelf (silhouettes until found);
##  - the hand attachments hung on the wall rack.

## Where things go (cabin space; set by the builder).
@export var pile_spot: Marker3D
@export var pedestal_row: Marker3D
@export var perch: Marker3D
@export var parts_shelf: Marker3D
@export var rack: Marker3D

const PEDESTALS := 10

var _spinners: Array[Node3D] = []
var _birds: Array[ParrotModel] = []
var _t := 0.0


func _ready() -> void:
	await get_tree().process_frame
	_build_pile()
	_build_pedestals()
	_build_perch()
	_build_parts()
	_build_rack()


func _process(delta: float) -> void:
	_t += delta
	for i in _spinners.size():
		var s := _spinners[i]
		if is_instance_valid(s):
			s.rotation.y = _t * 1.2 + i
			s.position.y = 0.95 + sin(_t * 2.0 + i) * 0.06
	for i in _birds.size():
		var bird := _birds[i]
		# Now and then a parrot ruffles its wings.
		var ph := fmod(_t * 0.4 + i * 0.37, 1.0)
		bird.set_flap(1.0 if ph < 0.06 else 0.0)


func _build_pile() -> void:
	if pile_spot == null:
		return
	var gold := InventoryManager.gold_value
	if gold <= 0:
		return
	var pile := TreasureDisplay.new()
	pile.kind = TreasureDisplay.Kind.PILE
	pile.count = clampi(3 + gold / 3, 3, 80)
	pile.seed = 3
	pile_spot.add_child(pile)
	var lab := _label("%d gold" % gold, Vector3(0, 1.6, 0))
	pile_spot.add_child(lab)


func _build_pedestals() -> void:
	if pedestal_row == null:
		return
	var treasures := InventoryManager.get_treasures()
	for i in PEDESTALS:
		var slot := Node3D.new()
		slot.position = Vector3(i * 1.15, 0, 0)
		pedestal_row.add_child(slot)
		var mb := MeshBuilder.new()
		mb.cylinder(0.32, 0.38, 0.7, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), Palette.WOOD_DARK, 10)
		mb.cylinder(0.4, 0.4, 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.72, 0)), Palette.BRASS, 12)
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		slot.add_child(mi)
		if i >= treasures.size():
			continue
		var t: Dictionary = treasures[i]
		var color := Color.from_string(String(t.get("color", "ffffff")), Color.WHITE)
		var shown := MeshInstance3D.new()
		shown.mesh = TreasureMeshes.get_mesh(StringName(t.get("kind", "gem")), color)
		shown.scale = Vector3.ONE * (1.3 if String(t.get("kind", "")) in ["crown", "relic", "goblet"] else 1.6)
		var spinner := Node3D.new()
		spinner.position = Vector3(0, 0.95, 0)
		spinner.add_child(shown)
		slot.add_child(spinner)
		_spinners.append(spinner)


func _build_perch() -> void:
	if perch == null:
		return
	var ids := ParrotManager.get_rescued_ids()
	for i in ids.size():
		var bird := ParrotModel.new()
		bird.plumage = ((absi(String(ids[i]).hash()) % 5) as ParrotModel.Plumage)
		bird.position = Vector3(i * 0.7, 0.05, 0)
		bird.rotation_degrees.y = 180.0 + randf_range(-20.0, 20.0)
		perch.add_child(bird)
		bird.set_folded()
		_birds.append(bird)


func _build_parts() -> void:
	if parts_shelf == null:
		return
	var parts := ShipParts.ids()
	for i in parts.size():
		var id: StringName = parts[i]
		var owned := InventoryManager.has_ship_part(id)
		var holder := Node3D.new()
		holder.position = Vector3(i * 1.3, 0, 0)
		parts_shelf.add_child(holder)
		var mi := MeshInstance3D.new()
		mi.mesh = _part_mesh(id, owned)
		holder.add_child(mi)
		if owned:
			var lab := _label(ShipParts.display_name(id).trim_prefix("Ship's "), Vector3(0, -0.35, 0.3))
			lab.font_size = 28
			holder.add_child(lab)


static func _part_mesh(id: StringName, owned: bool) -> ArrayMesh:
	var mb := MeshBuilder.new()
	var up := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	var c := Palette.BRASS if owned else Color(0.16, 0.13, 0.11)
	var wood := Palette.WOOD if owned else Color(0.14, 0.11, 0.09)
	match id:
		&"compass":
			mb.cylinder(0.32, 0.32, 0.1, Transform3D(up, Vector3(0, 0.35, 0)), c, 18)
			mb.torus(0.28, 0.36, Transform3D(up, Vector3(0, 0.35, 0)), c.lightened(0.1), 18, 5)
		&"ships_wheel":
			mb.torus(0.34, 0.42, Transform3D(up, Vector3(0, 0.5, 0)), wood, 20, 6)
			mb.cylinder(0.08, 0.08, 0.12, Transform3D(up, Vector3(0, 0.5, 0)), c, 10)
			for k in 8:
				var a := TAU * k / 8.0
				mb.cylinder(0.025, 0.03, 0.62, Transform3D(Basis.from_euler(Vector3(0, 0, a)), Vector3(0, 0.5, 0)) * Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0)), wood, 5)
		_:
			# Unknown parts: a covered shape with a question mark.
			mb.rounded_box(Vector3(0.6, 0.6, 0.3), 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.35, 0)), Color(0.18, 0.15, 0.13), 2)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal" if owned else &"matte"))


func _build_rack() -> void:
	if rack == null:
		return
	var i := 0
	for id in InventoryManager.get_attachments():
		var path := "res://resources/attachments/%s.tres" % id
		if not ResourceLoader.exists(path):
			continue
		var data := load(path) as AttachmentData
		if data == null or data.scene == null:
			continue
		var hook := Node3D.new()
		hook.position = Vector3(i * 1.45, 0, 0)
		rack.add_child(hook)
		var peg := MeshBuilder.new()
		peg.cylinder(0.03, 0.03, 0.2, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 0.05, 0.1)), Palette.WOOD_DARK, 6)
		var pm := MeshInstance3D.new()
		pm.mesh = peg.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		hook.add_child(pm)
		var shown := data.scene.instantiate() as Node3D
		shown.scale = Vector3.ONE * 1.4
		shown.position = Vector3(0, 0.0, 0.18)
		hook.add_child(shown)
		var lab := _label(data.display_name, Vector3(0, -0.95 - 0.12 * (i % 2), 0.2))
		lab.font_size = 22
		hook.add_child(lab)
		i += 1


func _label(text: String, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.005
	l.outline_size = 10
	l.modulate = Palette.GOLD.lightened(0.2)
	l.outline_modulate = Color(0.2, 0.1, 0.05)
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return l
