extends IslandBuilder
## Generates res://world/islands/hat_rock/hat_rock.tscn: Hat Rock, "a sea
## stack shaped exactly like a pirate's hat" (docs/ARCHIPELAGO.md), north of
## Castaway Cay. Built in the island's own frame (HatRock: its place in the
## archipelago, turned so -Z faces Castaway Cay):
##  - A landing beach and jetty at the front, where the boat comes in.
##  - Boulders up to the brim's low front edge, then the brim itself.
##  - The ledge spiralling up the crown: gaps to jump, and bare stretches
##    where gusts off the sea blow you over the edge unless you brace.
##  - The lookout on top: pound the buckle to open its door (the Spyglass
##    inside) and start the hoist, a shortcut back up from the brim.
##  - The feather: grapple across from the plank, swing ring to ring round
##    it to its shoulder, and walk up the quill to the parrot at the crest.
##  - A gem on the rosette pinned to one of the brim's corners (grapple).
##   tools/builders/build.sh hat_rock

const ISLAND := &"hat_rock"
const H := preload("res://world/horizon/horizon_hat_rock.gd")

var root: Node3D
var _door: Gate


func build() -> void:
	seed(20261003)
	root = island_root(ISLAND, "HatRock")
	begin("HatRock", ISLAND, "Hat Rock", &"castaway_explore", root)
	_rock()
	_beach()
	_landing()
	_climb()
	_ledge()
	_lookout()
	_hoist()
	_feather()
	_rosette()
	_hints()
	seabed(root.position, 300.0)
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
	waters(g, Vector3.ZERO, 100.0, mooring, arrival, "Hat Rock")
	_checkpoint(g, "cp_hat_rock", Vector3(-4, 1.0, -62), 180.0, "CpBeach")


## Boulders up to the brim's low front edge (a ledge grab from the top one),
## and coins across the brim to where the ledge begins.
func _climb() -> void:
	var g := b.group("Climb", gameplay)
	var edge := H.BRIM_OUT
	blk(g, Vector3(-3.5, 1.0, -edge - 6.8), Vector3(4.4, 2.5, 4.4), "rock", Vector3(0, 12, 0), LevelBlock.Shape.BOX, "Step1")
	blk(g, Vector3(0.5, 1.0, -edge - 3.0), Vector3(3.6, 5.5, 3.6), "rock", Vector3(0, -8, 0), LevelBlock.Shape.BOX, "Step2")
	coin_trail(Vector3(-3.5, 4.2, -edge - 6.8), Vector3(0.5, 7.2, -edge - 3.0), 3, 1.0)
	# Round the brim to where the ledge starts, by the front-left corner.
	var on_brim := func(a: float, r: float) -> Vector3:
		return Vector3(cos(a) * r, H.brim_surface(r, a), sin(a) * r)
	var steps := 5
	for k in steps:
		var a0 := lerpf(H.FRONT - 0.06, H.LEDGE_START + 0.1, float(k) / steps)
		var a1 := lerpf(H.FRONT - 0.06, H.LEDGE_START + 0.1, float(k + 1) / steps)
		coin_trail(on_brim.call(a0, 33.0) + Vector3.UP * 0.9, on_brim.call(a1, 33.0) + Vector3.UP * 0.9, 2, 0.0, CoinTrail.TrailShape.LINE)
	var cp_at: Vector3 = on_brim.call(H.LEDGE_START + 0.12, 31.0)
	_checkpoint(g, "cp_hat_rock_brim", cp_at, rad_to_deg(Player.yaw_of(Vector3(-cp_at.x, 0, -cp_at.z))), "CpBrim")


