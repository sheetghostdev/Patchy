extends RefCounted
## Generates res://props/prop_gallery.tscn: every prop of the props & nature
## kit laid out in labelled rows on a little island (meadow, beach, sea) with
## a few Patchy models for scale, for art review and screenshots.
##   godot --headless --path . res://props/tools/run_prop_builder.tscn -- prop_gallery
## Photograph it with tools/photo/shoot.sh scene=res://props/prop_gallery.tscn ...

const OUT := "res://props/prop_gallery.tscn"
const PATCHY := preload("res://characters/patchy/patchy_model.gd")

var b: SceneBuilder


func build() -> void:
	b = SceneBuilder.new("PropGallery")
	b.add(SkyEnvironment.new(), null, "SkyEnvironment")
	_ground()
	_palms_and_rocks(b.group("PalmsAndRocks"))
	_foliage(b.group("Foliage"))
	_structures(b.group("Structures"))
	_treasure(b.group("Treasure"))
	_beach(b.group("ShipwreckBeach"))
	b.save(OUT)


func put(parent: Node, node: Node3D, pos: Vector3, yaw: float = 0.0, node_name: String = "") -> Node3D:
	node.position = pos
	node.rotation_degrees.y = yaw
	var script := node.get_script() as Script
	b.add(node, parent, node_name if node_name != "" else String(script.get_global_name()))
	return node


func patchy(parent: Node, pos: Vector3, yaw: float) -> void:
	var p: Node3D = PATCHY.new()
	put(parent, p, pos, yaw, "PatchyForScale")


func title(parent: Node, pos: Vector3, text: String) -> void:
	b.label(parent, pos, text, 84, Color(1.0, 0.93, 0.7))


func _ground() -> void:
	var g := b.group("Ground")
	b.block(g, Vector3(0, -1, -3), Vector3(52, 1, 26), "grass", "", LevelBlock.Shape.BOX, 0, "Meadow")
	b.block(g, Vector3(0, -1, 17), Vector3(52, 1, 14), "sand", "", LevelBlock.Shape.BOX, 0, "Beach")
	b.block(g, Vector3(0, -4, 35), Vector3(52, 1, 22), "sand", "", LevelBlock.Shape.BOX, 0, "SeaFloor")
	b.block(g, Vector3(19, -1, 12.5), Vector3(4, 4, 5), "cliff", "", LevelBlock.Shape.BOX, 0, "CliffA")
	b.block(g, Vector3(19, -4, 26.5), Vector3(4, 7, 5), "cliff", "", LevelBlock.Shape.BOX, 0, "CliffB")
	var water := WaterVolume.new()
	water.size = Vector3(52, 4, 22)
	put(g, water, Vector3(0, -0.4, 35), 0.0, "Sea")


func _palms_and_rocks(p: Node) -> void:
	title(p, Vector3(-23, 3.0, -12), "PALMS & ROCKS")
	var palms := [[4.0, 4.0, 0.0, 7, 2.6], [7.0, 14.0, 30.0, 8, 3.4], [11.0, 22.0, -50.0, 9, 4.0], [6.0, 2.0, 0.0, 8, 3.2]]
	for k in palms.size():
		var s: Array = palms[k]
		var palm := PalmTree.new()
		palm.height = s[0]
		palm.lean_degrees = s[1]
		palm.lean_direction = s[2]
		palm.frond_count = s[3]
		palm.frond_length = s[4]
		palm.seed = k + 1
		put(p, palm, Vector3(-18 + k * 5.4, 0, -12))
	var rocks := [
		[StylizedRock.Preset.SAND_ROCK, Vector3(2.6, 1.8, 2.2), 2.5],
		[StylizedRock.Preset.CLIFF_ROCK, Vector3(3.0, 2.2, 2.6), 6.5],
		[StylizedRock.Preset.DARK_ROCK, Vector3(2.4, 1.6, 2.0), 10.5],
		[StylizedRock.Preset.MOSSY, Vector3(3.2, 1.6, 2.6), 14.5],
	]
	for k in rocks.size():
		var r := StylizedRock.new()
		r.preset = rocks[k][0]
		r.size = rocks[k][1]
		r.seed = k + 3
		put(p, r, Vector3(rocks[k][2], 0, -12))
		var small := StylizedRock.new()
		small.preset = rocks[k][0]
		small.size = Vector3(1.0, 0.7, 0.9)
		small.seed = k + 30
		put(p, small, Vector3(rocks[k][2] + 1.3, 0, -9.8), k * 40.0)
	var stone := StylizedRock.new()
	stone.preset = StylizedRock.Preset.CLIFF_ROCK
	stone.size = Vector3(1.4, 3.0, 1.3)
	stone.facets = 8
	stone.seed = 9
	put(p, stone, Vector3(18.2, 0, -12))
	patchy(p, Vector3(-15.6, 0, -10.5), -20)


