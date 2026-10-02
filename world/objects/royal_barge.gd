@tool
class_name RoyalBarge
extends FishingBoat
## Brock the Croc's royal barge (spec §100: theatrical, self-important): a
## purple, gold-banded hull with a golden croc figurehead, a velvet runner,
## a gilded throne under a fringed canopy and Brock's toothy pennant, rowed
## by two put-upon crabs. Brock himself stands at the bow (`brock`).

var brock: BrockModel
var _rowers: Array[Node3D] = []
var _oars: Array[Node3D] = []

const PURPLE := Color("5b2d82")
const GOLD := Color("f2c14e")
const VELVET := Color("b8313a")


func _init() -> void:
	length = 6.4
	half_width = 1.4
	hull_color = PURPLE
	band_color = GOLD
	barnacles = false
	boat_name = ""


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	brock = BrockModel.new()
	brock.position = Vector3(0, 0.26, -1.55)
	_visual.add_child(brock)
	for side: float in [-1.0, 1.0]:
		var crab := CrabModel.new()
		crab.scale = Vector3.ONE * 0.9
		crab.position = Vector3(side * 0.45, 0.3, 0.45)
		crab.rotation.y = PI
		_visual.add_child(crab)
		_rowers.append(crab)
		var oar := Node3D.new()
		oar.position = Vector3(side * 1.3, 0.62, 0.45)
		_visual.add_child(oar)
		var mb := MeshBuilder.new()
		mb.cylinder(0.035, 0.035, 2.6, Transform3D(Basis.from_euler(Vector3(0, 0, side * (PI * 0.5 + 0.45))), Vector3(side * 0.55, -0.45, 0)), Palette.WOOD, 6)
		mb.box(Vector3(0.05, 0.6, 0.22), Transform3D(Basis.from_euler(Vector3(0, 0, side * 0.45)), Vector3(side * 1.55, -1.0, 0)), GOLD.darkened(0.1))
		var om := MeshInstance3D.new()
		om.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		oar.add_child(om)
		_oars.append(oar)


func _process(delta: float) -> void:
	super._process(delta)
	if Engine.is_editor_hint():
		return
	# The crabs heave at their oars.
	var stroke := Time.get_ticks_msec() * 0.0042
	for i in _oars.size():
		var side := -1.0 if i == 0 else 1.0
		_oars[i].rotation = Vector3(0, side * sin(stroke) * 0.5, side * (0.15 + cos(stroke) * 0.15))
		_rowers[i].rotation.z = sin(stroke) * 0.12


func _gear_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	# Deck boards and a velvet runner from the throne to the bow.
	mb.box(Vector3(half_width * 1.5, 0.06, length * 0.78), Transform3D(Basis.IDENTITY, Vector3(0, 0.2, 0.1)), Palette.WOOD)
	mb.box(Vector3(0.7, 0.02, length * 0.7), Transform3D(Basis.IDENTITY, Vector3(0, 0.24, 0.1)), VELVET)
	# The throne under its canopy at the stern.
	var tz := length * 0.5 - 1.05
	mb.box(Vector3(1.0, 0.5, 0.8), Transform3D(Basis.IDENTITY, Vector3(0, 0.48, tz)), GOLD)
	mb.box(Vector3(0.8, 0.12, 0.65), Transform3D(Basis.IDENTITY, Vector3(0, 0.78, tz - 0.02)), VELVET)
	mb.box(Vector3(1.0, 1.3, 0.16), Transform3D(Basis.IDENTITY, Vector3(0, 1.3, tz + 0.35)), GOLD)
	mb.box(Vector3(0.78, 1.1, 0.06), Transform3D(Basis.IDENTITY, Vector3(0, 1.3, tz + 0.26)), VELVET)
	mb.sphere(0.14, Transform3D(Basis.IDENTITY, Vector3(0, 2.05, tz + 0.35)), GOLD, 6, 10)
	for x: float in [-0.95, 0.95]:
		for z: float in [-0.75, 0.75]:
			mb.cylinder(0.05, 0.05, 2.5, Transform3D(Basis.IDENTITY, Vector3(x, 1.45, tz + z)), GOLD, 8)
	mb.box(Vector3(2.2, 0.12, 1.8), Transform3D(Basis.IDENTITY, Vector3(0, 2.75, tz)), PURPLE)
	mb.cylinder(0.0, 1.3, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, 3.06, tz)), PURPLE.darkened(0.1), 4)
	for k in 14:
		var t := float(k) / 13.0
		for z: float in [-0.9, 0.9]:
			mb.cylinder(0.035, 0.0, 0.2, Transform3D(Basis.IDENTITY, Vector3(lerpf(-1.08, 1.08, t), 2.6, tz + z)), GOLD, 5)
	# Golden croc figurehead at the bow.
	var bow := Vector3(0, 0.75, -length * 0.5 - 0.15)
	mb.ellipsoid(Vector3(0.2, 0.17, 0.3), Transform3D(Basis.IDENTITY, bow), GOLD, 8, 10)
	mb.ellipsoid(Vector3(0.14, 0.08, 0.32), Transform3D(Basis.IDENTITY, bow + Vector3(0, -0.04, -0.36)), GOLD, 6, 10)
	for side: float in [-1.0, 1.0]:
		mb.sphere(0.06, Transform3D(Basis.IDENTITY, bow + Vector3(side * 0.1, 0.13, -0.08)), VELVET, 5, 7)
		for k in 3:
			mb.cylinder(0.0, 0.02, 0.06, Transform3D(Basis.from_euler(Vector3(PI, 0, 0)), bow + Vector3(side * 0.11, -0.09, -0.25 - k * 0.1)), Color("fffbea"), 4)
	# Lanterns on gold posts at the bow corners.
	for side: float in [-1.0, 1.0]:
		mb.cylinder(0.03, 0.03, 0.9, Transform3D(Basis.IDENTITY, Vector3(side * 0.9, 0.95, -length * 0.5 + 1.2)), GOLD, 6)
		mb.box(Vector3(0.18, 0.24, 0.18), Transform3D(Basis.IDENTITY, Vector3(side * 0.9, 1.5, -length * 0.5 + 1.2)), Color("ffe08a"))
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


## Brock's toothy pennant, flying high from the canopy.
func _flag_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var top := Vector3(0, 3.3, length * 0.5 - 1.05)
	mb.cylinder(0.03, 0.03, 1.4, Transform3D(Basis.IDENTITY, top + Vector3(0, 0.7, 0)), GOLD, 6)
	var green := Color("3f9a4a")
	mb.triangle(top + Vector3(0, 1.38, 0), top + Vector3(0, 0.78, 0), top + Vector3(0, 1.08, 1.3), green, true)
	for k in 4:
		var z := 0.14 + k * 0.22
		mb.triangle(top + Vector3(0.012, 1.15, z), top + Vector3(0.012, 1.02, z + 0.06), top + Vector3(0.012, 1.15, z + 0.12), Color.WHITE, true)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
