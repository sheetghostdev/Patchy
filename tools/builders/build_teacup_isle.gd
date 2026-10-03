extends IslandBuilder
## Generates res://world/islands/teacup_isle/teacup_isle.tscn: Teacup Isle, "a
## round island with tea... a whirlpool... in the middle" (docs/ARCHIPELAGO.md),
## east of Castaway Cay. Built in the island's own frame (TeacupIsle: its
## place in the archipelago, turned so -Z faces Castaway Cay):
##  - The saucer (a sandy shoal) with a jetty at the front; sugar-cube steps
##    up to a giant spoon leaning on the cup, and up its handle to the rim.
##  - The tea: swim in and the Whirlpool carries Patchy round and down the
##    drain into the grotto in the cup's foot.
##  - The grotto: three steam vents plugged with sugar cubes. Yank a plug
##    out with the grapple and the steam carries Patchy up to a shelf: the
##    parrot, the Golden Teapot, a gem.
##  - Out through the tunnel under the handle: blast the sugar wall.
##   tools/builders/build.sh teacup_isle

const ISLAND := &"teacup_isle"
const T := preload("res://world/horizon/horizon_teacup_isle.gd")
## The grotto's shelves: [angle (degrees), top height, what's on it].
const SHELVES := [[120.0, 6.6, "parrot"], [205.0, 7.2, "teapot"], [290.0, 6.2, "gem"]]

var root: Node3D


func build() -> void:
	seed(20261006)
	root = island_root(ISLAND, "TeacupIsle")
	begin("TeacupIsle", ISLAND, "Teacup Isle", &"castaway_explore", root)
	_rock()
	_landing()
	_tea()
	_grotto()
	_outside()
	_hints()
	horizon([ISLAND])
	open_sea(root.position, 440.0)
	spawn(root.transform * Vector3(0, 1.5, -T.saucer_top_r(Vector3.FORWARD) - 5.0), root.transform.basis * Vector3(0, 0, 1))
	b.save("res://world/islands/teacup_isle/teacup_isle.tscn")


func _rock() -> void:
	var cup := HorizonTeacupIsle.new()
	cup.playable = true
	b.add(cup, terrain, "Cup")


