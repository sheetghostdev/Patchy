@tool
class_name FishingBoat
extends Node3D
## Old Shellby's fishing boat, the Barnacle Betty (spec §103's side quest):
## a teal clinker hull crusted with barnacles, a stubby mast with the sail
## furled, a lobster pot, oars and her name on the transom. Solid to walk
## on. Bobs on the swell whenever she sits at sea level. While the crabs
## hold her she flies Brock's flag; it comes down when `flag_until` (a
## WorldState id, e.g. the parrot task that carries her home) completes.

@export_range(2.0, 8.0, 0.1) var length := 4.6:
	set(v):
		length = v
		_build()
@export_range(0.5, 2.0, 0.05) var half_width := 1.05:
	set(v):
		half_width = v
		_build()
@export var hull_color := Color("2f8f9d")
@export var band_color := Color("f3ead2")
@export var barnacles := true
@export var boat_name := "BARNACLE BETTY"
@export var flag_until: StringName = &""

const KEEL_Y := -0.5
const GUNWALE_Y := 0.55
const INSIDE := Color("c08a55")

var _visual: Node3D
var _flag: Node3D
var _t := 0.0


func _ready() -> void:
	_build()
	if Engine.is_editor_hint():
		return
	_t = randf() * 10.0
	if flag_until != &"":
		if WorldState.is_completed(flag_until):
			_flag.visible = false
		else:
			Events.world_task_completed.connect(_on_task_completed)


func _build() -> void:
	if not is_inside_tree():
		return
	for c in get_children(true):
		if c.get_meta(&"generated", false):
			c.free()
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	body.set_meta(&"generated", true)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(half_width * 1.9, GUNWALE_Y - KEEL_Y, length * 0.96)
	cs.shape = box
	cs.position = Vector3(0, (GUNWALE_Y + KEEL_Y) * 0.5, 0)
	body.add_child(cs)
	_visual = Node3D.new()
	_visual.set_meta(&"generated", true)
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mi := MeshInstance3D.new()
	mi.mesh = _hull_mesh()
	_visual.add_child(mi)
	var gear := MeshInstance3D.new()
	gear.mesh = _gear_mesh()
	_visual.add_child(gear)
	if boat_name != "":
		var lab := Label3D.new()
		lab.text = boat_name
		lab.font_size = 30
		lab.pixel_size = 0.005
		lab.outline_size = 6
		lab.modulate = band_color
		lab.outline_modulate = hull_color.darkened(0.5)
		lab.position = Vector3(0, 0.12, length * 0.5 + 0.035)
		_visual.add_child(lab)
	_flag = Node3D.new()
	_visual.add_child(_flag)
	var fm := MeshInstance3D.new()
	fm.mesh = _flag_mesh()
	_flag.add_child(fm)


## Half-width and gunwale height along the hull, s = 0 at the bow, 1 at the stern.
func _section(s: float) -> Vector2:
	var w := 0.0
	if s < 0.6:
		w = 0.08 + 0.92 * pow(sin(s / 0.6 * PI * 0.5), 0.7)
	else:
		w = 1.0 - 0.22 * pow((s - 0.6) / 0.4, 2.0)
	return Vector2(w * half_width, GUNWALE_Y + 0.3 * pow(1.0 - s, 2.0))


func _rows(scale_w: float, keel_lift: float, top_drop: float) -> Array:
	var rows: Array = []
	for j in 16:
		var s := float(j) / 15.0
		var z := -length * 0.5 + s * length
		var sec := _section(s)
		var keel := KEEL_Y + keel_lift + 0.2 * pow(1.0 - s, 3.0)
		var row := PackedVector3Array()
		for i in 11:
			var a := -PI * 0.5 + PI * float(i) / 10.0
			row.append(Vector3(sec.x * scale_w * sin(a), keel + (sec.y - top_drop - keel) * (1.0 - pow(cos(a), 0.7)), z))
		rows.append(row)
	return rows