func _foliage(p: Node) -> void:
	title(p, Vector3(-23, 2.2, -5.5), "FOLIAGE & SCATTER")
	var bushes := [[0, PropFoliage.Bloom.PINK, 1.0], [8, PropFoliage.Bloom.PINK, 1.15], [10, PropFoliage.Bloom.YELLOW, 1.4]]
	for k in bushes.size():
		var bush := Bush.new()
		bush.flowers = bushes[k][0]
		bush.bloom = bushes[k][1]
		bush.size = Vector3(1.2, 0.9, 1.2) * float(bushes[k][2])
		bush.seed = k + 1
		put(p, bush, Vector3(-18.5 + k * 2.3, 0, -5.5))
	for k in 3:
		var g := GrassTuft.new()
		g.seed = k + 1
		put(p, g, Vector3(-11.6 + k * 0.85, 0, -5.5))
	var blooms := [PropFoliage.Bloom.MIXED, PropFoliage.Bloom.PINK, PropFoliage.Bloom.YELLOW]
	for k in 3:
		var f := FlowerPatch.new()
		f.bloom = blooms[k]
		f.seed = k + 1
		put(p, f, Vector3(-8.6 + k * 1.1, 0, -5.5))
	for k in 2:
		var fern := Fern.new()
		fern.size = 0.85 + k * 0.4
		fern.seed = k + 1
		put(p, fern, Vector3(-4.6 + k * 1.9, 0, -5.5))
	var kinds := [[PropScatter.Kind.GRASS, 3.0, 0.3, 1], [PropScatter.Kind.FLOWERS, 0.5, 0.5, 2], [PropScatter.Kind.PEBBLES, 0.15, 0.6, 3], [PropScatter.Kind.FERNS, 0.06, 1.2, 4]]
	for k in kinds.size():
		var sc := PropScatter.new()
		sc.kind = kinds[k][0]
		sc.density = kinds[k][1]
		sc.min_spacing = kinds[k][2]
		sc.seed = kinds[k][3]
		sc.area_size = Vector2(17, 5)
		sc.surface_filter = [&"grass"]
		put(p, sc, Vector3(10.5, 0.5, -5.5), 0.0, "Scatter%d" % k)


func _structures(p: Node) -> void:
	title(p, Vector3(-23, 2.6, 1), "STRUCTURES")
	var c1 := Crate.new()
	put(p, c1, Vector3(-19, 0, 1), 12)
	var c2 := Crate.new()
	c2.breakable = false
	put(p, c2, Vector3(-17.5, 0, 1.2), -10)
	var c3 := Crate.new()
	c3.size = Vector3.ONE * 0.7
	c3.seed = 3
	put(p, c3, Vector3(-19, 1.0, 1), 40)
	var c4 := Crate.new()
	c4.style = Crate.Style.SLATS
	c4.size = Vector3(1.4, 0.8, 1.0)
	put(p, c4, Vector3(-15.8, 0, 1.4), 5)
	var b1 := Barrel.new()
	put(p, b1, Vector3(-13.9, 0, 0.8))
	var b2 := Barrel.new()
	b2.hoops = Barrel.Hoops.BRASS
	b2.seed = 2
	put(p, b2, Vector3(-12.8, 0, 0.6))
	var b3 := Barrel.new()
	b3.lying = true
	b3.seed = 3
	put(p, b3, Vector3(-13.3, 0, 2.4), 75)
	var post := Signpost.new()
	post.texts = PackedStringArray(["Shipwreck Cove", "Lookout", "Village"])
	post.directions = PackedFloat32Array([90.0, -40.0, 180.0])
	put(p, post, Vector3(-10.4, 0, 1.2))
	var fx := -8.6
	for st in [FenceSegment.Style.RAIL, FenceSegment.Style.PICKET, FenceSegment.Style.BAMBOO]:
		var f := FenceSegment.new()
		f.style = st
		put(p, f, Vector3(fx, 0, 2.8))
		fx += 2.8
	put(p, Torch.new(), Vector3(0.0, 0, 1))
	put(p, LanternPost.new(), Vector3(1.4, 0, 0.6))
	put(p, Bollard.new(), Vector3(3.0, 0, 1.6))
	var bw := Bollard.new()
	bw.style = Bollard.Style.WOOD
	put(p, bw, Vector3(3.8, 0, 1.6))
	put(p, RopeCoil.new(), Vector3(5.0, 0, 1.8))
	put(p, Anchor.new(), Vector3(7.0, 0, 0.8), -15)
	var an2 := Anchor.new()
	an2.lying = true
	an2.size = 1.4
	put(p, an2, Vector3(9.4, 0, 2.0), 20)
	put(p, DecorCannon.new(), Vector3(12.6, 0, 1.4), 160)
	put(p, Bell.new(), Vector3(16.0, 0, 0.8))
	# Loose physics crates (pushable / stackable), one breakable on top.
	for k in 3:
		var pc := PhysicsCrate.new()
		pc.seed = k + 5
		put(p, pc, Vector3(18.6 + (k % 2) * 1.0, 0.02 + floorf(k / 2.0) * 0.93, 1.0 - (k % 2) * 0.1), k * 12.0, "PhysicsCrate%d" % k)
	var pcb := PhysicsCrate.new()
	pcb.breakable = true
	pcb.size = Vector3.ONE * 0.7
	put(p, pcb, Vector3(19.6, 0.95, 0.9), 30, "PhysicsCrateBreakable")
	patchy(p, Vector3(-11.6, 0, 2.6), 15)


