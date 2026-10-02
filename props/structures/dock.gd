@tool
class_name Dock
extends PropBody
## Wooden dock / pier. Chunky planks laid across the width with small gaps
## and slightly ragged ends, stringers and headers underneath, round posts
## running down to `post_depth` (with a darker wet band near the water line),
## optional sagging rope rails strung between taller posts and bollards at
## the far end. Origin: the walkable deck surface at the near edge (center of
## the width); the dock extends along -Z. Collision: one box for the deck plus
## a cylinder per post. Footsteps report &"wood".

@export_range(2.0, 60.0, 0.1) var length := 8.0:
	set(v):
		length = v
		_queue_rebuild()
@export_range(1.2, 8.0, 0.05) var width := 2.6:
	set(v):
		width = v
		_queue_rebuild()
## Posts reach down to this depth below the deck surface.
@export_range(0.3, 20.0, 0.1) var post_depth := 2.5:
	set(v):
		post_depth = v
		_queue_rebuild()
@export_range(1.0, 6.0, 0.05) var post_spacing := 2.4:
	set(v):
		post_spacing = v
		_queue_rebuild()
## Water line (local y) for the wet band on the posts.
@export var water_line := -0.6:
	set(v):
		water_line = v
		_queue_rebuild()
@export var rope_rails := true:
	set(v):
		rope_rails = v
		_queue_rebuild()
@export_range(0.4, 1.6, 0.01) var rail_height := 0.9:
	set(v):
		rail_height = v
		_queue_rebuild()
@export var bollards := true:
	set(v):
		bollards = v
		_queue_rebuild()
## Gap between planks (m).
@export_range(0.0, 0.15, 0.005) var plank_gap := 0.035:
	set(v):
		plank_gap = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

const PLANK_DEPTH := 0.3
const PLANK_THICK := 0.12
const POST_RADIUS := 0.15


func _surface() -> StringName:
	return &"wood"