## The spiral ledge: a WindGust lane over each bare stretch (taking turns,
## blowing out to sea), and coins along the way.
func _ledge() -> void:
	var g := b.group("Ledge", gameplay)
	var k := 0
	for lane: Vector2 in H.LEDGE_BARE:
		var mid := H.ledge_point((lane.x + lane.y) * 0.5, 0.5)
		var low := H.ledge_point(lane.x, 0.5)
		var high := H.ledge_point(lane.y, 0.5)
		var out := Vector3(mid.x - H.CROWN_AT.x, 0, mid.z - H.CROWN_AT.z).normalized()
		# The lane is straight but the ledge curves: deepen the box by the
		# bow of the curve so the whole stretch is in the wind.
		var chord := Vector2(high.x - low.x, high.z - low.z).length()
		var r := Vector2(mid.x - H.CROWN_AT.x, mid.z - H.CROWN_AT.z).length()
		var bow := r * (1.0 - cos(chord / r * 0.5))
		var gust := WindGust.new()
		gust.size = Vector3(chord + 3.0, high.y - low.y + 5.0, 7.0 + bow)
		gust.position = Vector3(mid.x, low.y - 1.2, mid.z) - out * bow * 0.5
		gust.basis = Basis.looking_at(out)
		gust.offset = k * 1.6
		# The pennant stands at the lane's start, by the crown wall.
		gust.pennant_at = gust.basis.inverse() * (H.ledge_point(lane.x + 0.012, 0.15) - gust.position)
		b.add(gust, g, "Gust%d" % (k + 1))
		k += 1
	# Coins in short runs that follow the curve (none in the gust lanes'
	# gaps), and a heart halfway.
	for run: Vector2 in [Vector2(0.03, 0.06), Vector2(0.08, 0.11), Vector2(0.16, 0.19), Vector2(0.33, 0.36), Vector2(0.42, 0.45),
			Vector2(0.63, 0.66), Vector2(0.84, 0.855), Vector2(0.9, 0.93), Vector2(0.95, 0.98)]:
		coin_trail(H.ledge_point(run.x, 0.45) + Vector3.UP * 0.9, H.ledge_point(run.y, 0.45) + Vector3.UP * 0.9, 3, 0.0, CoinTrail.TrailShape.LINE)
	heart(H.ledge_point(0.68, 0.3) + Vector3.UP * 0.8)


## The lookout on the crown's top: the buckle that unlatches its door, the
## Spyglass inside, and a checkpoint where the ledge comes up.
func _lookout() -> void:
	var g := b.group("Lookout", gameplay)
	var top := H.lookout()
	var buckle := PoundPost.new()
	buckle.style = "buckle"
	buckle.post_height = 0.9
	buckle.post_id = &"hat_rock_buckle"
	buckle.position = Vector3(top.x, H.CROWN_TOP, top.z - 9.0)
	b.add(buckle, g, "Buckle")
	var door := Gate.new()
	door.gate_id = &"hat_rock_lookout_door"
	door.size = Vector3(2.2, 3.2, 0.3)
	door.position = top + Vector3(0, 0, -2.825)
	door.triggers = [buckle]
	b.add(door, g, "LookoutDoor")
	_door = door
	var glass := KeyItemPickup.new()
	glass.item_id = &"spyglass"
	glass.position = top + Vector3(0, 0.12, 0.6)
	b.add(glass, g, "Spyglass")
	var end := H.ledge_point(1.0, 0.5)
	var inward := Vector3(H.CROWN_AT.x - end.x, 0, H.CROWN_AT.z - end.z).normalized()
	_checkpoint(g, "cp_hat_rock_top", end + inward * 4.0, rad_to_deg(Player.yaw_of(inward)), "CpTop")
	coin_trail(buckle.position + Vector3(-3.0, 0.9, 2.0), buckle.position + Vector3(3.0, 0.9, 2.0), 4, 0.0, CoinTrail.TrailShape.LINE)


## The hoist off the front of the crown: a davit out over the brim, a
## gantry and pulley, and the basket (parked up top until the buckle).
func _hoist() -> void:
	var g := b.group("Hoist", gameplay)
	var top_y := H.CROWN_TOP + 0.3
	var z_in := -14.0
	var z_out := -27.85
	var basket_z := -29.2
	blk(structures, Vector3(0, top_y - 0.4, (z_in + z_out) * 0.5), Vector3(2.4, 0.4, z_in - z_out), "wood", Vector3.ZERO, LevelBlock.Shape.BOX, "Davit")
	for side: float in [-1.0, 1.0]:
		blk(structures, Vector3(side * 1.75, top_y, z_out - 0.2), Vector3(0.3, 5.7, 0.3), "wood_dark", Vector3.ZERO, LevelBlock.Shape.CYLINDER, "GantryPost")
		blk(structures, Vector3(side * 1.25, top_y - 0.05, (z_in + z_out) * 0.5), Vector3(0.2, 0.9, z_in - z_out - 0.6), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "DavitRail")
	blk(structures, Vector3(0, top_y + 5.4, z_out - 0.2), Vector3(3.9, 0.35, 0.35), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "GantryBeam")
	blk(structures, Vector3(0, top_y + 5.4, (z_out - 0.2 + basket_z) * 0.5), Vector3(0.35, 0.35, absf(basket_z - z_out) + 0.6), "wood_dark", Vector3.ZERO, LevelBlock.Shape.BOX, "GantryArm")
	blk(structures, Vector3(0, top_y + 4.9, basket_z), Vector3(0.7, 0.5, 0.7), "metal", Vector3(0, 0, 90), LevelBlock.Shape.CYLINDER, "Pulley")
	var hoist := LookoutHoist.new()
	hoist.position = Vector3(0, top_y, basket_z)
	hoist.drop = top_y - (H.PED + 0.25)
	hoist.pulley = 4.9
	hoist.speed = 6.0
	hoist.wait_time = 1.4
	hoist.gate = _door
	b.add(hoist, g, "Hoist")


