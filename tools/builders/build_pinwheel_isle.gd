extends IslandBuilder
## Generates res://world/islands/pinwheel_isle/pinwheel_isle.tscn: Pinwheel
## Isle, "a tiny island bristling with giant spinning pinwheels"
## (docs/ARCHIPELAGO.md), north-west of Castaway Cay. Built in the island's
## own frame (PinwheelIsle: its place in the archipelago, turned so -Z
## faces Castaway Cay):
##  - A sandy skirt with a jetty at the front, and a mossy knob in three
##    sheer tiers above it.
##  - Three PinwheelLifts up the cliffs between the tiers, round the knob:
##    stand on a platform, spin the wheel above (cannon or grapple) and
##    ride the screw up. A gem on a nook beside the second.
##  - A parrot on the summit, and the great pole's lift up to the crow's
##    nest under the biggest wheel, with a Heart Piece.
##   tools/builders/build.sh pinwheel_isle

const ISLAND := &"pinwheel_isle"
const P := preload("res://world/horizon/horizon_pinwheel_isle.gd")

var root: Node3D


func build() -> void:
	seed(20261005)
	root = island_root(ISLAND, "PinwheelIsle")
	begin("PinwheelIsle", ISLAND, "Pinwheel Isle", &"castaway_explore", root)
	_rock()
	_landing()
	_lifts()
	_summit()
	_extras()
	_hints()
	horizon([ISLAND])
	open_sea(root.position, 420.0)
	var front: float = -float(P.TIERS[0][1].y)
	spawn(root.transform * Vector3(0, 1.5, front - 7.0), root.transform.basis * Vector3(0, 0, 1))
	b.save("res://world/islands/pinwheel_isle/pinwheel_isle.tscn")


func _rock() -> void:
	var isle := HorizonPinwheelIsle.new()
	isle.playable = true
	b.add(isle, terrain, "Isle")


func _landing() -> void:
	var g := b.group("Landing", gameplay)
	var front: float = -float(P.TIERS[0][1].y)
	var jetty := Dock.new()
	jetty.length = 10.0
	jetty.width = 2.6
	jetty.post_depth = 6.0
	jetty.water_line = -0.9
	jetty.position = Vector3(0, 1.0, front + 1.0)
	b.add(jetty, g, "Jetty")
	var mooring := Marker3D.new()
	mooring.position = Vector3(3.0, 0.0, front - 7.5)
	mooring.rotation.y = PI
	b.add(mooring, g, "BoatMooring")
	var arrival := Marker3D.new()
	arrival.position = Vector3(0, 1.4, front - 6.0)
	arrival.rotation.y = PI
	b.add(arrival, g, "Arrival")
	boat(g, mooring, 220.0)
	waters(g, Vector3.ZERO, 75.0, mooring, arrival, "Pinwheel Isle")
	_checkpoint(g, "cp_pinwheel_beach", Vector3(-4.0, P.TIERS[0][2], front + 5.0), 0.0, "CpBeach")


