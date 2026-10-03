@tool
class_name HorizonStormpeak
extends HorizonIsland
## Stormpeak on the horizon (docs/ARCHIPELAGO.md): a needle of slate rock
## with a lighthouse on its tip, lost in a storm that never ends. A dark
## thundercloud wheels slowly round the peak, rain hangs beneath it in
## grey curtains, and every few seconds lightning cracks down and lights the
## cloud from inside.

const SLATE := [Color("5f6779"), Color("7c8598"), Color("454c5b")]
const CLOUD := Color("555c6e")
const BOLT := Color("e8f2ff")
const PEAK := 236.0

var _cloud: Node3D
var _cloud_mat: ShaderMaterial
var _bolt: MeshInstance3D
var _top := Vector3.ZERO
var _next := 2.0
var _rng := RandomNumberGenerator.new()


func _build() -> void:
	var rng := PropKit.make_rng(seed, 909)
	_rng.seed = seed
	# The needle, with two lower spurs leaning on it.
	var rock := PropBuilder.new()
	rock.append(mesa(outline_around(Vector2(50, 44), 12, 0.16, seed), PEAK, 12.0, 0.74, seed + 1))
	rock.append(mesa(outline_around(Vector2(34, 28), 10, 0.2, seed + 2), 128.0, 10.0, 0.6, seed + 3, Vector3(-46, 0, 22)))
	rock.append(mesa(outline_around(Vector2(28, 26), 10, 0.2, seed + 4), 86.0, 10.0, 0.55, seed + 5, Vector3(44, 0, 30)))
	for k in 6:
		var a := rng.randf() * TAU
		rock.append(StylizedRock.build_rock(StylizedRock.Preset.DARK_ROCK, Vector3(18, 12, 16) * rng.randf_range(0.6, 1.3), seed + 20 + k), Transform3D(Basis(Vector3.UP, a), Vector3(cos(a) * 80.0, -2.0, sin(a) * 70.0)))
	paint(rock, SLATE, seed, 0.03)
	add_part(rock)
	# The lighthouse on the tip: striped tower, glowing lamp, dark cap.
	_top = Vector3(0, PEAK, 0)
	var house := PropBuilder.new()
	for k in 5:
		var r0 := 6.5 - k * 0.5
		house.cylinder(r0 - 0.5, r0, 5.0, Transform3D(Basis.IDENTITY, _top + Vector3(0, 2.5 + k * 5.0, 0)), Color("f4efe6") if k % 2 == 0 else Color("d8433a"), 10)
	house.cylinder(0.0, 5.5, 5.0, Transform3D(Basis.IDENTITY, _top + Vector3(0, 33.5, 0)), Color("2b2a30"), 10)
	house.flat_shade()
	shade(house, seed + 1)
	add_part(house)
	var lamp := PropBuilder.new()
	lamp.cylinder(3.6, 3.6, 4.0, Transform3D(Basis.IDENTITY, _top + Vector3(0, 29.0, 0)), Color.WHITE, 10)
	add_part(lamp, &"emissive", null, Color("ffe08a"))
	# The thundercloud: dark heaps in a slow wheel round the peak.
	_cloud = Node3D.new()
	_cloud.name = "Thundercloud"
	_cloud.position = Vector3(0, PEAK + 22.0, 0)
	get_root().add_child(_cloud)
	var cloud := PropBuilder.new()
	for k in 22:
		var a := TAU * k / 22.0 + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(45.0, 130.0)
		var size := rng.randf_range(32.0, 56.0)
		cloud.ellipsoid(Vector3(size, size * 0.55, size), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(cos(a) * r, rng.randf_range(-10.0, 16.0), sin(a) * r)), CLOUD.lightened(rng.randf_range(-0.05, 0.12)), 4, 8)
	cloud.ellipsoid(Vector3(160, 20, 150), Transform3D(Basis.IDENTITY, Vector3(0, 28, 0)), CLOUD.lightened(0.08), 4, 14)
	cloud.flat_shade()
	shade(cloud, seed + 2, 0.03)
	var cmi := MeshInstance3D.new()
	_cloud_mat = MaterialLibrary.toon_unique(Color.WHITE, &"soft")
	cmi.mesh = cloud.build(null, _cloud_mat)
	cmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cloud.add_child(cmi)
	# Rain hanging under it in a ring of grey curtains.
	var rain := PropBuilder.new()
	var segs := 20
	var ring_r := 78.0
	for k in segs:
		var a0 := TAU * k / segs
		var a1 := TAU * (k + 1) / segs
		var top0 := Vector3(cos(a0) * ring_r, PEAK + 6.0, sin(a0) * ring_r)
		var top1 := Vector3(cos(a1) * ring_r, PEAK + 6.0, sin(a1) * ring_r)
		var i0 := rain.vert(top0, Vector3.UP, Color.WHITE, Vector2(float(k) / segs, 0.0))
		rain.vert(top1, Vector3.UP, Color.WHITE, Vector2(float(k + 1) / segs, 0.0))
		rain.vert(Vector3(top1.x * 1.2, 0.0, top1.z * 1.2), Vector3.UP, Color.WHITE, Vector2(float(k + 1) / segs, 1.0))
		rain.vert(Vector3(top0.x * 1.2, 0.0, top0.z * 1.2), Vector3.UP, Color.WHITE, Vector2(float(k) / segs, 1.0))
		rain.quad(i0, i0 + 1, i0 + 2, i0 + 3, Vector3(cos(a0), 0, sin(a0)))
	var rmi := MeshInstance3D.new()
	var rmat := ShaderMaterial.new()
	rmat.shader = preload("res://world/horizon/far_rain.gdshader")
	rmi.mesh = rain.build(null, rmat)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_root().add_child(rmi)
	# One reusable bolt, rebuilt for every strike.
	_bolt = MeshInstance3D.new()
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	get_root().add_child(_bolt)


