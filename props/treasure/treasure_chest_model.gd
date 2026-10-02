@tool
class_name TreasureChestModel
extends PropNode
## Visual-only treasure chest (safe to put under any StaticBody3D or gameplay
## node): a chunky planked body with metal bands, corner brackets, side
## handles and a lock plate, and a barrel-top lid on a hinge pivot exposed as
## `lid` (rotate `lid.rotation.x` positive to open, or set `open_amount`).
## Variants: WOOD (warm wood, iron bands) and GOLD (gilded, gem-studded).
## A heap of gold coins and gems sits inside (`treasure`). Front faces -Z;
## origin at the bottom center.

enum Variant { WOOD, GOLD }

@export var variant := Variant.WOOD:
	set(v):
		variant = v
		_queue_rebuild()
## Body footprint and height (the lid adds about half the depth on top).
@export var size := Vector3(1.1, 0.6, 0.72):
	set(v):
		size = v.max(Vector3.ONE * 0.2)
		_queue_rebuild()
@export_range(0.0, 1.0, 0.01) var open_amount := 0.0:
	set(v):
		open_amount = v
		if lid != null:
			lid.rotation.x = open_amount * OPEN_ANGLE
@export var treasure := true:
	set(v):
		treasure = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const OPEN_ANGLE := 1.92

## Hinge pivot at the back top edge of the body.
var lid: Node3D