func _landing() -> void:
	var g := b.group("Landing", gameplay)
	var front := -T.saucer_top_r(Vector3.FORWARD)
	var jetty := Dock.new()
	jetty.length = 10.0
	jetty.width = 2.6
	jetty.post_depth = 6.0
	jetty.water_line = -0.9
	jetty.position = Vector3(0, 1.0, front + 0.8)
	b.add(jetty, g, "Jetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(3.0, 0.0, front - 7.5)
	mooring.rotation.y = PI
	b.add(mooring, g, "BoatMooring")
	var arrival := Marker3D.new()
	arrival.position = Vector3(0, 1.4, front - 6.0)
	arrival.rotation.y = PI
	b.add(arrival, g, "Arrival")
	boat(g, mooring, 230.0)
	waters(g, Vector3.ZERO, 85.0, mooring, arrival, "Teacup Isle")
	_checkpoint(g, "cp_teacup_saucer", Vector3(-4.0, T.SAUCER_TOP, front + 6.0), 0.0, "CpSaucer")


## The tea to swim in, and the whirlpool that takes it down the drain.
func _tea() -> void:
	var g := b.group("Tea", gameplay)
	var tea := WaterVolume.new()
	tea.round = true
	tea.show_surface = false
	tea.wave_height = 0.05
	tea.size = Vector3(T.TEA_R * 2.0 + 1.0, T.TEA_Y - T.TEA_FLOOR + 0.2, T.TEA_R * 2.0 + 1.0)
	tea.position = Vector3(0, T.TEA_Y, 0)
	b.add(tea, g, "TeaWater")
	var pool := Whirlpool.new()
	pool.position = Vector3(0, T.TEA_Y, 0)
	pool.radius = T.TEA_R
	pool.eye_radius = T.DRAIN_R + 0.3
	pool.drop_to = (T.GROTTO_TOP - 1.6) - T.TEA_Y
	b.add(pool, g, "Whirlpool")


## The grotto in the cup's foot: lights, the vents and their plugs, the
## shelves and what's on them, and the sugar wall across the tunnel out.
func _grotto() -> void:
	var g := b.group("Grotto", gameplay)
	for d: Array in [[Vector3(0, 7.5, 0), 1.6, Color("ffe2a8")], [Vector3(-8, 5.0, 6), 1.0, Color("bfe7ff")], [Vector3(8, 5.0, -6), 1.0, Color("bfe7ff")]]:
		var light := OmniLight3D.new()
		light.position = d[0]
		light.light_energy = d[1]
		light.light_color = d[2]
		light.omni_range = 16.0
		light.light_specular = 0.0
		b.add(light, g, "GrottoLight")
	for k in SHELVES.size():
		var d: Array = SHELVES[k]
		var a := deg_to_rad(d[0])
		var dir := Vector3(cos(a), 0, sin(a))
		var top: float = d[1]
		# The shelf: a chalk ledge out of the wall.
		var shelf_mid := dir * (T.GROTTO_R - 1.4)
		blk(structures, Vector3(shelf_mid.x, top - 0.8, shelf_mid.z), Vector3(4.2, 0.8, 3.4), "stone", Vector3(0, rad_to_deg(Player.yaw_of(dir)), 0), LevelBlock.Shape.BOX, "Shelf%d" % (k + 1))
		# The vent below it, plugged with sugar.
		var vent := SteamVent.new()
		vent.position = dir * (T.GROTTO_R - 5.8) + Vector3.UP * T.SAUCER_TOP
		vent.height = top - T.SAUCER_TOP + 1.2
		b.add(vent, g, "Vent%d" % (k + 1))
		var plug := SugarPlug.new()
		plug.plug_id = StringName("teacup_plug_%d" % (k + 1))
		plug.vent = vent
		plug.position = vent.position
		b.add(plug, g, "Plug%d" % (k + 1))
		var on := Vector3(shelf_mid.x, top, shelf_mid.z) + dir * 0.4
		match d[2]:
			"parrot":
				cage(on, "teacup_parrot_grotto", ParrotModel.Plumage.LIME)
			"teapot":
				var chest := TreasureChest.new()
				chest.chest_id = &"teacup_chest"
				chest.island_id = ISLAND
				chest.contents = "teapot"
				chest.gold_variant = true
				chest.position = on
				chest.rotation.y = Player.yaw_of(-dir)
				b.add(chest, g, "TeapotChest")
			"gem":
				gem(on + Vector3.UP * 0.8, "teacup_gem_grotto", Palette.GEM_RED)
	# The sugar wall across the way out, at the tunnel's inner mouth.
	var wall := CrackedRock.new()
	wall.look = "sugar"
	wall.rock_id = &"teacup_sugar_wall"
	wall.size = Vector3(3.6, T.TUNNEL_TOP - T.SAUCER_TOP, 1.0)
	var ta := T.TUNNEL_ANGLE
	wall.position = Vector3(cos(ta), 0, sin(ta)) * (T.GROTTO_R + 0.6) + Vector3.UP * T.SAUCER_TOP
	wall.rotation.y = Player.yaw_of(Vector3(cos(ta), 0, sin(ta)))
	b.add(wall, g, "SugarWall")
	_checkpoint(g, "cp_teacup_grotto", Vector3(-3.0, T.SAUCER_TOP, 4.0), 0.0, "CpGrotto")
	coin_trail(Vector3(-5, 1.9, -2), Vector3(5, 1.9, -2), 5, 0.0, CoinTrail.TrailShape.LINE)


## Coins up the spoon and round the saucer, crabs, a heart, and a gem on
## top of the handle.
func _outside() -> void:
	var foot := T.spoon_foot()
	var top := T.spoon_top()
	coin_trail(foot + Vector3.UP * 1.0, top + Vector3.UP * 1.0, 7, 0.0, CoinTrail.TrailShape.LINE)
	for d: Array in [[30.0, 70.0], [110.0, 150.0], [250.0, 290.0]]:
		var a0 := deg_to_rad(d[0])
		var a1 := deg_to_rad(d[1])
		coin_trail(Vector3(cos(a0) * 34.0, T.SAUCER_TOP + 0.9, sin(a0) * 34.0), Vector3(cos(a1) * 34.0, T.SAUCER_TOP + 0.9, sin(a1) * 34.0), 4, 0.0, CoinTrail.TrailShape.LINE)
	for d: Array in [[Vector3(-20, T.SAUCER_TOP + 0.05, -32), "teacup_crab_1"], [Vector3(31, T.SAUCER_TOP + 0.05, 14), "teacup_crab_2"]]:
		crab(d[0], CrabModel.Variant.NORMAL, d[1])
	heart(Vector3(-36, T.SAUCER_TOP + 0.6, 6))
	# On the crest of the handle, a walk up its back from the rim.
	var ta := T.TUNNEL_ANGLE
	gem(Vector3(cos(ta), 0, sin(ta)) * 33.0 + Vector3.UP * 21.8, "teacup_gem_handle", Palette.GEM_BLUE)


func _hints() -> void:
	var g := b.group("Hints", gameplay)
	var top := T.spoon_top()
	for d: Array in [
			["hint_teacup_tea", top, Vector3(6, 4, 6), "The tea's swirling round... jump in and see where it goes!", &""],
			["hint_teacup_plug", Vector3(0, T.SAUCER_TOP, 0), Vector3(8, 5, 8), "{tool_primary} Yank the sugar cubes out of the vents with the grapple", &"grapple"],
			["hint_teacup_wall", Vector3(cos(T.TUNNEL_ANGLE), 0, sin(T.TUNNEL_ANGLE)) * (T.GROTTO_R - 3.0) + Vector3.UP * T.SAUCER_TOP, Vector3(5, 4, 5), "A wall of sugar... the cannon should crack it", &"cannon"]]:
		var h := TutorialHint.new()
		h.hint_id = StringName(d[0])
		h.position = d[1]
		h.size = d[2]
		h.text = d[3]
		h.require_attachment = d[4]
		b.add(h, g, String(d[0]).capitalize().replace(" ", ""))


func _checkpoint(parent: Node, id: String, pos: Vector3, yaw: float, node_name: String) -> void:
	var cp := Checkpoint.new()
	cp.checkpoint_id = StringName(id)
	cp.position = pos
	cp.respawn_yaw = yaw
	b.add(cp, parent, node_name)