func _hull_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var outer := _rows(1.0, 0.0, 0.0)
	var inner := _rows(0.88, 0.14, 0.03)
	mb.grid(outer, hull_color, func(p: Vector3) -> Vector3: return Vector3(p.x, p.y - GUNWALE_Y, 0.0).normalized())
	mb.grid(inner, INSIDE, func(p: Vector3) -> Vector3: return -Vector3(p.x, p.y - GUNWALE_Y, 0.0).normalized())
	var last: PackedVector3Array = outer[outer.size() - 1]
	var center := Vector3(0, (KEEL_Y + GUNWALE_Y) * 0.5, length * 0.5)
	for i in last.size() - 1:
		mb.triangle(center, last[i], last[i + 1], hull_color.darkened(0.12), true)
	mb.triangle(last[0], last[last.size() - 1], center, hull_color.darkened(0.12), true)
	# Gunwale rails and a band just below them.
	for side: int in [0, 10]:
		var rail := PackedVector3Array()
		var radii := PackedFloat32Array()
		for j in outer.size():
			rail.append((outer[j] as PackedVector3Array)[side] + Vector3(0, 0.02, 0))
			radii.append(0.07)
		mb.tube(rail, radii, Palette.WOOD_DARK, 6, true)
	mb.tube(PackedVector3Array([last[0] + Vector3(0, 0.02, 0), last[last.size() - 1] + Vector3(0, 0.02, 0)]), PackedFloat32Array([0.07, 0.07]), Palette.WOOD_DARK, 6, true)
	for j in outer.size() - 1:
		var r0: PackedVector3Array = outer[j]
		var r1: PackedVector3Array = outer[j + 1]
		for cols: Array in [[0, 1], [10, 9]]:
			var a := r0[cols[0]].lerp(r0[cols[1]], 0.55)
			var b := r1[cols[0]].lerp(r1[cols[1]], 0.55)
			var o := Vector3(signf(a.x) * 0.012, 0, 0)
			mb.box(Vector3(0.02, 0.1, a.distance_to(b) + 0.02), Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP), (a + b) * 0.5 + o), band_color)
	# Barnacles crusting the lower hull.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for k in (46 if barnacles else 0):
		var j := rng.randi_range(1, outer.size() - 2)
		var i := rng.randi_range(2, 4) if rng.randf() < 0.5 else rng.randi_range(6, 8)
		var p: Vector3 = (outer[j] as PackedVector3Array)[i]
		var n := Vector3(p.x, p.y - GUNWALE_Y, 0.0).normalized()
		var r := rng.randf_range(0.025, 0.05)
		mb.cylinder(r * 0.4, r, r * 0.9, Transform3D(Basis.looking_at(n, Vector3.FORWARD) * Basis.from_euler(Vector3(-PI * 0.5, 0, 0)), p + n * r * 0.3), Color("d9d4c8").darkened(rng.randf() * 0.2), 6)
	# Thwarts.
	for z: float in [-0.7, 0.55, 1.5]:
		mb.box(Vector3(half_width * 1.55, 0.07, 0.34), Transform3D(Basis.IDENTITY, Vector3(0, 0.24, z)), Palette.WOOD)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))