func _treasure(p: Node) -> void:
	title(p, Vector3(-23, 2.0, 7), "TREASURE")
	var cage := ParrotCageModel.new()
	put(p, cage, Vector3(-9, 0, 7), 165)
	var cage2 := ParrotCageModel.new()
	cage2.metal = ParrotCageModel.Metal.IRON
	cage2.door_open = 1.0
	put(p, cage2, Vector3(-7.3, 0, 7.3), 200)
	var c1 := TreasureChestModel.new()
	put(p, c1, Vector3(-5.1, 0, 7), 175)
	var c2 := TreasureChestModel.new()
	c2.open_amount = 0.75
	put(p, c2, Vector3(-3.3, 0, 7.1), 185)
	var c3 := TreasureChestModel.new()
	c3.variant = TreasureChestModel.Variant.GOLD
	c3.open_amount = 1.0
	put(p, c3, Vector3(-1.4, 0, 6.9), 170)
	var pile := TreasureDisplay.new()
	pile.kind = TreasureDisplay.Kind.PILE
	put(p, pile, Vector3(0.6, 0, 7.3))
	var gems := [Palette.GEM_RED, Palette.GEM_BLUE, PropPalette.GEM_GREEN, PropPalette.GEM_PURPLE, PropPalette.GEM_YELLOW]
	for k in 5:
		var coin := TreasureDisplay.new()
		put(p, coin, Vector3(2.2 + k * 0.8, 0, 6.9), k * 30.0, "Coin%d" % k)
		var gem := TreasureDisplay.new()
		gem.kind = TreasureDisplay.Kind.GEM
		gem.gem_color = gems[k]
		put(p, gem, Vector3(2.6 + k * 0.8, 0, 7.9), k * 20.0, "Gem%d" % k)
	patchy(p, Vector3(7.6, 0, 7.2), -25)


func _beach(p: Node) -> void:
	title(p, Vector3(-23, 3.0, 16), "SHIPWRECK BEACH")
	var hull := HullSection.new()
	put(p, hull, Vector3(-15.5, 0, 16.5), 20)
	var debris := ShipDebris.new()
	debris.radius = 3.0
	put(p, debris, Vector3(-9.5, 0, 14.2))
	var mast := BrokenMast.new()
	mast.tilt_direction = 70.0
	put(p, mast, Vector3(-11, 0, 20.2))
	var bow := BowPiece.new()
	put(p, bow, Vector3(-3.8, 0, 19.6), 150)
	var palm := PalmTree.new()
	palm.height = 8.0
	palm.lean_degrees = 24.0
	palm.lean_direction = 150.0
	palm.frond_length = 3.6
	palm.seed = 7
	put(p, palm, Vector3(1.5, 0, 12.6))
	var palm2 := PalmTree.new()
	palm2.height = 6.0
	palm2.lean_degrees = 10.0
	palm2.lean_direction = -120.0
	palm2.seed = 8
	put(p, palm2, Vector3(14.5, 0, 12.8))
	var dock := Dock.new()
	dock.length = 12.0
	put(p, dock, Vector3(6.5, 0.16, 21.5), 180)
	for x: float in [4.8, 8.2]:
		put(p, Torch.new(), Vector3(x, 0, 21.0), 0.0, "DockTorch")
	put(p, Crate.new(), Vector3(3.2, 0, 19.0), 25, "BeachCrate")
	put(p, Barrel.new(), Vector3(4.3, 0, 18.4), 0.0, "BeachBarrel")
	var s1 := StylizedRock.new()
	s1.preset = StylizedRock.Preset.SAND_ROCK
	s1.size = Vector3(2.2, 1.4, 1.9)
	s1.seed = 41
	put(p, s1, Vector3(11.5, 0, 17.5))
	var s2 := StylizedRock.new()
	s2.preset = StylizedRock.Preset.SAND_ROCK
	s2.size = Vector3(1.0, 0.7, 0.9)
	s2.seed = 42
	put(p, s2, Vector3(12.9, 0, 18.8))
	var sea_rock := StylizedRock.new()
	sea_rock.preset = StylizedRock.Preset.DARK_ROCK
	sea_rock.size = Vector3(3.0, 7.0, 2.6)
	sea_rock.seed = 43
	put(p, sea_rock, Vector3(12, -3, 28))
	var bridge := RopeBridge.new()
	bridge.end_point = Vector3(0, 0, 9)
	put(p, bridge, Vector3(19, 3, 15))
	patchy(p, Vector3(6.2, 0.16, 23.5), 160)
	patchy(p, Vector3(-7.2, 0, 16.6), -30)
