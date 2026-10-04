extends IslandBuilder
## Generates res://world/islands/bell_atoll/bell_atoll.tscn: Bell Atoll, "a
## ring of reef where five bells play a sailor's song" (docs/ARCHIPELAGO.md),
## south-east of Castaway Cay. Built in the island's own frame (BellAtoll:
## its place in the archipelago, turned so -Z faces Castaway Cay):
##  - The landing rock and its jetty at the front, a sand spit out to the
##    islet in the middle, and the reef ring all round the lagoon.
##  - Five bells on the tall reef rocks, each with its note painted as a
##    wave; the song carved on a stone by the belfry. Ring them in order
##    before the tide comes in (BellSong, Tide). A wrong note: the gulls
##    laugh.
##  - The song done, a dais rises from the lagoon with a chest (a crown and
##    the Shanty Sheet) and a parrot.
##  - Grapple up into the belfry's chamber: the great bell plays the song
##    through, and there's a gem. Another gem lies on the lagoon floor.
##   tools/builders/build.sh bell_atoll

const ISLAND := &"bell_atoll"
const A := preload("res://world/horizon/horizon_bell_atoll.gd")
## The note of the bell on each bell rock (A.BELL_ROCKS order).
const NOTES_AT := [3, 1, 5, 2, 4]
const SONG := [4, 3, 5, 2, 1]

var root: Node3D
var _bells: Array[ReefBell] = []
var _great: ReefBell
var _dais: RisingDais
var _tide: Tide
var _gulls: Array[Node3D] = []


func build() -> void:
	seed(20261004)
	root = island_root(ISLAND, "BellAtoll")
	begin("BellAtoll", ISLAND, "Bell Atoll", &"castaway_explore", root)
	_rock()
	_landing()
	_bells_and_song()
	_belfry()
	_reef()
	_dais_and_reward()
	_hints()
	seabed(root.position, 300.0)
	b.save("res://world/islands/bell_atoll/bell_atoll.tscn")


func _rock() -> void:
	var atoll := HorizonBellAtoll.new()
	atoll.playable = true
	b.add(atoll, terrain, "Atoll")