func _process(delta: float) -> void:
	if _cloud == null:
		return
	_cloud.rotation.y += delta * 0.03
	_next -= delta
	if _next > 0.0:
		return
	_next = _rng.randf_range(2.0, 5.5)
	_strike()


## A jagged bolt from the cloud to the lighthouse (it is the highest metal
## around) or down to the sea, and the cloud lit up from inside.
func _strike() -> void:
	var from := Vector3(_rng.randf_range(-55, 55), PEAK + 16.0, _rng.randf_range(-55, 55))
	var to := _top + Vector3(0, 34, 0) if _rng.randf() < 0.45 else Vector3(_rng.randf_range(-90, 90), 0, _rng.randf_range(-90, 90))
	var mb := PropBuilder.new()
	var pts := PackedVector3Array([from])
	var steps := 9
	for k in range(1, steps):
		var t := float(k) / steps
		pts.append(from.lerp(to, t) + Vector3(_rng.randf_range(-9, 9), 0, _rng.randf_range(-9, 9)))
	pts.append(to)
	for k in pts.size() - 1:
		var a := pts[k]
		var b := pts[k + 1]
		var side := (b - a).cross(Vector3.FORWARD).normalized() * (2.2 - k * 0.15)
		mb.triangle(a - side, a + side, b + side, Color.WHITE, true)
		mb.triangle(a - side, b + side, b - side, Color.WHITE, true)
	_bolt.mesh = mb.build(null, MaterialLibrary.toon(BOLT, &"emissive"))
	_bolt.visible = true
	_cloud_mat.set_shader_parameter(&"emission_color", Color("c8d8ff"))
	var tw := create_tween()
	tw.tween_method(func(e: float) -> void: _cloud_mat.set_shader_parameter(&"emission_energy", e), 0.9, 0.0, 0.45)
	var flick := create_tween()
	flick.tween_interval(0.08)
	flick.tween_callback(func() -> void: _bolt.visible = false)
	flick.tween_interval(0.06)
	flick.tween_callback(func() -> void: _bolt.visible = true)
	flick.tween_interval(0.1)
	flick.tween_callback(func() -> void: _bolt.visible = false)
