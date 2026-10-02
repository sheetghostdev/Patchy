class_name BellBuoy
extends StaticBody3D
## A red-and-white bell buoy halfway across the strait (spec §117,
## "navigation landmarks"): it rides the swell, and its bell clangs as it
## rolls, so you can steer for it by sound as well as sight. Bump it with
## the boat or give it a swipe and it rings out.

var _visual: Node3D
var _bell: Node3D
var _swing := 0.0
var _swing_v := 0.0
var _t := 0.0
var _next_ring := 3.0
var _bump_cool := 0.0


func _ready() -> void:
	# Solid to boats and the camera; on PROPS too so a swipe can ring it.
	collision_layer = Layers.WORLD | Layers.PROPS
	collision_mask = 0
	_t = randf() * 10.0
	_visual = Node3D.new()
	add_child(_visual)
	var mb := MeshBuilder.new()
	var red := Color("d8402f")
	var white := Color("f4efe6")
	# Float: stacked bands, a deck ring, and a little cage tower on top.
	for k in 4:
		mb.cylinder(0.78 - k * 0.04, 0.82 - k * 0.04, 0.3, Transform3D(Basis.IDENTITY, Vector3(0, -0.25 + k * 0.3, 0)), red if k % 2 == 0 else white, 16)
	mb.cylinder(0.95, 0.95, 0.1, Transform3D(Basis.IDENTITY, Vector3(0, 0.95, 0)), Palette.METAL.darkened(0.2), 18)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		mb.cylinder(0.05, 0.05, 1.7, Transform3D(Basis.from_euler(Vector3(0, 0, 0)), Vector3(cos(a) * 0.5, 1.85, sin(a) * 0.5)), red, 6)
	mb.cylinder(0.62, 0.62, 0.12, Transform3D(Basis.IDENTITY, Vector3(0, 2.72, 0)), red, 14)
	mb.cylinder(0.0, 0.5, 0.45, Transform3D(Basis.IDENTITY, Vector3(0, 3.0, 0)), red.darkened(0.15), 14)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
	_visual.add_child(mi)
	var lamp := MeshBuilder.new()
	lamp.sphere(0.14, Transform3D(Basis.IDENTITY, Vector3(0, 3.3, 0)), Color("fff1a8"), 6, 8)
	var lm := MeshInstance3D.new()
	lm.mesh = lamp.build(null, MaterialLibrary.toon(Color.WHITE, &"emissive"))
	_visual.add_child(lm)
	_bell = Node3D.new()
	_bell.position = Vector3(0, 2.6, 0)
	_visual.add_child(_bell)
	var bb := MeshBuilder.new()
	bb.cylinder(0.12, 0.3, 0.5, Transform3D(Basis.IDENTITY, Vector3(0, -0.3, 0)), Palette.BRASS, 14)
	bb.torus(0.26, 0.33, Transform3D(Basis.IDENTITY, Vector3(0, -0.55, 0)), Palette.BRASS.darkened(0.1), 14, 4)
	bb.sphere(0.07, Transform3D(Basis.IDENTITY, Vector3(0, -0.62, 0)), Palette.METAL, 5, 6)
	var bm := MeshInstance3D.new()
	bm.mesh = bb.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	_bell.add_child(bm)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.95
	cyl.height = 3.4
	cs.shape = cyl
	cs.position = Vector3(0, 1.3, 0)
	add_child(cs)


func _physics_process(delta: float) -> void:
	_t += delta
	_bump_cool = maxf(_bump_cool - delta, 0.0)
	var surface := WaterVolume.surface_at(get_world_3d(), global_position)
	_visual.position.y = surface - global_position.y - 0.35 + sin(_t * 1.2) * 0.12
	var roll := sin(_t * 0.9) * 0.1
	_visual.rotation = Vector3(roll, 0, sin(_t * 0.7 + 1.3) * 0.08)
	# The bell swings against the roll and clangs at the top of each swing.
	_swing_v += (-roll * 2.0 - _swing) * 30.0 * delta
	_swing_v *= exp(-delta * 1.5)
	_swing += _swing_v * delta
	_bell.rotation.z = _swing
	_next_ring -= delta
	if _next_ring <= 0.0:
		_next_ring = randf_range(5.0, 9.0)
		ring(-8.0)
	for n in get_tree().get_nodes_in_group(&"boat"):
		var boat := n as Node3D
		if boat != null and _bump_cool <= 0.0 and Player.flat(boat.global_position - global_position).length() < 2.4:
			_bump_cool = 1.5
			ring(0.0)


func ring(volume_db: float = 0.0) -> void:
	_swing_v += 2.5 if randf() < 0.5 else -2.5
	AudioManager.play(&"bell_ring", _bell.global_position, volume_db, randf_range(0.85, 0.95))


func take_hit(_hit: Dictionary) -> void:
	if _bump_cool <= 0.0:
		_bump_cool = 0.5
		ring(2.0)
