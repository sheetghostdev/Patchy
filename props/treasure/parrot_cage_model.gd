@tool
class_name ParrotCageModel
extends PropNode
## Visual-only domed bird cage for parrot rescues: a turned wooden plinth,
## brass bars curving into a dome, ring bands, a finial with a hanging ring,
## a wooden perch inside and a hinged door. Gameplay scripts animate the
## exposed `door` pivot (rotate `door.rotation.y`; open = negative angles,
## swinging outward) or set `door_open` (0..1). Front (door side) faces -Z;
## origin at the bottom center. No physics of its own.

enum Metal { BRASS, IRON }

@export_range(0.25, 2.0, 0.01) var radius := 0.55:
	set(v):
		radius = v
		_queue_rebuild()
## Height of the straight part of the bars (the dome sits on top).
@export_range(0.3, 3.0, 0.01) var wall_height := 0.85:
	set(v):
		wall_height = v
		_queue_rebuild()
@export_range(6, 32) var bars := 14:
	set(v):
		bars = v
		_queue_rebuild()
@export var metal := Metal.BRASS:
	set(v):
		metal = v
		_queue_rebuild()
@export var perch := true:
	set(v):
		perch = v
		_queue_rebuild()
## Editor / preview door opening (0 closed, 1 fully open).
@export_range(0.0, 1.0, 0.01) var door_open := 0.0:
	set(v):
		door_open = v
		if door != null:
			door.rotation.y = -door_open * DOOR_SWING
## Door width as an angle around the cage (deg).
@export_range(30.0, 120.0, 1.0) var door_angle := 62.0:
	set(v):
		door_angle = v
		_queue_rebuild()

const DOOR_SWING := 1.95
const BAR_R := 0.018

## Hinge pivot of the door (rotate around Y to open).
var door: Node3D
## Total height including the finial ring.
var total_height := 0.0