## The feather: the plank's iron ring on the first tuft (grapple), hook
## rings from tuft to tuft and up to the shoulder, the parrot at the crest.
func _feather() -> void:
	var g := b.group("Feather", gameplay)
	var t0: Vector3 = H.TUFTS[0]
	var back := -H.plank_dir()
	# A big iron ring over the first tuft's near edge, too far for the hook.
	# Nothing above it: the grapple's hop carries Patchy up past it.
	var iron := HookPoint.new()
	iron.grapple_only = true
	iron.grapple_arrival = "hop"
	iron.hang_length = 0.0
	iron.position = t0 + back * 2.2 + Vector3.UP * 3.6
	iron.scale = Vector3.ONE * 1.6
	b.add(iron, g, "FeatherIron")
	# Rings round the feather: each 3 m out from a tuft's edge and 6 m up,
	# so the swing drops you on the next tuft, 3 m higher.
	var stops: Array = H.TUFTS.duplicate()
	stops.append(H.SHOULDER)
	var radii: Array = H.TUFT_RADII.duplicate()
	for k in stops.size() - 1:
		var from: Vector3 = stops[k]
		var to: Vector3 = stops[k + 1]
		var dir := Vector3(to.x - from.x, 0, to.z - from.z).normalized()
		var hp := HookPoint.new()
		hp.position = from + dir * (float(radii[k]) + 3.0) + Vector3.UP * (6.0 if k < stops.size() - 2 else 6.5)
		hp.hang_length = 1.4
		b.add(hp, g, "FeatherRing%d" % (k + 1))
		coin_trail(from + dir * (float(radii[k]) + 0.8) + Vector3.UP * 1.2, hp.position + dir * 2.0 + Vector3.DOWN * 3.2, 3, 2.0)
	var aside := Vector3(back.z, 0, -back.x)
	_checkpoint(g, "cp_hat_rock_feather", t0 + aside * 1.7, rad_to_deg(Player.yaw_of(-back)), "CpFeather")
	cage(H.CREST + Vector3.UP * 0.05, "hat_rock_parrot_crest", ParrotModel.Plumage.AZURE)
	coin_trail(H.quill_point(0.15) + Vector3.UP * 0.8, H.quill_point(0.75) + Vector3.UP * 0.8, 5, 0.0, CoinTrail.TrailShape.LINE)


## The rosette on a corner of the brim: a gem, and a dark iron ring just
## inside it that only the grapple reaches, from up the brim's curl.
func _rosette() -> void:
	var g := b.group("Rosette", gameplay)
	var rc := H.rosette_center()
	var inward := Vector3(-rc.x, 0, -rc.z).normalized()
	var iron := HookPoint.new()
	iron.grapple_only = true
	iron.grapple_arrival = "hop"
	iron.hang_length = 0.0
	iron.position = rc + inward * 2.0 + Vector3.UP * 3.0
	iron.scale = Vector3.ONE * 1.4
	b.add(iron, g, "RosetteIron")
	gem(rc + Vector3.UP * 0.9 - inward * 0.3, "hat_rock_gem_rosette", Palette.GEM_RED)


func _hints() -> void:
	var g := b.group("Hints", gameplay)
	var gust_at := H.ledge_point(H.LEDGE_BARE[0].x - 0.015, 0.5)
	var plank := H.plank_end()
	for d: Array in [
			["hint_gust", gust_at, Vector3(6, 4, 6), "Gusts off the sea! Hold {crouch} to brace until they pass", &""],
			["hint_buckle", Vector3(0, H.CROWN_TOP, H.lookout().z - 9.0), Vector3(8, 4, 8), "A great gold buckle... In the air, press {ground_pound} to pound it", &""],
			["hint_feather_grapple", plank, Vector3(5, 4, 5), "{tool_primary} Grapple the iron ring on the feather", &"grapple"]]:
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
