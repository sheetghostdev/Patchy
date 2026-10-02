extends Node3D
## Dev showroom for iterating on prop art: lays out a named set of props on a
## small island so the photo tool can frame them.
##   tools/photo/shoot.sh scene=res://props/tests/prop_viewer.tscn show=palms \
##       out=/tmp/palms_%d.png "cams=0,4,14>0,3,0"
## Sets (show=): palms, rocks, foliage, crates, dock, wreck, treasure, misc.
## Options: night=1 (dark preset to judge torches/lanterns), break=N (smash
## every breakable after N frames), vcam=x,y,z>lx,ly,lz (own camera, for
## the photo tool's snaps=), nossao=1 / noglow=1 / nomsaa=1 (render debug).


func _ready() -> void:
	var which := "palms"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("show="):
			which = a.substr(5)
	var env := SkyEnvironment.new()
	add_child(env)
	for a in OS.get_cmdline_user_args():
		if a == "nossao=1":
			env.world_env.environment.ssao_enabled = false
		if a == "noglow=1":
			env.world_env.environment.glow_enabled = false
		if a == "nomsaa=1":
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
		if a == "night=1":
			env.preset = SkyEnvironment.Preset.CAVE
	var ground := LevelBlock.new()
	ground.size = Vector3(60, 1, 60)
	ground.surface = "grass" if which != "dock" else "sand"
	ground.position = Vector3(0, -1, 0)
	add_child(ground)
	var method := "_show_%s" % which
	if has_method(method):
		call(method)
	else:
		push_error("prop_viewer: unknown set %s" % which)
	# vcam=x,y,z>lx,ly,lz: a camera of our own (for the photo tool's snaps=).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("vcam="):
			var parts := a.substr(5).split(">")
			var p := parts[0].split(",")
			var l := parts[1].split(",")
			var cam := Camera3D.new()
			cam.fov = 50.0
			add_child(cam)
			cam.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
			cam.look_at(Vector3(float(l[0]), float(l[1]), float(l[2])))
			cam.make_current()
	# break=N: smash every breakable after N frames (debris preview).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("break="):
			for i in int(a.substr(6)):
				await get_tree().process_frame
			for n in get_children():
				if n is BreakableProp:
					(n as BreakableProp).take_hit({"damage": 1, "kind": &"swipe", "source": self, "position": (n as Node3D).global_position + Vector3(0, 0.5, 2), "direction": Vector3.FORWARD})


func _place(n: Node3D, pos: Vector3, yaw_deg: float = 0.0) -> Node3D:
	n.position = pos
	n.rotation_degrees.y = yaw_deg
	add_child(n)
	return n


func _show_rocks() -> void:
	var presets := [StylizedRock.Preset.SAND_ROCK, StylizedRock.Preset.CLIFF_ROCK, StylizedRock.Preset.DARK_ROCK, StylizedRock.Preset.MOSSY]
	for k in presets.size():
		var big := StylizedRock.new()
		big.preset = presets[k]
		big.size = Vector3(2.4, 1.7, 2.1)
		big.seed = k + 1
		_place(big, Vector3(-6.0 + k * 4.0, 0, 0))
		var small := StylizedRock.new()
		small.preset = presets[k]
		small.size = Vector3(1.0, 0.7, 0.9)
		small.seed = k + 11
		_place(small, Vector3(-4.6 + k * 4.0, 0, 2.0))
		var tall := StylizedRock.new()
		tall.preset = presets[k]
		tall.size = Vector3(1.3, 2.6, 1.2)
		tall.seed = k + 21
		tall.facets = 7
		_place(tall, Vector3(-6.8 + k * 4.0, 0, -2.6))
	var p := Node3D.new()
	_place(p, Vector3.ZERO)


