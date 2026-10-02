@tool
class_name DigSpot
extends Node3D
## Buried treasure (spec §58). A sandy mound that glints now and then, or,
## for hidden spots, nothing but a faint shimmer: the treasure map that leads
## here only sketches the place (spec §86–87), it never marks the world.
## Two scoops of the shovel pop the treasure out. Persistent by spot_id.

signal dug_up(spot: DigSpot)

@export var spot_id: StringName = &""
@export var island_id: StringName = &""
@export_enum("coins", "gem", "pearl", "goblet", "crown", "relic", "heart", "map") var contents := "coins":
	set(v):
		contents = v
		_rebuild()
@export var coins := 6
## Map handed out when contents is "map".
@export var map_id: StringName = &""
@export var gem_color := Color(0.25, 0.6, 1.0)
@export_range(1, 5) var digs_required := 2
## No mound: only a faint shimmer.
@export var hidden := false:
	set(v):
		hidden = v
		_rebuild()
## Treasure map whose sketch leads here (marked solved when dug up).
@export var marked_by_map: StringName = &""

var _visual: Node3D
var _mound: MeshInstance3D
var _glints: Array[MeshInstance3D] = []
var _digs := 0
var _done := false
var _t := 0.0


func _ready() -> void:
	_rebuild()
	if Engine.is_editor_hint():
		return
	add_to_group(&"dig_spot")
	if contents in ["gem", "pearl", "goblet", "crown", "relic"] and spot_id != &"":
		add_to_group(&"treasure_source")
	if spot_id != &"" and WorldState.is_completed(spot_id):
		_done = true
		_show_hole()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.free()
	_glints.clear()
	_visual = Node3D.new()
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	if not hidden:
		mb.ellipsoid(Vector3(0.75, 0.22, 0.7), Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), Palette.SAND.lightened(0.05), 6, 12)
		for k in 6:
			var a := TAU * k / 6.0 + 0.3
			mb.sphere(0.07, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.62, 0.05, sin(a) * 0.58)), Palette.SAND_DARK, 3, 5)
	mb.box(Vector3(0.05, 0.01, 0.4), Transform3D(Basis.from_euler(Vector3(0, 0.4, 0)), Vector3(0.1, 0.005, 0.05)), Palette.SAND_DARK.darkened(0.15))
	mb.box(Vector3(0.04, 0.01, 0.3), Transform3D(Basis.from_euler(Vector3(0, -0.7, 0)), Vector3(-0.15, 0.005, -0.1)), Palette.SAND_DARK.darkened(0.15))
	_mound = MeshInstance3D.new()
	_mound.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	_visual.add_child(_mound)
	for k in 3:
		var g := MeshInstance3D.new()
		var sb := MeshBuilder.new()
		sb.box(Vector3(0.025, 0.16, 0.025), Transform3D.IDENTITY, Color("fff6c8"))
		sb.box(Vector3(0.16, 0.025, 0.025), Transform3D.IDENTITY, Color("fff6c8"))
		g.mesh = sb.build(null, MaterialLibrary.toon(Color.WHITE, &"emissive"))
		var a := TAU * k / 3.0
		g.position = Vector3(cos(a) * 0.35, 0.28, sin(a) * 0.3)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.add_child(g)
		_glints.append(g)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _done:
		return
	_t += delta
	var cam := get_viewport().get_camera_3d()
	for i in _glints.size():
		var g := _glints[i]
		var ph := fmod(_t * (0.55 if hidden else 0.8) + i * 0.37, 1.0)
		var tw := smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.08, 0.22, ph))
		g.scale = Vector3.ONE * maxf(tw * (0.7 if hidden else 1.0), 0.001)
		if cam != null:
			var d := cam.global_position - g.global_position
			g.rotation = Vector3(0, atan2(d.x, d.z), 0)


## For IslandInfo's treasure totals.
func get_treasure_island() -> StringName:
	return island_id


func can_dig() -> bool:
	return not _done


func dig(player: Node3D) -> void:
	if _done:
		return
	_digs += 1
	VFX.dust(get_tree().current_scene, global_position + Vector3.UP * 0.2, 10, 0.35, Color(0.98, 0.9, 0.7, 0.95), 1.6, 2.2)
	if _mound != null:
		_mound.scale = Vector3(1.0, maxf(1.0 - float(_digs) / digs_required, 0.15), 1.0)
	if _digs < digs_required:
		return
	_done = true
	if spot_id != &"":
		WorldState.mark_completed(spot_id)
	if marked_by_map != &"":
		InventoryManager.mark_map_solved(marked_by_map)
	AudioManager.play(&"shovel_find", global_position)
	AudioManager.play_stinger(&"stinger_treasure")
	VFX.sparkle(get_tree().current_scene, global_position + Vector3.UP * 0.6, Palette.GOLD, 20, 5.0)
	_show_hole()
	_reward(player as Player)
	dug_up.emit(self)


func _reward(player: Player) -> void:
	var scene := get_tree().current_scene
	if contents == "map":
		if map_id != &"":
			InventoryManager.add_treasure_map(map_id)
			Events.hud_message.emit("Found a treasure map!", 3.0)
		return
	if contents == "coins":
		for i in coins:
			var c := Collectible.new()
			c.kind = "coin"
			c.launched = true
			scene.add_child(c)
			c.global_position = global_position + Vector3.UP * 0.5
		return
	var prize := Collectible.new()
	prize.kind = contents
	prize.treasure_id = StringName("%s_prize" % spot_id) if spot_id != &"" else &""
	prize.island_id = island_id
	prize.gem_color = gem_color
	prize.launched = true
	# The big find pops straight up and drops back by the hole.
	prize.launch_velocity = Vector3(0, 7.0, 0)
	scene.add_child(prize)
	prize.global_position = global_position + Vector3.UP * 0.6
	for i in mini(coins, 4):
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.5
	if player != null and player.state_id == &"ground":
		player.play_tool_anim(&"hold_up", 0.9)


func _show_hole() -> void:
	if _mound != null:
		var hb := MeshBuilder.new()
		hb.cylinder(0.42, 0.36, 0.03, Transform3D(Basis.IDENTITY, Vector3(0, 0.01, 0)), Color("5c4630"), 14)
		for k in 7:
			var a := TAU * k / 7.0
			hb.sphere(0.09, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.55, 0.04, sin(a) * 0.5)), Palette.SAND_DARK, 3, 5)
		_mound.mesh = hb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		_mound.scale = Vector3.ONE
	for g in _glints:
		g.visible = false