func _build() -> void:
	var parts := PropParts.new()
	var rng := PropKit.make_rng(seed, 91)
	var mt := parts.matte
	var half_w := width * 0.5
	var tones := [PropPalette.PLANK, PropPalette.PLANK_LIGHT, PropPalette.PLANK.darkened(0.1), PropPalette.HULL_LIGHT]
	# Deck planks.
	var count := maxi(int(floor((length + plank_gap) / (PLANK_DEPTH + plank_gap))), 1)
	var pitch := length / count
	for k in count:
		var z := -pitch * (k + 0.5)
		var extra := rng.randf_range(-0.05, 0.08)
		var shift := rng.randf_range(-0.04, 0.04)
		var orient := Basis(Vector3.UP, deg_to_rad(rng.randf_range(-1.2, 1.2)))
		var pos := Vector3(shift, -PLANK_THICK * 0.5 + rng.randf_range(-0.008, 0.004), z)
		mt.chamfer_box(Vector3(width + 0.12 + extra, PLANK_THICK, pitch - plank_gap), 0.025, Transform3D(orient, pos), PropKit.jitter(tones[rng.randi() % tones.size()], rng, 0.04))
	# Stringers along the length, headers across at each post row.
	var under := -PLANK_THICK
	var stringer_x: Array[float] = [-half_w + 0.3, half_w - 0.3]
	if width > 3.0:
		stringer_x.append(0.0)
	for x in stringer_x:
		mt.chamfer_box(Vector3(0.16, 0.2, length - 0.1), 0.03, Transform3D(Basis.IDENTITY, Vector3(x, under - 0.1, -length * 0.5)), PropPalette.WOOD_FRAME.darkened(0.1))
	var rows := _post_rows()
	for z in rows:
		mt.chamfer_box(Vector3(width + 0.3, 0.2, 0.18), 0.03, Transform3D(Basis.IDENTITY, Vector3(0, under - 0.3, z)), PropPalette.WOOD_FRAME.darkened(0.15))
	# Posts (taller when they carry the rope rails).
	var top := rail_height + 0.12 if rope_rails else 0.18
	var wet := PropPalette.WOOD_DEEP
	var dry := PropPalette.WOOD_FRAME
	for z in rows:
		for sx: float in [-1.0, 1.0]:
			var x := sx * (half_w + 0.06)
			var r := POST_RADIUS * rng.randf_range(0.95, 1.08)
			var wl := clampf(water_line, -post_depth + 0.05, -0.05)
			var pts := PackedVector3Array([Vector3(x, -post_depth, z), Vector3(x, wl - 0.25, z), Vector3(x, wl, z), Vector3(x, top - r * 0.5, z)])
			mt.banded_tube(pts, PackedFloat32Array([r, r, r, r]), PackedColorArray([wet, wet.lerp(dry, 0.4), dry]), 10)
			mt.sphere(r, Transform3D(Basis.from_scale(Vector3(1.0, 0.55, 1.0)), Vector3(x, top - r * 0.5, z)), dry.lightened(0.08), 4, 10)
			add_shape(PropKit.cylinder_shape(r, top + post_depth), Transform3D(Basis.IDENTITY, Vector3(x, (top - post_depth) * 0.5, z)), "Post")
			if rope_rails:
				mt.torus(r * 0.95, r * 1.35, Transform3D(Basis.IDENTITY, Vector3(x, rail_height, z)), PropPalette.ROPE_DARK, 12, 5)
	# Rope rails between neighboring posts.
	if rope_rails:
		for sx: float in [-1.0, 1.0]:
			var x := sx * (half_w + 0.06)
			for k in rows.size() - 1:
				var a := Vector3(x, rail_height, rows[k])
				var b := Vector3(x, rail_height, rows[k + 1])
				mt.tube(_sag(a, b, 0.18, 8), PackedFloat32Array([0.035]), Palette.ROPE, 6, false)
	# Bollards at the far end.
	if bollards:
		for sx: float in [-1.0, 1.0]:
			var p := Vector3(sx * (half_w - 0.35), 0.0, -length + 0.45)
			_bollard(parts, p)
	add_mesh(parts.build(), "Dock")
	# Walkable deck.
	add_shape(PropKit.box_shape(Vector3(width, PLANK_THICK * 2.0, length)), Transform3D(Basis.IDENTITY, Vector3(0, -PLANK_THICK, -length * 0.5)), "Deck")
	if bollards:
		for sx: float in [-1.0, 1.0]:
			add_shape(PropKit.cylinder_shape(0.2, 0.5), Transform3D(Basis.IDENTITY, Vector3(sx * (half_w - 0.35), 0.25, -length + 0.45)), "Bollard")


func _post_rows() -> Array[float]:
	var rows: Array[float] = []
	var n := maxi(int(ceil((length - 0.4) / post_spacing)), 1)
	for k in n + 1:
		rows.append(-0.2 - (length - 0.4) * float(k) / n)
	return rows


static func _sag(a: Vector3, b: Vector3, sag: float, steps: int) -> PackedVector3Array:
	var pts := PackedVector3Array()
	for k in steps + 1:
		var t := float(k) / steps
		pts.append(a.lerp(b, t) + Vector3.DOWN * sag * 4.0 * t * (1.0 - t))
	return pts


## Short iron mooring bollard with a rope loop (also used by Bollard).
static func _bollard(parts: PropParts, p: Vector3, size_scale: float = 1.0) -> void:
	var s := size_scale
	var prof := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.2 * s, 0.0), Vector2(0.17 * s, 0.06 * s), Vector2(0.13 * s, 0.1 * s),
		Vector2(0.12 * s, 0.32 * s), Vector2(0.19 * s, 0.38 * s), Vector2(0.19 * s, 0.44 * s), Vector2(0.14 * s, 0.49 * s), Vector2(0.0, 0.5 * s),
	])
	parts.metal.lathe(prof, 14, Transform3D(Basis.IDENTITY, p), PropPalette.IRON)
	parts.matte.torus(0.12 * s, 0.17 * s, Transform3D(Basis(Vector3.RIGHT, 0.12), p + Vector3.UP * 0.2 * s), PropPalette.ROPE_DARK, 14, 6)