func _show_foliage() -> void:
	for k in 3:
		var b := Bush.new()
		b.seed = k + 1
		b.size = Vector3(1.2, 0.9, 1.2) * (0.8 + k * 0.25)
		b.flowers = [0, 6, 10][k]
		b.bloom = [PropFoliage.Bloom.PINK, PropFoliage.Bloom.RED, PropFoliage.Bloom.YELLOW][k]
		_place(b, Vector3(-5.0 + k * 2.2, 0, 0))
	for k in 3:
		var g := GrassTuft.new()
		g.seed = k + 1
		_place(g, Vector3(-5.0 + k * 0.9, 0, 2.2))
	for k in 3:
		var f := FlowerPatch.new()
		f.seed = k + 1
		f.bloom = [PropFoliage.Bloom.MIXED, PropFoliage.Bloom.PINK, PropFoliage.Bloom.YELLOW][k]
		_place(f, Vector3(-1.6 + k * 1.0, 0, 2.2))
	for k in 2:
		var fe := Fern.new()
		fe.seed = k + 1
		fe.size = 0.8 + k * 0.4
		_place(fe, Vector3(2.0 + k * 1.8, 0, 1.6))
	var sc := PropScatter.new()
	sc.area_size = Vector2(8, 5)
	sc.density = 3.0
	sc.min_spacing = 0.3
	_place(sc, Vector3(0, 0.5, -5))
	var sf := PropScatter.new()
	sf.kind = PropScatter.Kind.FLOWERS
	sf.area_size = Vector2(8, 5)
	sf.density = 0.5
	sf.seed = 4
	_place(sf, Vector3(0, 0.5, -5))
	var sp := PropScatter.new()
	sp.kind = PropScatter.Kind.PEBBLES
	sp.area_size = Vector2(8, 5)
	sp.density = 0.3
	sp.seed = 5
	_place(sp, Vector3(0, 0.5, -5))


func _show_crates() -> void:
	var c1 := Crate.new()
	_place(c1, Vector3(-3.0, 0, 0), 20)
	var c2 := Crate.new()
	c2.breakable = false
	_place(c2, Vector3(-1.5, 0, 0), -15)
	var c3 := Crate.new()
	c3.style = Crate.Style.SLATS
	c3.size = Vector3(1.4, 0.8, 1.0)
	_place(c3, Vector3(0.2, 0, 0.2), 5)
	var c4 := Crate.new()
	c4.size = Vector3.ONE * 0.7
	_place(c4, Vector3(-3.0, 1.0, 0), 35)
	var b1 := Barrel.new()
	_place(b1, Vector3(1.8, 0, 0))
	var b2 := Barrel.new()
	b2.hoops = Barrel.Hoops.BRASS
	b2.seed = 2
	_place(b2, Vector3(2.9, 0, -0.4))
	var b3 := Barrel.new()
	b3.lying = true
	b3.seed = 3
	_place(b3, Vector3(2.4, 0, 1.4), 70)


func _block(pos: Vector3, size: Vector3, surface: String) -> LevelBlock:
	var b := LevelBlock.new()
	b.size = size
	b.surface = surface
	b.position = pos
	add_child(b)
	return b


func _show_dock() -> void:
	for c in get_children():
		if c is LevelBlock:
			c.free()
	_block(Vector3(0, -1, 8), Vector3(40, 1, 16), "sand")
	_block(Vector3(0, -4, -12), Vector3(40, 1, 24), "sand")
	var water := WaterVolume.new()
	water.size = Vector3(40, 4, 24)
	water.position = Vector3(0, -0.45, -12)
	add_child(water)
	var dock := Dock.new()
	dock.length = 10.0
	_place(dock, Vector3(-4, 0, 0.6))
	# Two cliffs with a rope bridge between them.
	_block(Vector3(6, -1, 0), Vector3(4, 4, 4), "cliff")
	_block(Vector3(6, -1, -14), Vector3(4, 4, 4), "cliff")
	var bridge := RopeBridge.new()
	bridge.end_point = Vector3(0, 0, -10)
	_place(bridge, Vector3(6, 3, -2))