## The jetty off the landing rock, the boat, the waters and a checkpoint.
func _landing() -> void:
	var g := b.group("Landing", gameplay)
	var edge := -A.RING_R - A.rock_half(0).y
	var jetty := Dock.new()
	jetty.length = 10.0
	jetty.width = 2.6
	jetty.post_depth = 6.0
	jetty.water_line = -0.9
	jetty.position = Vector3(0, 1.3, edge + 1.0)
	b.add(jetty, g, "Jetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(3.0, 0.0, edge - 7.5)
	mooring.rotation.y = PI
	b.add(mooring, g, "BoatMooring")
	var arrival := Marker3D.new()
	arrival.position = Vector3(0, 1.6, edge - 6.0)
	arrival.rotation.y = PI
	b.add(arrival, g, "Arrival")
	waters(g, Vector3.ZERO, 75.0, mooring, arrival, "Bell Atoll")
	_checkpoint(g, "cp_bell_landing", A.rock_top(0) + Vector3(-2.5, 0, -2.0), 0.0, "CpLanding")
	heart(A.rock_top(0) + Vector3(4.0, 0.6, 2.5))


## The five bells (facing the lagoon), the song stone, the tide and the
## song that ties them together.
func _bells_and_song() -> void:
	var g := b.group("Bells", gameplay)
	for j in 5:
		var at := A.bell_spot(j)
		var bell := ReefBell.new()
		bell.note = NOTES_AT[j]
		bell.position = at
		bell.basis = Basis.looking_at(Vector3(-at.x, 0, -at.z).normalized())
		b.add(bell, g, "Bell%d" % (j + 1))
		_bells.append(bell)
	var stone := SongStone.new()
	stone.song = PackedInt32Array(SONG)
	stone.position = Vector3(0, A.ISLET_TOP, -6.6)
	b.add(stone, g, "SongStone")
	_tide = Tide.new()
	_tide.high = A.HIGH_TIDE
	_tide.rise_time = 60.0
	_tide.fall_time = 5.0
	b.add(_tide, g, "Tide")


## The great bell in the belfry's chamber, the iron ring to grapple up to
## it, and a gem up there.
func _belfry() -> void:
	var g := b.group("Belfry", gameplay)
	_great = ReefBell.new()
	_great.note = 0
	_great.position = A.great_bell_at()
	b.add(_great, g, "GreatBell")
	var floor_at := A.chamber_floor()
	var iron := HookPoint.new()
	iron.grapple_only = true
	iron.grapple_arrival = "hop"
	iron.hang_length = 0.0
	# On the east side, clear of the song stone in front.
	iron.position = floor_at + Vector3(A.BELFRY.x * 0.5 + 1.0, 1.5, 0)
	iron.scale = Vector3.ONE * 1.4
	b.add(iron, g, "BelfryIron")
	gem(floor_at + Vector3(-1.4, 0.9, 1.4), "bell_atoll_gem_belfry", Palette.GEM_BLUE)
	_checkpoint(g, "cp_bell_islet", Vector3(-3.6, A.ISLET_TOP, -5.6), 0.0, "CpIslet")


## The dais behind the belfry, down in the lagoon until the song is played,
## with the chest (a crown and the Shanty Sheet) and a parrot on it.
func _dais_and_reward() -> void:
	var g := b.group("Reward", gameplay)
	_dais = RisingDais.new()
	_dais.raised_id = &"bell_atoll_dais"
	_dais.radius = 3.4
	_dais.drop = 5.6
	_dais.position = Vector3(0, A.ISLET_TOP, A.ISLET_R * 0.92 + 2.8)
	b.add(_dais, g, "Dais")
	var chest := TreasureChest.new()
	chest.chest_id = &"bell_atoll_chest"
	chest.island_id = ISLAND
	chest.contents = "crown"
	chest.key_item_reward = &"shanty_sheet"
	chest.gold_variant = true
	chest.position = Vector3(0.9, 0, 0.9)
	chest.rotation.y = PI + 0.3
	b.add(chest, _dais, "Chest")
	var cage := ParrotCage.new()
	cage.parrot_id = &"bell_atoll_parrot"
	cage.island_id = ISLAND
	cage.plumage = ParrotModel.Plumage.SUNNY
	cage.position = Vector3(-1.5, 0, 0.6)
	b.add(cage, _dais, "ParrotCage_bell_atoll_parrot")
	var song := BellSong.new()
	song.bells = _bells
	song.great_bell = _great
	song.song = PackedInt32Array(SONG)
	song.tide = _tide
	song.dais = _dais
	song.gulls = _gulls
	b.add(song, g, "BellSong")


## Gulls, crabs, coins round the ring and a gem on the lagoon floor.
func _reef() -> void:
	var g := b.group("Reef", gameplay)
	for k: int in [2, 4, 8, 10]:
		var top := A.rock_top(k)
		var gull := ReefGull.new()
		gull.position = top + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.0, 1.0))
		gull.rotation.y = Player.yaw_of(Vector3(-top.x, 0, -top.z)) + randf_range(-0.6, 0.6)
		b.add(gull, g, "Gull")
		_gulls.append(gull)
	for k in 12:
		var top := A.rock_top(k)
		if k in A.BELL_ROCKS:
			continue
		# A short run of coins along each low rock.
		var a := A.rock_angle(k)
		var along := Vector3(-sin(a), 0, cos(a))
		coin_trail(top + Vector3.UP * 0.9 - along * 3.0, top + Vector3.UP * 0.9 + along * 3.0, 3, 0.0, CoinTrail.TrailShape.LINE)
	for k: int in [6, 11]:
		crab(A.rock_top(k) + Vector3(0, 0.05, 0), CrabModel.Variant.NORMAL, "bell_atoll_crab_%d" % k)
	gem(Vector3(15.0, A.LAGOON + 0.8, -9.0), "bell_atoll_gem_lagoon", Palette.GEM_RED)
	coin_trail(Vector3(0, A.SPIT_TOP + 0.9, -A.RING_R + 8.0), Vector3(0, A.SPIT_TOP + 0.9, -A.ISLET_R - 1.0), 6, 0.0, CoinTrail.TrailShape.LINE)


func _hints() -> void:
	var g := b.group("Hints", gameplay)
	for d: Array in [
			["hint_song_stone", Vector3(0, A.ISLET_TOP, -8.2), Vector3(6, 4, 4), "The song: count each wave's crests, and ring the bell with that wave", &""],
			["hint_bell", A.bell_spot(0), Vector3(7, 4, 7), "{attack} Swipe a bell to ring it  ·  the cannon or a ground pound works too", &""],
			["hint_belfry_grapple", Vector3(5.5, A.ISLET_TOP, 0), Vector3(4, 4, 6), "{tool_primary} Grapple up into the belfry", &"grapple"]]:
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