func _gear_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var mast_z := -0.95
	# Stubby mast with the sail furled along the boom.
	mb.cylinder(0.055, 0.07, 2.6, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, mast_z)), Palette.WOOD_DARK, 8)
	var aft := Basis.from_euler(Vector3(PI * 0.5, 0, 0))
	mb.cylinder(0.04, 0.04, 1.9, Transform3D(aft, Vector3(0, 0.95, mast_z + 0.95)), Palette.WOOD_DARK, 6)
	mb.cylinder(0.11, 0.09, 1.6, Transform3D(aft, Vector3(0, 1.07, mast_z + 0.95)), Color("efe3c4"), 8)
	for k in 4:
		mb.torus(0.09, 0.125, Transform3D(aft, Vector3(0, 1.07, mast_z + 0.35 + k * 0.4)), Palette.ROPE, 10, 4)
	# Lobster pot in the bow, oars across the thwarts, a rope coil aft.
	var pot := Transform3D(Basis.from_euler(Vector3(0, 0.3, 0)), Vector3(0.05, 0.3, -1.45))
	for x: float in [-0.25, 0.25]:
		for y: float in [0.0, 0.36]:
			mb.box(Vector3(0.04, 0.04, 0.52), pot * Transform3D(Basis.IDENTITY, Vector3(x, y, 0)), Palette.WOOD)
	for k in 5:
		mb.box(Vector3(0.5, 0.03, 0.03), pot * Transform3D(Basis.IDENTITY, Vector3(0, 0.36, -0.24 + k * 0.12)), Palette.WOOD.darkened(0.1))
		mb.box(Vector3(0.03, 0.36, 0.03), pot * Transform3D(Basis.IDENTITY, Vector3(-0.25, 0.18, -0.24 + k * 0.12)), Palette.WOOD.darkened(0.1))
		mb.box(Vector3(0.03, 0.36, 0.03), pot * Transform3D(Basis.IDENTITY, Vector3(0.25, 0.18, -0.24 + k * 0.12)), Palette.WOOD.darkened(0.1))
	for side: float in [-1.0, 1.0]:
		var oar := Transform3D(Basis.from_euler(Vector3(0, side * 0.12, 0)), Vector3(side * 0.38, 0.3, 0.6))
		mb.cylinder(0.025, 0.025, 2.2, oar * Transform3D(aft, Vector3.ZERO), Palette.WOOD, 6)
		mb.box(Vector3(0.16, 0.02, 0.5), oar * Transform3D(Basis.IDENTITY, Vector3(0, 0, 1.15)), Palette.WOOD)
	mb.torus(0.08, 0.2, Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.27, 1.85)), Palette.ROPE, 14, 5)
	mb.torus(0.05, 0.15, Transform3D(Basis.IDENTITY, Vector3(-0.3, 0.33, 1.85)), Palette.ROPE.darkened(0.1), 12, 4)
	# A bucket with a fish tail sticking out.
	mb.cylinder(0.14, 0.11, 0.26, Transform3D(Basis.IDENTITY, Vector3(0.45, 0.35, 1.6)), Palette.METAL, 10)
	mb.ellipsoid(Vector3(0.05, 0.09, 0.02), Transform3D(Basis.from_euler(Vector3(0, 0, 0.4)), Vector3(0.43, 0.55, 1.6)), Color("6fb0d9"), 4, 6)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


## Brock's colors on a stick lashed to the mast: a green pennant with a
## toothy white grin.
func _flag_mesh() -> ArrayMesh:
	var mb := MeshBuilder.new()
	var top := Vector3(0, 2.7, -0.95)
	mb.cylinder(0.025, 0.025, 0.9, Transform3D(Basis.IDENTITY, top + Vector3(0, 0.4, 0)), Palette.WOOD_DARK, 5)
	var green := Color("3f9a4a")
	mb.triangle(top + Vector3(0, 0.82, 0), top + Vector3(0, 0.38, 0), top + Vector3(0, 0.6, 0.85), green, true)
	for k in 3:
		var z := 0.12 + k * 0.17
		mb.triangle(top + Vector3(0.012, 0.6 + 0.07, z), top + Vector3(0.012, 0.6 - 0.02, z + 0.05), top + Vector3(0.012, 0.6 + 0.07, z + 0.1), Color.WHITE, true)
	return mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))


func _on_task_completed(task_id: StringName) -> void:
	if task_id == flag_until and _flag != null and _flag.visible:
		var tw := create_tween()
		tw.tween_property(_flag, "scale", Vector3(0.01, 0.01, 0.01), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_callback(func() -> void: _flag.visible = false)
		VFX.dust(get_tree().current_scene, _flag.global_position + Vector3.UP * 3.0, 8, 0.4, Color(0.4, 0.75, 0.45, 0.9), 1.5, 1.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _visual == null:
		return
	_t += delta
	# Afloat (at sea level): bob and roll on the swell.
	if absf(global_position.y) < 1.0:
		var surface := _surface_height()
		_visual.position.y = surface - global_position.y + sin(_t * 1.3) * 0.05
		_visual.rotation = Vector3(sin(_t * 0.9) * 0.03, 0, sin(_t * 1.1 + 0.5) * 0.05)
	elif _visual.position != Vector3.ZERO:
		_visual.position = Vector3.ZERO
		_visual.rotation = Vector3.ZERO


func _surface_height() -> float:
	return WaterVolume.surface_at(get_world_3d(), global_position)