func _show_misc() -> void:
	var post := Signpost.new()
	post.texts = PackedStringArray(["Shipwreck Cove", "Lookout", "Village"])
	post.directions = PackedFloat32Array([0.0, 120.0, -100.0])
	_place(post, Vector3(-5, 0, 0), 0)
	var fx := -3.0
	for st in [FenceSegment.Style.RAIL, FenceSegment.Style.PICKET, FenceSegment.Style.BAMBOO]:
		var f := FenceSegment.new()
		f.style = st
		_place(f, Vector3(fx, 0, 2.0))
		fx += 2.7
	var t := Torch.new()
	_place(t, Vector3(-2.5, 0, -1.0))
	var lp := LanternPost.new()
	_place(lp, Vector3(-1.0, 0, -1.2))
	var bo := Bollard.new()
	_place(bo, Vector3(0.6, 0, -0.5))
	var bw := Bollard.new()
	bw.style = Bollard.Style.WOOD
	_place(bw, Vector3(1.3, 0, -0.5))
	var rc := RopeCoil.new()
	_place(rc, Vector3(0.9, 0, 0.6))
	var an := Anchor.new()
	_place(an, Vector3(2.8, 0, -1.2), -20)
	var an2 := Anchor.new()
	an2.lying = true
	an2.size = 1.4
	_place(an2, Vector3(3.0, 0, 0.8), 30)
	var cn := DecorCannon.new()
	_place(cn, Vector3(5.2, 0, -0.5), -30)
	var be := Bell.new()
	_place(be, Vector3(7.6, 0, -1.0), -10)


func _show_wreck() -> void:
	for c in get_children():
		if c is LevelBlock:
			c.free()
	_block(Vector3(0, -1, 0), Vector3(60, 1, 60), "sand")
	var hull := HullSection.new()
	_place(hull, Vector3(-4.5, 0, 0), 15)
	var bow := BowPiece.new()
	_place(bow, Vector3(2.5, 0, 1.5), -35)
	var mast := BrokenMast.new()
	mast.tilt_direction = 70.0
	_place(mast, Vector3(-0.8, 0, -3.5))
	var debris := ShipDebris.new()
	_place(debris, Vector3(0.5, 0, 3.5))


func _show_treasure() -> void:
	var cage := ParrotCageModel.new()
	_place(cage, Vector3(-3.2, 0, 0), 20)
	var cage2 := ParrotCageModel.new()
	cage2.door_open = 1.0
	cage2.metal = ParrotCageModel.Metal.IRON
	_place(cage2, Vector3(-1.6, 0, 0.4), -15)
	var c1 := TreasureChestModel.new()
	_place(c1, Vector3(0.3, 0, 0.3), 10)
	var c2 := TreasureChestModel.new()
	c2.open_amount = 0.75
	_place(c2, Vector3(1.9, 0, 0.0), -10)
	var c3 := TreasureChestModel.new()
	c3.variant = TreasureChestModel.Variant.GOLD
	c3.open_amount = 1.0
	_place(c3, Vector3(3.5, 0, 0.3), -20)
	var gems := [Palette.GEM_RED, Palette.GEM_BLUE, PropPalette.GEM_GREEN, PropPalette.GEM_PURPLE, PropPalette.GEM_YELLOW]
	for k in 5:
		var coin := MeshInstance3D.new()
		coin.mesh = PropMeshes.coin()
		_place(coin, Vector3(-1.4 + k * 0.75, 0.5, 2.0), k * 25.0)
		var gem := MeshInstance3D.new()
		gem.mesh = PropMeshes.gem(gems[k])
		_place(gem, Vector3(-1.1 + k * 0.75, 0.45, 2.6), k * 20.0)


func _show_palms() -> void:
	var specs := [
		[4.0, 4.0, 0.0, 7, 2.6, 1],
		[7.0, 14.0, 30.0, 8, 3.2, 2],
		[11.0, 22.0, -60.0, 9, 3.6, 3],
		[6.0, 0.0, 0.0, 6, 3.0, 4],
	]
	for k in specs.size():
		var s: Array = specs[k]
		var p := PalmTree.new()
		p.height = s[0]
		p.lean_degrees = s[1]
		p.lean_direction = s[2]
		p.frond_count = s[3]
		p.frond_length = s[4]
		p.seed = s[5]
		_place(p, Vector3(-9.0 + k * 6.0, 0, 0))
