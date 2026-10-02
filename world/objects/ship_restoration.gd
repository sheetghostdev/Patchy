class_name ShipRestoration
extends Node3D
## The wreck of the Patchy, put back together piece by piece (spec §79):
## every recovered ship part appears where it belongs on deck. The Ship's
## Wheel stands at the helm, where Patchy can take the wheel to open the sea
## chart and sail for any known dock (spec §118, "Patchy's restored ship");
## the Ship's Compass sits in its brass binnacle in front of it.

## Where the wheel stands; its -Z faces the bow.
@export var helm: Marker3D
@export var binnacle: Marker3D

var _wheel: Node3D
var _spinner: Node3D
var _compass: Node3D
var _card: Node3D
var _use: Interactable
var _spin := 0.0
var _t := 0.0


func _ready() -> void:
	if helm != null:
		_wheel = _build_helm()
		helm.add_child(_wheel)
	if binnacle != null:
		_compass = _build_binnacle()
		binnacle.add_child(_compass)
	_refresh(false)
	Events.ship_part_recovered.connect(func(_id: StringName) -> void: _refresh(true))


func _refresh(celebrate: bool) -> void:
	for d: Array in [[_wheel, &"ships_wheel"], [_compass, &"compass"]]:
		var n: Node3D = d[0]
		if n == null:
			continue
		var has := InventoryManager.has_ship_part(d[1])
		if has and not n.visible and celebrate:
			VFX.sparkle(get_tree().current_scene, n.global_position + Vector3.UP * 1.0, Palette.GOLD, 16, 3.0)
		n.visible = has
		n.process_mode = Node.PROCESS_MODE_INHERIT if has else Node.PROCESS_MODE_DISABLED
	if _use != null:
		_use.enabled = _wheel.visible


func _process(delta: float) -> void:
	_t += delta
	if _spinner != null and _wheel.visible:
		_spin = move_toward(_spin, 0.0, delta * 2.5)
		_spinner.rotation.z += _spin * delta
	if _card != null and _compass.visible:
		# The compass card keeps pointing north, with a little wobble.
		var pb := _card.get_parent_node_3d().global_basis
		_card.rotation.y = -atan2(pb.z.x, pb.z.z) + sin(_t * 1.7) * 0.06


func _build_helm() -> Node3D:
	var root := Node3D.new()
	var mb := MeshBuilder.new()
	mb.box(Vector3(0.26, 1.0, 0.26), Transform3D(Basis.IDENTITY, Vector3(0, 0.5, 0)), Palette.WOOD_DARK)
	mb.box(Vector3(0.5, 0.08, 0.5), Transform3D(Basis.IDENTITY, Vector3(0, 0.04, 0)), Palette.WOOD_DARK.darkened(0.15))
	mb.cylinder(0.05, 0.05, 0.3, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, 1.12, 0.1)), Palette.BRASS, 8)
	var stand := MeshInstance3D.new()
	stand.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	root.add_child(stand)
	_spinner = Node3D.new()
	_spinner.position = Vector3(0, 1.12, 0.26)
	root.add_child(_spinner)
	var wb := MeshBuilder.new()
	var face := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	wb.torus(0.44, 0.53, Transform3D(face, Vector3.ZERO), Palette.WOOD, 24, 6)
	wb.cylinder(0.1, 0.1, 0.12, Transform3D(face, Vector3.ZERO), Palette.BRASS, 12)
	for k in 8:
		var a := TAU * k / 8.0
		var spoke := Transform3D(Basis.from_euler(Vector3(0, 0, a)), Vector3.ZERO)
		wb.cylinder(0.028, 0.034, 0.98, spoke * Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), Palette.WOOD, 6)
		wb.cylinder(0.04, 0.03, 0.16, spoke * Transform3D(Basis.IDENTITY, Vector3(0, 0.66, 0)), Palette.WOOD_DARK, 6)
	var wheel := MeshInstance3D.new()
	wheel.mesh = wb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_spinner.add_child(wheel)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.2, 1.7, 0.5)
	cs.shape = box
	cs.position = Vector3(0, 0.85, 0.12)
	body.add_child(cs)
	root.add_child(body)
	_use = Interactable.new()
	_use.prompt = "{interact} Take the helm"
	_use.radius = 1.7
	_use.position = Vector3(0, 1.0, 0.5)
	_use.interacted.connect(_take_helm)
	root.add_child(_use)
	return root


func _build_binnacle() -> Node3D:
	var root := Node3D.new()
	var mb := MeshBuilder.new()
	mb.cylinder(0.16, 0.22, 0.9, Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Palette.WOOD_DARK, 12)
	mb.cylinder(0.27, 0.22, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Palette.BRASS, 16)
	mb.sphere(0.12, Transform3D(Basis.IDENTITY, Vector3(-0.32, 0.98, 0)), Palette.BRASS.darkened(0.2), 6, 10)
	mb.sphere(0.12, Transform3D(Basis.IDENTITY, Vector3(0.32, 0.98, 0)), Palette.BRASS.darkened(0.2), 6, 10)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	root.add_child(mi)
	_card = Node3D.new()
	_card.position = Vector3(0, 1.02, 0)
	root.add_child(_card)
	var cb := MeshBuilder.new()
	cb.cylinder(0.21, 0.21, 0.02, Transform3D.IDENTITY, Palette.SHIRT, 18)
	cb.box(Vector3(0.05, 0.012, 0.32), Transform3D(Basis.IDENTITY, Vector3(0, 0.016, -0.08)), Palette.COAT)
	cb.box(Vector3(0.04, 0.012, 0.16), Transform3D(Basis.IDENTITY, Vector3(0, 0.016, 0.08)), Palette.PUPIL)
	cb.box(Vector3(0.3, 0.012, 0.025), Transform3D(Basis.IDENTITY, Vector3(0, 0.014, 0)), Palette.PUPIL)
	var card := MeshInstance3D.new()
	card.mesh = cb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_card.add_child(card)
	return root


func _take_helm(_player: Node3D) -> void:
	_spin = 6.0
	AudioManager.play(&"wood_creak", _wheel.global_position, -2.0)
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"open_map"):
		ui.call(&"open_map")
