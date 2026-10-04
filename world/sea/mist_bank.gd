class_name MistBank
extends Node3D
## A bank of sea mist round an island that isn't charted yet (still being
## built): low white cloud on the water all round its shore. Sail or swim
## into it and the mist turns you gently back out, with a word about why.
## Only round those islands: the open sea between them is open.
## Sits at the island's center at sea level and follows its shoreline: the
## outline of its silhouette (`island_id`, from the "horizon_island" group)
## at sea level, padded out by `margin`.

@export var island_id: StringName = &""
@export var margin := 12.0
@export var message := "A wall of thick sea mist hides %s. There's no way in... not yet. (This island isn't built yet.)"

const PUSH := 2.5
const MAX_PUSH := 14.0

## The mist's outline round the island (x, z from this node).
var outline := PackedVector2Array()
## How far the mist reaches from the center at most.
var radius := 0.0
var _hint_cool := 0.0
var _cloud: MeshInstance3D


func _ready() -> void:
	add_to_group(&"mist_bank")
	_setup.call_deferred()


func _setup() -> void:
	var shore := _shoreline()
	var hull := Geometry2D.convex_hull(shore)
	var padded := Geometry2D.offset_polygon(hull, margin, Geometry2D.JOIN_ROUND)
	outline = padded[0] if not padded.is_empty() else hull
	radius = 0.0
	for p in outline:
		radius = maxf(radius, p.length())
	_build()


## The island's shore: its silhouette's points near sea level, in this
## node's frame at life size (the WorldDirector scales silhouettes with
## distance; the mist stays put).
func _shoreline() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for n in get_tree().get_nodes_in_group(&"horizon_island"):
		var sil := n as Node3D
		if sil == null or StringName(sil.get_meta(&"island_id", &"")) != island_id:
			continue
		var inv := sil.global_transform.affine_inverse()
		var place := Transform3D(sil.global_basis.orthonormalized(), sil.global_position - global_position)
		for mi: MeshInstance3D in sil.find_children("*", "MeshInstance3D", true, false):
			if mi.mesh == null or not mi.is_visible_in_tree():
				continue
			var xf := inv * mi.global_transform
			for k in mi.mesh.get_surface_count():
				for v: Vector3 in mi.mesh.surface_get_arrays(k)[Mesh.ARRAY_VERTEX]:
					var q := xf * v
					if q.y > -1.0 and q.y < 2.5:
						var w := place * q
						pts.append(Vector2(w.x, w.z))
		break
	if pts.size() < 3:
		for k in 16:
			pts.append(Vector2.from_angle(TAU * k / 16.0) * 40.0)
	return pts


func _build() -> void:
	var mb := PropBuilder.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(island_id)
	# A wall of cloud on the water round the shore: big low billows, smaller
	# ones heaped on top, so the shore's hidden but the island's shape
	# still rises above it.
	var k := 0
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		var steps := maxi(1, int(a.distance_to(b) / 9.0))
		for j in steps:
			var p := a.lerp(b, float(j) / steps)
			var out := Vector3(p.x, 0, p.y).normalized()
			var yaw := Player.yaw_of(out)
			for tier in 3:
				if tier == 2 and k % 2 == 1:
					continue
				var size := rng.randf_range(9.0, 13.0) * (1.0 - tier * 0.22)
				var at := Vector3(p.x, 0, p.y) + out * (rng.randf_range(-5.0, 3.0) - tier * 2.0) + Vector3.UP * (1.0 + tier * 4.2 + rng.randf_range(0.0, 1.2))
				var shape := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(size * 1.25, size * 0.62, size))
				mb.sphere(1.0, Transform3D(shape, at), Color("f6f4ee").darkened(rng.randf_range(0.0, 0.05)), 4, 8)
			k += 1
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transparency = 0.18
	# Only up close: from afar the island's shape is the thing to see.
	mi.visibility_range_end = radius + 170.0
	mi.visibility_range_end_margin = 80.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	_cloud = mi


func _process(_delta: float) -> void:
	# The bank breathes a little on the swell.
	if _cloud != null:
		_cloud.position.y = sin(Time.get_ticks_msec() * 0.0004) * 0.4


func _physics_process(delta: float) -> void:
	_hint_cool = maxf(_hint_cool - delta, 0.0)
	var p := GameManager.player as Player
	if p == null or outline.is_empty():
		return
	var body: Node3D = p
	var boat: TinyBoat = null
	if p.state_id == &"boat":
		for b in get_tree().get_nodes_in_group(&"boat"):
			if (b as TinyBoat) != null and (b as TinyBoat).driver == p:
				boat = b
				body = boat
				break
	elif p.state_id != &"swim":
		return
	var into := depth(body.global_position)
	if into <= 0.0:
		return
	var here := _local(body.global_position)
	var out := (_nearest_edge(here) - here).normalized()
	var push := Vector3(out.x, 0, out.y) * minf(PUSH + into * 1.5, MAX_PUSH) * delta
	body.global_position += push
	if boat != null:
		boat.slow_to(lerpf(boat.top_speed(), 2.0, clampf(into / 10.0, 0.0, 1.0)))
	if _hint_cool <= 0.0:
		_hint_cool = 8.0
		Events.hud_message.emit(message % UIChartData.display_name(island_id), 3.5)


## How far inside the mist `pos` is (m; 0 outside it).
func depth(pos: Vector3) -> float:
	var q := _local(pos)
	if outline.is_empty() or not Geometry2D.is_point_in_polygon(q, outline):
		return 0.0
	return q.distance_to(_nearest_edge(q))


func contains(pos: Vector3) -> bool:
	return depth(pos) > 0.0


func _local(pos: Vector3) -> Vector2:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z)


func _nearest_edge(q: Vector2) -> Vector2:
	var best := q
	var best_d := INF
	for i in outline.size():
		var c := Geometry2D.get_closest_point_to_segment(q, outline[i], outline[(i + 1) % outline.size()])
		var d := q.distance_squared_to(c)
		if d < best_d:
			best_d = d
			best = c
	return best
