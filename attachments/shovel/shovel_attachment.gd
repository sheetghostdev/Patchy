class_name ShovelAttachment
extends AttachmentBase
## A stout pirate spade on the hook (spec §58).
## - Secrets: dig spots (sparkling mounds, the places treasure maps sketch)
##   give up buried treasure, sometimes a whole treasure map. Dig close to a
##   hidden one and Patchy can tell it's near, but not exactly where.
## - Combat: a scoop under a crab's legs flips it over.

const DIG_TIME := 0.5
const REACH := 1.5
## A miss this close to a hidden spot earns a "warmer" hint.
const WARM_RADIUS := 4.5

var _busy := 0.0


func _ready() -> void:
	var wood := MeshBuilder.new()
	var metal := MeshBuilder.new()
	wood.cylinder(0.03, 0.03, 0.62, Transform3D(Basis.IDENTITY, Vector3(0, -0.33, 0)), Palette.WOOD, 8)
	wood.box(Vector3(0.16, 0.035, 0.05), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, 0)), Palette.WOOD_DARK)
	metal.cylinder(0.045, 0.035, 0.08, Transform3D(Basis.IDENTITY, Vector3(0, -0.04, 0)), Palette.BRASS, 10)
	# Spade blade: a rounded plate with a raised spine, facing forward.
	var blade := Transform3D(Basis.IDENTITY, Vector3(0, -0.74, -0.01))
	metal.rounded_box(Vector3(0.22, 0.26, 0.025), 0.01, blade, Palette.HOOK_METAL, 2)
	metal.sphere(0.11, Transform3D(Basis.from_scale(Vector3(1.0, 0.55, 0.12)), Vector3(0, -0.86, -0.01)), Palette.HOOK_METAL, 6, 10)
	metal.box(Vector3(0.03, 0.24, 0.035), Transform3D(Basis.IDENTITY, Vector3(0, -0.71, -0.02)), Palette.HOOK_METAL.darkened(0.2))
	add_mesh(wood, &"matte")
	add_mesh(metal, &"metal")


func pickup_hint() -> String:
	return "Shovel! {tool_primary} digs: try sparkling sand, and scoop crabs over."


func physics_update(delta: float) -> void:
	_busy = maxf(_busy - delta, 0.0)


func primary_action() -> void:
	if player == null or _busy > 0.0 or player.state_id != &"ground":
		return
	_busy = DIG_TIME
	player.play_tool_anim(&"dig", DIG_TIME)
	var front := player.global_position + player.facing * 0.9
	# A brief plant of the feet while the spade bites.
	player.set_horizontal_velocity(Vector3.ZERO)
	await get_tree().create_timer(DIG_TIME * 0.42, false).timeout
	if player == null or not is_instance_valid(player):
		return
	AudioManager.play(StringName("shovel_dig_0%d" % randi_range(1, 3)), front)
	var spot := _find_spot(front, REACH)
	if spot != null:
		spot.dig(player)
		return
	VFX.dust(get_tree().current_scene, front, 7, 0.3, _dirt_color(), 1.4, 1.6)
	var near := _find_spot(front, WARM_RADIUS)
	if near != null and near.hidden:
		Events.hud_message.emit("Hmm... something's buried close by.", 1.8)
	# Scoop whatever stands right in front.
	for n in get_tree().get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		if e != null and e.global_position.distance_to(front) < REACH and e.has_method(&"take_hit"):
			e.call(&"take_hit", {"damage": 0, "kind": &"shovel", "source": player, "position": player.global_position, "direction": player.facing})


func _find_spot(front: Vector3, reach: float) -> DigSpot:
	var best: DigSpot = null
	var best_d := reach
	for n in get_tree().get_nodes_in_group(&"dig_spot"):
		var spot := n as DigSpot
		if spot == null or not spot.can_dig():
			continue
		var d := Player.flat(spot.global_position - front).length()
		if d < best_d and absf(spot.global_position.y - player.global_position.y) < 1.2:
			best_d = d
			best = spot
	return best


func _dirt_color() -> Color:
	var surf: StringName = &"sand"
	var fc: Object = player.floor_collider
	if is_instance_valid(fc) and fc is Node:
		surf = StringName((fc as Node).get_meta(&"surface", &"sand"))
	return Color(0.98, 0.9, 0.7, 0.9) if surf == &"sand" else Color(0.55, 0.4, 0.28, 0.9)
