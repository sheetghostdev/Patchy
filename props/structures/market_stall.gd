@tool
class_name MarketStall
extends PropBody
## A village market stall: a plank counter on trestles under a striped
## canvas roof on four poles, laden with the day's catch, fruit or pots.
## Origin: the ground at the stall's middle; the counter faces -Z. The
## canvas roof is walkable (a step up the village's rooftops).
## Footsteps report &"wood".

enum Goods { FISH, FRUIT, POTS }

@export var goods := Goods.FISH:
	set(v):
		goods = v
		_queue_rebuild()
@export var canvas := Color("e8483c"):
	set(v):
		canvas = v
		_queue_rebuild()
@export_range(1.6, 5.0, 0.05) var width := 2.8:
	set(v):
		width = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const DEPTH := 1.6
const COUNTER := 1.0
const ROOF := 2.5


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed, 307)
	var hw := width * 0.5
	var hd := DEPTH * 0.5
	# Poles, the counter on its trestles, a back shelf.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var top := ROOF + (0.25 if sz > 0.0 else 0.0)
			parts.matte.cylinder(0.06, 0.07, top, Transform3D(Basis.IDENTITY, Vector3(sx * (hw - 0.1), top * 0.5, sz * (hd - 0.1))), PropPalette.WOOD_FRAME, 8)
	parts.matte.chamfer_box(Vector3(width - 0.1, 0.1, 0.7), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, COUNTER, -hd + 0.4)), PropPalette.PLANK)
	parts.matte.chamfer_box(Vector3(width - 0.2, COUNTER - 0.1, 0.06), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, (COUNTER - 0.1) * 0.5, -hd + 0.1)), PropPalette.PLANK_DARK)
	parts.matte.chamfer_box(Vector3(width - 0.2, 0.08, 0.4), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, 1.35, hd - 0.25)), PropPalette.PLANK_DARK)
	# The striped canvas roof, sloping down to the front, with a scalloped edge.
	var stripes := maxi(4, int(width / 0.45))
	var a := Vector3(0, ROOF + 0.3, hd + 0.1)
	var b := Vector3(0, ROOF - 0.05, -hd - 0.25)
	var dir := (b - a).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP.slide(dir).normalized())
	var length := a.distance_to(b)
	for k in stripes:
		var x := -hw - 0.1 + (k + 0.5) * (width + 0.2) / stripes
		var col := canvas if k % 2 == 0 else Color("f8f1e2")
		parts.matte.box(Vector3((width + 0.2) / stripes, 0.05, length), Transform3D(basis, (a + b) * 0.5 + Vector3(x, 0, 0)), col)
		parts.soft.cylinder(0.11, 0.11, 0.04, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), b + Vector3(x, -0.06, -0.02)), col, 10)
	# The goods.
	var top := COUNTER + 0.05
	match goods:
		Goods.FISH:
			for k in 7:
				var c: Color = [Color("8ab4d8"), Color("e7a46a"), Color("c7d7e6"), Color("f0b8a0")][rng.randi() % 4]
				var p := Vector3(-hw + 0.45 + k * (width - 0.9) / 6.0, top + 0.06, -hd + 0.4 + rng.randf_range(-0.12, 0.12))
				var yaw := rng.randf_range(-0.6, 0.6)
				parts.soft.ellipsoid(Vector3(0.09, 0.06, 0.22), Transform3D(Basis(Vector3.UP, yaw), p), c, 5, 8)
				parts.soft.cylinder(0.0, 0.08, 0.12, Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), p + Basis(Vector3.UP, yaw) * Vector3(0, 0, 0.26)), c.darkened(0.15), 6)
			# Ice-blue crate of more fish, hanging fish on a line.
			parts.matte.chamfer_box(Vector3(0.7, 0.35, 0.5), 0.03, Transform3D(Basis.IDENTITY, Vector3(hw - 0.5, 0.18, hd - 0.4)), PropPalette.PLANK_DARK)
			for k in 3:
				parts.soft.ellipsoid(Vector3(0.07, 0.2, 0.05), Transform3D(Basis.IDENTITY, Vector3(-hw + 0.5 + k * 0.5, ROOF - 0.45, -hd + 0.15)), Color("9cc3e0"), 5, 8)
				parts.matte.cylinder(0.008, 0.008, 0.3, Transform3D(Basis.IDENTITY, Vector3(-hw + 0.5 + k * 0.5, ROOF - 0.12, -hd + 0.15)), PropPalette.ROPE_DARK, 4)
		Goods.FRUIT:
			for k in 3:
				var x := -hw + 0.55 + k * (width - 1.1) / 2.0
				parts.matte.chamfer_box(Vector3(0.6, 0.18, 0.45), 0.03, Transform3D(Basis.IDENTITY, Vector3(x, top + 0.09, -hd + 0.4)), PropPalette.PLANK_LIGHT)
				var fruit: Color = [Color("ffcf3f"), Color("f08a3c"), Color("e8483c")][k]
				for j in 6:
					parts.soft.sphere(0.08, Transform3D(Basis.IDENTITY, Vector3(x + (j % 3 - 1) * 0.16, top + 0.24 + (j / 3) * 0.06, -hd + 0.33 + (j / 3) * 0.12)), PropKit.jitter(fruit, rng, 0.05), 4, 7)
			for k in 3:
				parts.soft.ellipsoid(Vector3(0.05, 0.16, 0.05), Transform3D(Basis(Vector3.BACK, 0.4), Vector3(-0.3 + k * 0.12, ROOF - 0.4, -hd + 0.18)), Color("ffd84a"), 4, 6)
		Goods.POTS:
			for k in 5:
				var x := -hw + 0.45 + k * (width - 0.9) / 4.0
				var r := rng.randf_range(0.1, 0.17)
				var c: Color = [Color("c9693e"), Color("d98b52"), Color("4f8fc0"), Color("e6d3b0")][rng.randi() % 4]
				var prof := PackedVector2Array([Vector2(0, 0), Vector2(r * 0.7, 0), Vector2(r, r * 0.8), Vector2(r * 0.85, r * 1.6), Vector2(r * 0.5, r * 1.9), Vector2(r * 0.55, r * 2.1), Vector2(0, r * 2.1)])
				parts.glossy.lathe(prof, 10, Transform3D(Basis.IDENTITY, Vector3(x, top, -hd + 0.4)), c)
	add_mesh(parts.build(), "Stall")
	add_shape(PropKit.box_shape(Vector3(width - 0.1, COUNTER, 0.7)), Transform3D(Basis.IDENTITY, Vector3(0, COUNTER * 0.5, -hd + 0.4)), "Counter")
	add_shape(PropKit.box_shape(Vector3(width + 0.2, 0.12, length)), Transform3D(basis, (a + b) * 0.5), "Canvas")
	for sx: float in [-1.0, 1.0]:
		add_shape(PropKit.cylinder_shape(0.08, ROOF), Transform3D(Basis.IDENTITY, Vector3(sx * (hw - 0.1), ROOF * 0.5, hd - 0.1)), "Pole")