## The three lifts up the tiers, each with a landing deck at the top, and
## coins up the screw.
func _lifts() -> void:
	var g := b.group("Lifts", gameplay)
	for k in P.LIFTS.size():
		var lower: int = P.LIFTS[k][0]
		var base := P.lift_base(k)
		var out := P.lift_out(k)
		var lift := PinwheelLift.new()
		lift.position = base + Vector3.UP * 0.25
		lift.basis = Basis.looking_at(out)
		lift.travel = P.lift_top(k) - (base.y + 0.25)
		lift.pole_extra = 4.0
		lift.wheel_radius = 2.6
		lift.colors = k * 2
		b.add(lift, g, "Lift%d" % (k + 1))
		# A plank deck from the cliff top out to the platform's top stop.
		var rim := P.tier_rim(lower + 1, P.LIFTS[k][1], -1.2)
		var reach := base + out * -(PinwheelLift.PLATFORM_R + 0.1)
		var mid := (Vector3(rim.x, 0, rim.z) + Vector3(reach.x, 0, reach.z)) * 0.5
		var length := Vector2(reach.x - rim.x, reach.z - rim.z).length()
		blk(structures, Vector3(mid.x, P.lift_top(k) - 0.3, mid.z), Vector3(2.6, 0.35, length), "wood", Vector3(0, rad_to_deg(Player.yaw_of(out)), 0), LevelBlock.Shape.BOX, "Landing%d" % (k + 1))
		# Coins up the screw, picked up on the ride.
		var side := Vector3(out.z, 0, -out.x) * 1.15
		coin_trail(lift.position + side + Vector3.UP * 1.0, lift.position + side + Vector3.UP * (lift.travel + 0.6), 5, 0.0, CoinTrail.TrailShape.LINE)
	# The second lift passes a nook in the cliff with a gem on it.
	var k2 := 1
	var nook := P.tier_rim(int(P.LIFTS[k2][0]) + 1, float(P.LIFTS[k2][1]) + 17.0, 0.8)
	nook.y = P.TIERS[1][2] + 3.4
	var nout := Vector3(nook.x - P.TIERS[2][0].x, 0, nook.z - P.TIERS[2][0].y).normalized()
	blk(structures, nook + nout * -0.6 + Vector3.DOWN * 0.6, Vector3(2.4, 0.6, 2.6), "rock", Vector3(0, rad_to_deg(Player.yaw_of(nout)), 0), LevelBlock.Shape.BOX, "GemNook")
	gem(nook + nout * -0.4 + Vector3.UP * 0.8, "pinwheel_gem_nook", Palette.GEM_BLUE)


## The summit: a parrot, and the great pole's lift up to the crow's nest
## with the Heart Piece.
func _summit() -> void:
	var g := b.group("Summit", gameplay)
	var top := P.tier_top(3)
	var great := PinwheelLift.new()
	var gb := P.great_base()
	great.position = gb + Vector3.UP * 0.25
	great.travel = P.NEST_Y - (gb.y + 0.25)
	great.pole_extra = 6.0
	great.wheel_radius = 4.4
	great.colors = 3
	b.add(great, g, "GreatLift")
	cage(top + Vector3(3.6, 0.05, -1.5), "pinwheel_parrot_summit", ParrotModel.Plumage.ROSE)
	var piece := HeartPiece.new()
	piece.piece_id = &"pinwheel_heart_piece"
	piece.position = gb + Vector3(2.8, P.NEST_Y - gb.y, 0)
	b.add(piece, g, "HeartPiece")
	_checkpoint(g, "cp_pinwheel_summit", top + Vector3(1.0, 0, -3.5), 0.0, "CpSummit")
	coin_trail(gb + Vector3(-2.7, P.NEST_Y - gb.y + 0.8, 0), gb + Vector3(0, P.NEST_Y - gb.y + 0.8, -2.7), 3, 0.0, CoinTrail.TrailShape.LINE)


## Crabs on the first tier, a heart, coins round the tiers.
func _extras() -> void:
	for d: Array in [[Vector3(-8.0, 0, -9.0), "pinwheel_crab_1"], [Vector3(10.0, 0, 6.0), "pinwheel_crab_2"]]:
		crab(d[0] + Vector3.UP * (P.TIERS[1][2] + 0.05), CrabModel.Variant.NORMAL, d[1])
	heart(P.tier_rim(2, -120.0, -3.0) + Vector3.UP * 0.6)
	for d: Array in [[0, -60.0, -30.0], [0, 90.0, 120.0], [1, 0.0, 40.0], [1, -140.0, -110.0], [2, 120.0, 150.0]]:
		var a := P.tier_rim(d[0], d[1], -2.5)
		var c := P.tier_rim(d[0], d[2], -2.5)
		coin_trail(a + Vector3.UP * 0.9, c + Vector3.UP * 0.9, 4, 0.0, CoinTrail.TrailShape.LINE)


func _hints() -> void:
	var g := b.group("Hints", gameplay)
	var first := P.lift_base(0)
	for d: Array in [
			["hint_pinwheel", first + Vector3.UP * 0.25, Vector3(5, 4, 5), "Stand on the platform and spin the pinwheel above: {tool_primary} with the cannon or the grapple", &""]]:
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