func _build() -> void:
	var gold := variant == Variant.GOLD
	var w := size.x
	var h := size.y
	var d := size.z
	var rng := PropKit.make_rng(seed, 77)
	var body_col: Color = PropPalette.CHEST_GOLD if gold else PropPalette.CHEST_WOOD
	var dark_col: Color = PropPalette.CHEST_GOLD_DARK if gold else PropPalette.CHEST_WOOD_DARK
	var band_col: Color = PropPalette.CHEST_GOLD_DARK if gold else PropPalette.CHEST_BAND
	var parts := PropParts.new()
	var wood: PropBuilder = parts.glossy if gold else parts.matte
	var me := parts.metal
	var t := 0.07
	# Open box: floor + four walls, inside lined in velvet.
	wood.chamfer_box(Vector3(w, t, d), 0.02, Transform3D(Basis.IDENTITY, Vector3.UP * t * 0.5), dark_col)
	for sz: float in [-1.0, 1.0]:
		var wall_planks := 3
		for k in wall_planks:
			var ph := (h - t) / wall_planks
			var y := t + ph * (k + 0.5)
			wood.chamfer_box(Vector3(w, ph - 0.012, t), 0.018, Transform3D(Basis.IDENTITY, Vector3(0, y, sz * (d - t) * 0.5)), PropKit.jitter(body_col, rng, 0.04))
	for sx: float in [-1.0, 1.0]:
		wood.chamfer_box(Vector3(t, h - t, d - t * 2.0), 0.018, Transform3D(Basis.IDENTITY, Vector3(sx * (w - t) * 0.5, t + (h - t) * 0.5, 0)), PropKit.jitter(body_col.darkened(0.05), rng, 0.03))
	parts.matte.box(Vector3(w - t * 2.0, 0.02, d - t * 2.0), Transform3D(Basis.IDENTITY, Vector3.UP * (t + 0.01)), PropPalette.CHEST_INSIDE)
	for sz: float in [-1.0, 1.0]:
		parts.matte.box(Vector3(w - t * 2.0, h - t - 0.02, 0.01), Transform3D(Basis.IDENTITY, Vector3(0, t + (h - t) * 0.5, sz * ((d - t) * 0.5 - t * 0.5 - 0.006))), PropPalette.CHEST_INSIDE)
	# Bands wrapping the body, corner brackets, handles, lock plate.
	for bx: float in [-0.32, 0.32]:
		var x := bx * w
		for sz: float in [-1.0, 1.0]:
			me.chamfer_box(Vector3(0.08, h, 0.025), 0.008, Transform3D(Basis.IDENTITY, Vector3(x, h * 0.5, sz * (d * 0.5 + 0.006))), band_col)
		me.chamfer_box(Vector3(0.08, 0.025, d + 0.03), 0.008, Transform3D(Basis.IDENTITY, Vector3(x, 0.006, 0)), band_col)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector3(sx * w * 0.5, 0.0, sz * d * 0.5)
			me.chamfer_box(Vector3(0.14, 0.16, 0.035), 0.01, Transform3D(Basis.IDENTITY, c + Vector3(-sx * 0.055, 0.09, sz * 0.012)), band_col.lightened(0.08))
			me.chamfer_box(Vector3(0.035, 0.16, 0.14), 0.01, Transform3D(Basis.IDENTITY, c + Vector3(sx * 0.012, 0.09, -sz * 0.055)), band_col.lightened(0.08))
		me.chamfer_box(Vector3(0.025, 0.12, 0.2), 0.008, Transform3D(Basis.IDENTITY, Vector3(sx * (w * 0.5 + 0.01), h * 0.62, 0)), band_col)
		me.torus(0.05, 0.075, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(sx * (w * 0.5 + 0.04), h * 0.55, 0)), band_col.lightened(0.15), 14, 5)
	var lock_col := PropPalette.GOLD_DEEP if not gold else PropPalette.GOLD_LIGHT
	me.chamfer_box(Vector3(0.17, 0.2, 0.03), 0.015, Transform3D(Basis.IDENTITY, Vector3(0, h - 0.13, -d * 0.5 - 0.016)), lock_col)
	parts.matte.box(Vector3(0.03, 0.07, 0.01), Transform3D(Basis.IDENTITY, Vector3(0, h - 0.15, -d * 0.5 - 0.034)), Color("2b2135"))
	parts.matte.sphere(0.022, Transform3D(Basis.IDENTITY, Vector3(0, h - 0.11, -d * 0.5 - 0.032)), Color("2b2135"), 3, 6)
	if gold:
		for k in 4:
			var gx := (-0.32 if k < 2 else 0.32) * w
			var gy := h * (0.3 if k % 2 == 0 else 0.7)
			parts.gem.append(PropMeshes.gem_builder([PropPalette.GEM_GREEN, Palette.GEM_RED, Palette.GEM_BLUE, PropPalette.GEM_PURPLE][k], 0.06), Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(gx, gy, -d * 0.5 - 0.035)))
	# Treasure heap inside.
	if treasure:
		var heap_y := h * 0.82
		parts.soft.ellipsoid(Vector3((w - t * 2.0) * 0.48, h * 0.2, (d - t * 2.0) * 0.46), Transform3D(Basis.IDENTITY, Vector3.UP * heap_y), PropPalette.CHEST_GOLD_DARK, 6, 14)
		var coins := 16
		for k in coins:
			var a := rng.randf() * TAU
			var rr := sqrt(rng.randf())
			var p := Vector3(cos(a) * rr * (w - t * 2.0) * 0.42, 0.0, sin(a) * rr * (d - t * 2.0) * 0.38)
			p.y = heap_y + h * 0.2 * sqrt(maxf(1.0 - rr * rr, 0.0)) - 0.005
			var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5)))
			me.cylinder(0.055, 0.055, 0.018, Transform3D(tilt, p), PropPalette.COIN if k % 3 else PropPalette.COIN_RIM, 10)
		for k in 3:
			var a := rng.randf() * TAU
			var p := Vector3(cos(a) * w * 0.18, heap_y + h * 0.14, sin(a) * d * 0.12)
			parts.gem.append(PropMeshes.gem_builder([Palette.GEM_RED, Palette.GEM_BLUE, PropPalette.GEM_GREEN][k], 0.07), Transform3D(Basis.from_euler(Vector3(rng.randf(), rng.randf() * TAU, 0.3)), p))
	add_mesh(parts.build(), "Body")
	# Lid: barrel-top planks on a hinge at the back top edge.
	lid = PropKit.pivot(self, "Lid", Transform3D(Basis.IDENTITY, Vector3(0, h, d * 0.5)))
	var lp := PropParts.new()
	var lw: PropBuilder = lp.glossy if gold else lp.matte
	var arc_h := d * 0.42
	var planks := 5
	var arc := func(f: float) -> Vector3:
		var ang := f * PI
		return Vector3(0.0, sin(ang) * arc_h, -d * 0.5 + cos(ang) * d * 0.5)
	for k in planks:
		var f0 := float(k) / planks
		var f1 := float(k + 1) / planks
		var p0: Vector3 = arc.call(f0)
		var p1: Vector3 = arc.call(f1)
		var mid := (p0 + p1) * 0.5
		var chord := (p1 - p0)
		var out := Vector3.RIGHT.cross(chord).normalized()
		if out.dot(mid - Vector3(0, 0, -d * 0.5)) < 0.0:
			out = -out
		var orient := Basis(Vector3.RIGHT, out, Vector3.RIGHT.cross(out))
		lw.chamfer_box(Vector3(w, t, chord.length() + 0.004), 0.016, Transform3D(orient, mid - out * t * 0.5), PropKit.jitter(body_col, rng, 0.04))
	# Lid end caps.
	var cap := PackedVector2Array()
	for k in 13:
		var p: Vector3 = arc.call(float(k) / 12.0)
		cap.append(Vector2(-p.z, p.y))
	for sx: float in [-1.0, 1.0]:
		lw.extrude(cap, t, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(sx * (w - t) * 0.5, 0.0, 0.0)), dark_col, 0.012)
	# Bands over the lid and the hasp.
	for bx: float in [-0.32, 0.32]:
		var bottom := PackedVector3Array()
		var top := PackedVector3Array()
		for k in 13:
			var p: Vector3 = arc.call(float(k) / 12.0)
			var outw := (p - Vector3(0, 0, -d * 0.5)).normalized()
			bottom.append(p + outw * 0.012 + Vector3(bx * w - 0.04, 0, 0))
			top.append(p + outw * 0.012 + Vector3(bx * w + 0.04, 0, 0))
		lp.metal.board_strip(bottom, top, 0.026, band_col, Vector3.UP, Color(0, 0, 0, 0), Vector3(0, 0, -d * 0.5))
	lp.metal.chamfer_box(Vector3(0.12, 0.16, 0.03), 0.012, Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -d - 0.02)), lock_col)
	PropKit.mesh_instance(lid, lp.build(), "LidMesh")
	lid.rotation.x = open_amount * OPEN_ANGLE
