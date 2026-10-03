extends IslandBuilder
## Generates res://world/islands/hat_rock/hat_rock.tscn: Hat Rock, "a sea
## stack shaped exactly like a pirate's hat" (docs/ARCHIPELAGO.md), north of
## Castaway Cay. Built in the island's own frame (HatRock: its place in the
## archipelago, turned so -Z faces Castaway Cay):
##  - A landing beach and jetty at the front, where the boat comes in.
##  - Boulders up to the brim's low front edge, then the brim itself.
##  - The ledge spiralling up the crown to the lookout on the top.
##   tools/builders/build.sh hat_rock

const ISLAND := &"hat_rock"

var root: Node3D


func build() -> void:
	seed(20261003)
	root = island_root(ISLAND, "HatRock")
	begin("HatRock", ISLAND, "Hat Rock", &"castaway_explore", root)
	_rock()
	_beach()
	_landing()
	_climb()
	horizon([ISLAND])
	open_sea(root.position, 420.0)
	spawn(root.transform * Vector3(6, 1.5, -71), root.transform.basis * Vector3(0, 0, 1))
	b.save("res://world/islands/hat_rock/hat_rock.tscn")


func _rock() -> void:
	var hat := HorizonHatRock.new()
	hat.playable = true
	b.add(hat, terrain, "Hat")


## Sand all round the stack's foot, widest at the front where boats land.
func _beach() -> void:
	var ring: Array = []
	for k in 22:
		var a := TAU * k / 22.0
		var r := 44.0 + 26.0 * pow(maxf(-sin(a), 0.0), 1.5) + sin(a * 5.0) * 2.0
		ring.append(Vector2(cos(a) * r, sin(a) * r))
	plateau(terrain, "Beach", ring, 1.0, 9.0, "sand", {"shore": true, "shore_width": 14.0, "shore_drop": 5.0, "seed": 61})
	var n := b.group("Nature", root)
	var k := 300
	for d: Array in [[Vector3(-26, 1.0, -48), 7.0, 14.0, 200.0], [Vector3(24, 1.0, -50), 6.5, 18.0, -30.0], [Vector3(-36, 1.0, -30), 6.0, 12.0, 250.0],
			[Vector3(34, 1.0, -34), 7.5, 16.0, -70.0], [Vector3(-14, 1.0, -62), 6.0, 20.0, 160.0]]:
		k += 7
		palm(n, d[0], d[1], d[2], d[3], k)
	rock(n, Vector3(-18, 1.0, -64), Vector3(2.0, 1.4, 1.8), StylizedRock.Preset.SAND_ROCK, 81)
	rock(n, Vector3(30, 1.0, -56), Vector3(1.6, 1.1, 1.4), StylizedRock.Preset.MOSSY, 83)


## The jetty, the boat, the waters and the checkpoint.
func _landing() -> void:
	var g := b.group("Landing", gameplay)
	var jetty := Dock.new()
	jetty.length = 12.0
	jetty.width = 2.6
	jetty.post_depth = 7.0
	jetty.water_line = -1.0
	jetty.position = Vector3(6, 1.1, -66)
	b.add(jetty, g, "Jetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(9.6, 0.0, -75)
	mooring.rotation.y = PI
	b.add(mooring, g, "BoatMooring")
	var arrival := Marker3D.new()
	arrival.position = Vector3(6, 1.4, -68)
	b.add(arrival, g, "Arrival")
	arrival.rotation.y = PI
	boat(g, mooring, 230.0)
	waters(g, Vector3.ZERO, 100.0, mooring, arrival, "Hat Rock")
	var cp := Checkpoint.new()
	cp.checkpoint_id = &"cp_hat_rock"
	cp.position = Vector3(-4, 1.0, -62)
	cp.respawn_yaw = 180.0
	b.add(cp, g, "CpBeach")


## Boulders up to the brim's low front edge (a ledge grab from the top one).
func _climb() -> void:
	var g := b.group("Climb", gameplay)
	var edge := HorizonHatRock.BRIM_OUT
	blk(g, Vector3(-3.5, 1.0, -edge - 7.5), Vector3(4.4, 2.5, 4.4), "rock", Vector3(0, 12, 0), LevelBlock.Shape.BOX, "Step1")
	blk(g, Vector3(0.5, 1.0, -edge - 4.2), Vector3(3.6, 5.5, 3.6), "rock", Vector3(0, -8, 0), LevelBlock.Shape.BOX, "Step2")
	coin_trail(Vector3(-3.5, 4.2, -edge - 7.5), Vector3(0.5, 7.2, -edge - 4.2), 3, 1.0)