func _build() -> void:
	var r := radius
	var base_h := 0.14 * maxf(r / 0.55, 0.6)
	var wall_top := base_h + wall_height
	var dome := r * 0.85
	total_height = wall_top + dome + 0.16
	var fit: Color = Palette.BRASS if metal == Metal.BRASS else PropPalette.IRON
	var parts := PropParts.new()
	# Turned wooden plinth with a lighter rim.
	var plinth := PackedVector2Array([Vector2(0.0, 0.0), Vector2(r + 0.07, 0.0), Vector2(r + 0.09, base_h * 0.35), Vector2(r + 0.06, base_h * 0.6)])
	parts.matte.lathe(plinth, 24, Transform3D.IDENTITY, PropPalette.CAGE_BASE)
	var rim := PackedVector2Array([Vector2(r + 0.06, base_h * 0.6), Vector2(r + 0.05, base_h), Vector2(0.0, base_h)])
	parts.matte.lathe(rim, 24, Transform3D.IDENTITY, PropPalette.CAGE_BASE_TRIM)
	# Door opening (centered on -Z) and its hinge on the left edge.
	var half_door := deg_to_rad(door_angle) * 0.5
	var front := -PI * 0.5  # angle of -Z in the XZ circle (x = cos, z = sin)
	var door_top := base_h + wall_height * 0.82
	var me := parts.metal
	for k in bars:
		var a := TAU * float(k) / bars + PI / bars
		var in_door := absf(wrapf(a - front, -PI, PI)) < half_door
		var pts := PackedVector3Array()
		var d := Vector3(cos(a), 0.0, sin(a))
		if not in_door:
			pts.append(d * r + Vector3.UP * base_h)
		pts.append(d * r + Vector3.UP * (door_top if in_door else wall_top * 0.6 + base_h * 0.4))
		pts.append(d * r + Vector3.UP * wall_top)
		for s in range(1, 6):
			var t := float(s) / 5.0 * PI * 0.5
			pts.append(d * r * cos(t) + Vector3.UP * (wall_top + dome * sin(t)))
		me.tube(pts, PackedFloat32Array([BAR_R]), fit, 5, false)
	# Ring bands (the bottom and middle rings skip the door opening).
	me.torus(r - 0.03, r + 0.03, Transform3D(Basis.IDENTITY, Vector3.UP * wall_top), fit.lightened(0.08), 32, 6)
	for y: float in [base_h + 0.03, base_h + wall_height * 0.42]:
		me.tube(_arc(r, y, front + half_door, front + TAU - half_door, 24), PackedFloat32Array([BAR_R * 1.4]), fit.darkened(0.05), 5, true)
	me.tube(_arc(r, door_top, front - half_door, front + half_door, 6), PackedFloat32Array([BAR_R * 1.4]), fit, 5, false)
	# Finial and hanging ring.
	var top := Vector3.UP * (wall_top + dome)
	me.sphere(0.05, Transform3D(Basis.IDENTITY, top), fit.lightened(0.1), 5, 10)
	me.torus(0.035, 0.07, Transform3D(Basis(Vector3.RIGHT, PI * 0.5), top + Vector3.UP * 0.1), fit, 14, 6)
	# Perch.
	if perch:
		var py := base_h + wall_height * 0.55
		parts.matte.rod(Vector3(-r * 0.92, py, 0.05), Vector3(r * 0.92, py, 0.05), 0.028, 0.028, PropPalette.PERCH, 8, true)
		parts.matte.rod(Vector3(-r * 0.3, py - 0.25, 0.05), Vector3(-r * 0.3, py, 0.05), 0.012, 0.012, fit, 4, false)
		me.torus(0.12, 0.14, Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(r * 0.25, py - 0.18, 0.05)), fit, 16, 4)
		parts.glossy.cylinder(0.09, 0.07, 0.05, Transform3D(Basis.IDENTITY, Vector3(r * 0.4, base_h + 0.025, r * 0.35)), PropPalette.SIGN_PAINTS[0], 12)
	add_mesh(parts.build(), "Cage")
	# Door on its hinge.
	var hinge_a := front - half_door
	var hinge := Vector3(cos(hinge_a), 0.0, sin(hinge_a)) * r + Vector3.UP * base_h
	door = PropKit.pivot(self, "Door", Transform3D(Basis.IDENTITY, hinge))
	var dp := PropParts.new()
	var dm := dp.metal
	var door_bars := maxi(int(round(float(bars) * deg_to_rad(door_angle) / TAU)), 2)
	for k in door_bars + 1:
		var a := lerpf(front - half_door, front + half_door, float(k) / door_bars)
		var d := Vector3(cos(a), 0.0, sin(a)) * (r + 0.012)
		dm.tube(PackedVector3Array([d + Vector3.UP * (base_h + 0.03) - hinge, d + Vector3.UP * (door_top - 0.02) - hinge]), PackedFloat32Array([BAR_R]), fit, 5, true)
	for y: float in [base_h + 0.04, door_top - 0.03, (base_h + door_top) * 0.5]:
		var arc := _arc(r + 0.012, y, front - half_door, front + half_door, 6)
		for i in arc.size():
			arc[i] -= hinge
		dm.tube(arc, PackedFloat32Array([BAR_R * 1.3]), fit.lightened(0.06), 5, true)
	var latch_a := front + half_door
	var latch := Vector3(cos(latch_a), 0.0, sin(latch_a)) * (r + 0.03) + Vector3.UP * (base_h + wall_height * 0.45) - hinge
	dm.chamfer_box(Vector3(0.05, 0.08, 0.03), 0.008, Transform3D(Basis(Vector3.UP, -latch_a), latch), PropPalette.GOLD_DEEP)
	PropKit.mesh_instance(door, dp.build(), "DoorMesh")
	door.rotation.y = -door_open * DOOR_SWING


static func _arc(r: float, y: float, a0: float, a1: float, steps: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for s in steps + 1:
		var a := lerpf(a0, a1, float(s) / steps)
		pts.append(Vector3(cos(a) * r, y, sin(a) * r))
	return pts
