class_name FloatingBarrel
extends StaticBody3D
## Flotsam from Brock's raids bobbing between the islands (spec §117,
## "floating barrels"): ram it with the boat or give it a swipe and it
## bursts, and the coins inside fly straight to Patchy (nothing sinks out
## of reach). Persistent by barrel_id.

@export var barrel_id: StringName = &""
@export_range(0, 20) var coins := 4
## Ramming speed (m/s) that breaks it.
@export_range(0.5, 10.0, 0.1) var ram_speed := 2.0

const HEIGHT := 1.1
const RADIUS := 0.42

var _visual: Node3D
var _t := 0.0
var _broken := false
var _boat_last := Vector3.INF


func _ready() -> void:
	collision_layer = Layers.PROPS
	collision_mask = 0
	if barrel_id != &"" and WorldState.is_completed(barrel_id):
		queue_free()
		return
	_t = randf() * TAU
	_visual = Node3D.new()
	add_child(_visual)
	var mi := MeshInstance3D.new()
	mi.mesh = Barrel.build_mesh(HEIGHT, RADIUS, Barrel.Hoops.IRON, int(position.x * 7.0 + position.z))
	mi.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(HEIGHT * 0.5, 0, 0))
	_visual.add_child(mi)
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = RADIUS
	cyl.height = HEIGHT
	cs.shape = cyl
	cs.basis = Basis(Vector3.BACK, PI * 0.5)
	add_child(cs)


func _physics_process(delta: float) -> void:
	if _broken:
		return
	_t += delta
	var surface := WaterVolume.surface_at(get_world_3d(), global_position)
	global_position.y = surface - 0.12 + sin(_t * 1.6) * 0.05
	_visual.rotation = Vector3(sin(_t * 1.1) * 0.12, _t * 0.15, sin(_t * 0.9 + 1.0) * 0.1)
	# A boat ploughing into it at speed bursts it.
	for n in get_tree().get_nodes_in_group(&"boat"):
		var boat := n as Node3D
		if boat == null:
			continue
		var speed := 0.0 if _boat_last == Vector3.INF else Player.flat(boat.global_position - _boat_last).length() / maxf(delta, 0.001)
		_boat_last = boat.global_position
		if Player.flat(boat.global_position - global_position).length() < 2.2 and speed > ram_speed:
			burst()
			return


func take_hit(_hit: Dictionary) -> void:
	burst()


func burst() -> void:
	if _broken:
		return
	_broken = true
	if barrel_id != &"":
		WorldState.mark_completed(barrel_id)
	var scene := get_tree().current_scene
	AudioManager.play(&"barrel_break", global_position)
	VFX.splash(scene, global_position, 1.2)
	VFX.dust(scene, global_position + Vector3.UP * 0.3, 8, 0.3, Color(0.62, 0.44, 0.26, 0.95), 2.2, 2.0)
	for i in coins:
		var c := Collectible.new()
		c.kind = "coin"
		scene.add_child(c)
		c.global_position = global_position + Vector3(randf_range(-0.4, 0.4), 0.6 + i * 0.12, randf_range(-0.4, 0.4))
		# Straight into Patchy's pouch.
		c.set(&"_magnet_t", 0.01 + i * 0.02)
	queue_free()
