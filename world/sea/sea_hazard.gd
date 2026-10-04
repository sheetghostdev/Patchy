class_name SeaHazard
extends Node3D
## A sea hazard round one of the late islands (docs/ARCHIPELAGO.md, the open
## sea): a band of bad water between the open sea and the island that a boat
## can't cross until Patchy's ship has the upgrade that answers it
## (ShipUpgrades, fitted at Gus's shipyard). Without it the hazard turns the
## boat (or a swimmer) gently back out with a word about what's wrong and
## what would do; with it, the boat sails on through. Each kind looks the
## part, and can be seen from well out to sea:
##  - STORM (Stormpeak): a wall of black cloud and rain, lightning, a
##    heaving sea. The Iron Hull rides it out.
##  - FORT_GUNS (Cannonball Cliffs): Brock's gun towers on rocks all round,
##    lobbing shot at any boat that comes near. With the Bow Cannon Patchy
##    can sail in and shoot back, silencing them one by one.
##  - BOILING_SEA (Cinder Isle): scalding orange water, steam and smoking
##    lava rocks. The Copper Bottom takes the heat.
##  - REEF (Crocodile Crown): three rings of coral with a gap or two in
##    each, and currents pouring out through them. The Racing Rig beats the
##    currents; then it's a maze to thread.
## Sits at the island's center at sea level. The band runs from `inner` to
## `inner + width` from it; `inner` 0 puts it just outside the island's sea
## mist (MistBank) while the island's still to be built.

enum Kind { STORM, FORT_GUNS, BOILING_SEA, REEF }

@export var kind := Kind.STORM
@export var island_id: StringName = &""
## Inner edge of the band from the center (0: just outside the island's mist).
@export var inner := 0.0
@export var width := 60.0

## The upgrade that answers each kind.
const NEEDS := {Kind.STORM: &"iron_hull", Kind.FORT_GUNS: &"bow_cannon", Kind.BOILING_SEA: &"copper_hull", Kind.REEF: &"racing_rig"}
const NAMES := {Kind.STORM: "the storm wall", Kind.FORT_GUNS: "Brock's fort guns", Kind.BOILING_SEA: "the boiling sea", Kind.REEF: "the reef maze"}
const TURN_BACK := {
	Kind.STORM: "The storm round %s would smash this little boat to kindling! An iron hull could ride it out.",
	Kind.FORT_GUNS: "Brock's fort guns round %s have your range! You'd need a cannon of your own to answer them.",
	Kind.BOILING_SEA: "The sea round %s is boiling! It would scald the planks right through. A copper bottom could take the heat.",
	Kind.REEF: "The currents pouring out of the reef round %s are too strong for this sail! A faster rig could beat them.",
}
const THROUGH := {
	Kind.STORM: "The iron hull rides out the storm!",
	Kind.FORT_GUNS: "Brock's gunners have seen your cannon! Shoot back to silence them.",
	Kind.BOILING_SEA: "The copper bottom takes the heat. Steady as she goes!",
	Kind.REEF: "The racing rig beats the currents! Now find the gaps in the reef.",
}
const PUSH := 2.5
const MAX_PUSH := 14.0
## How far out past the band it's drawn.
const SEEN := {Kind.STORM: 1400.0, Kind.FORT_GUNS: 650.0, Kind.BOILING_SEA: 650.0, Kind.REEF: 650.0}
## The reef: its rings of coral (fractions across the band) and the gaps in
## each (degrees round from the island's east, toward the south).
const REEF_RINGS: Array[float] = [0.15, 0.5, 0.85]
const REEF_GAPS := [[20.0, 200.0], [110.0], [65.0, 245.0]]
const REEF_GAP_WIDTH := 16.0
## The current out through the reef, for a boat that can beat it.
const REEF_CURRENT := 3.0
const GUN_COUNT := 6
## Archipelago "hazard" names, and how wide each kind's band is.
const KINDS := {&"storm": Kind.STORM, &"fort_guns": Kind.FORT_GUNS, &"boiling_sea": Kind.BOILING_SEA, &"reef": Kind.REEF}
const WIDTHS := {Kind.STORM: 70.0, Kind.FORT_GUNS: 60.0, Kind.BOILING_SEA: 55.0, Kind.REEF: 66.0}

var _ready_done := false
var _hint_cool := 0.0
var _inside := false
var _fx_t := 0.0
var _jolt_t := 0.0
var _bolt: MeshInstance3D
var _flash: OmniLight3D
var _streaks: Node3D


## The hazard round island `id` (Archipelago "hazard"), or null.
static func for_island(id: StringName) -> SeaHazard:
	var key := StringName(Archipelago.get_island(id).get("hazard", &""))
	if not KINDS.has(key):
		return null
	var h := SeaHazard.new()
	h.kind = KINDS[key]
	h.island_id = id
	h.width = WIDTHS[h.kind]
	h.position = Archipelago.world_position(id)
	return h


func _ready() -> void:
	add_to_group(&"sea_hazard")
	_setup.call_deferred()


func _setup(tries := 0) -> void:
	if inner <= 0.0:
		var r := _mist_radius()
		if r < 0.0 and tries < 3:
			_setup.call_deferred(tries + 1)
			return
		inner = (r + 8.0) if r > 0.0 else 120.0
	match kind:
		Kind.STORM:
			_build_storm()
		Kind.FORT_GUNS:
			_build_forts()
		Kind.BOILING_SEA:
			_build_boiling()
		Kind.REEF:
			_build_reef()
	_ready_done = true


## The island's mist's reach (-1 while it's still working it out, 0 for
## no mist at all).
func _mist_radius() -> float:
	for n in get_tree().get_nodes_in_group(&"mist_bank"):
		var m := n as MistBank
		if m != null and m.island_id == island_id:
			return m.radius if m.radius > 0.0 else -1.0
	return 0.0


func outer() -> float:
	return inner + width


## The upgrade that answers this hazard.
func needs() -> StringName:
	return NEEDS[kind]


func passable() -> bool:
	return ShipUpgrades.has(needs())


## How far inside the band `pos` is, from its outer edge (m; 0 outside it).
func depth(pos: Vector3) -> float:
	var d := _flat(pos).length()
	if d <= inner or d >= outer():
		return 0.0
	return outer() - d


func contains(pos: Vector3) -> bool:
	return depth(pos) > 0.0


func _flat(pos: Vector3) -> Vector2:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z)


func _out_dir(pos: Vector3) -> Vector3:
	var f := _flat(pos)
	if f.length() < 0.01:
		return Vector3.RIGHT
	f = f.normalized()
	return Vector3(f.x, 0, f.y)


func _boat_of(p: Player) -> TinyBoat:
	if p.state_id != &"boat":
		return null
	for b in get_tree().get_nodes_in_group(&"boat"):
		var boat := b as TinyBoat
		if boat != null and boat.driver == p:
			return boat
	return null


func _physics_process(delta: float) -> void:
	if not _ready_done:
		return
	_hint_cool = maxf(_hint_cool - delta, 0.0)
	var p := GameManager.player as Player
	if p == null or not is_instance_valid(p):
		return
	var boat := _boat_of(p)
	var body: Node3D = boat if boat != null else (p as Node3D if p.state_id == &"swim" else null)
	_effects(delta, p, boat)
	if body == null:
		return
	var into := depth(body.global_position)
	if into <= 0.0:
		if _flat(body.global_position).length() >= outer():
			_inside = false
		return
	var out := _out_dir(body.global_position)
	if boat != null and passable():
		if not _inside:
			_inside = true
			Events.hud_message.emit(THROUGH[kind], 3.0)
		_ride(boat, out, delta)
		return
	body.global_position += out * minf(PUSH + into * 1.5, MAX_PUSH) * delta
	if boat != null:
		boat.slow_to(lerpf(boat.top_speed(), 2.0, clampf(into / 10.0, 0.0, 1.0)))
	if _hint_cool <= 0.0:
		_hint_cool = 8.0
		Events.hud_message.emit(TURN_BACK[kind] % UIChartData.display_name(island_id), 4.0)


## Sailing through with the right upgrade: still rough going.
func _ride(boat: TinyBoat, out: Vector3, delta: float) -> void:
	match kind:
		Kind.STORM:
			boat.slow_to(boat.top_speed() * 0.8)
			_jolt_t -= delta
			if _jolt_t <= 0.0:
				_jolt_t = randf_range(0.9, 1.8)
				Events.camera_impulse.emit(0.12)
				AudioManager.play(&"wood_creak", boat.global_position, -6.0, randf_range(0.7, 0.9))
		Kind.REEF:
			boat.global_position += out * REEF_CURRENT * delta


# --- Living effects --------------------------------------------------------------------

func _effects(delta: float, p: Player, boat: TinyBoat) -> void:
	var near := _flat(p.global_position).length()
	_fx_t -= delta
	match kind:
		Kind.STORM:
			if near < outer() + 700.0 and _fx_t <= 0.0:
				_fx_t = randf_range(2.5, 6.0)
				_strike(p.global_position)
		Kind.BOILING_SEA:
			if near > inner - 20.0 and near < outer() + 25.0 and _fx_t <= 0.0:
				_fx_t = 0.18
				var at := (boat.global_position if boat != null else p.global_position) + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))
				if contains(at):
					at.y = 0.1
					VFX.dust(get_tree().current_scene, at, 4, 0.9, Color(1, 1, 1, 0.55), 1.4, 2.6)
					VFX.splash(get_tree().current_scene, at, 0.45)


func _process(delta: float) -> void:
	if _streaks != null:
		_streaks.rotation.y += delta * 0.01


## A lightning bolt somewhere in the storm on Patchy's side of it, a flash,
## and thunder a moment later.
func _strike(from: Vector3) -> void:
	if _bolt == null:
		return
	var toward := atan2(from.z - global_position.z, from.x - global_position.x)
	var a := toward + randf_range(-0.6, 0.6)
	var r := inner + width * randf_range(0.2, 0.8)
	var foot := Vector3(cos(a) * r, 0, sin(a) * r)
	var mb := MeshBuilder.new()
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	var y := 30.0
	var at := foot + Vector3(randf_range(-4, 4), y, randf_range(-4, 4))
	while y > 0.0:
		pts.append(at)
		radii.append(0.35)
		y -= randf_range(3.0, 5.0)
		at = Vector3(foot.x + randf_range(-3.5, 3.5), maxf(y, 0.0), foot.z + randf_range(-3.5, 3.5))
	pts.append(Vector3(at.x, 0.0, at.z))
	radii.append(0.2)
	mb.tube(pts, radii, Color(1, 1, 0.85), 5, false)
	_bolt.mesh = mb.build(null, MaterialLibrary.unshaded(Color(1.0, 0.98, 0.8)))
	_bolt.visible = true
	_flash.position = foot + Vector3.UP * 20.0
	_flash.light_energy = 8.0
	var tw := create_tween()
	tw.tween_property(_flash, "light_energy", 0.0, 0.35)
	get_tree().create_timer(0.14, false).timeout.connect(func() -> void:
		if is_instance_valid(_bolt):
			_bolt.visible = false)
	var boom := to_global(foot)
	var wait := clampf(boom.distance_to(from) / 340.0, 0.1, 2.0)
	get_tree().create_timer(wait, false).timeout.connect(func() -> void:
		if is_instance_valid(self):
			AudioManager.play(&"explosion", boom, 4.0, 0.42, 0.1)
			if boom.distance_to(from) < 160.0:
				Events.camera_impulse.emit(0.1))


# --- Building -----------------------------------------------------------------------

func _mesh(mb: MeshBuilder, finish: StringName, alpha_cut := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, finish))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transparency = alpha_cut
	mi.visibility_range_end = outer() + float(SEEN[kind])
	mi.visibility_range_end_margin = 80.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	return mi


## Flat, unlit vertex colors (hot water that should glow, not shade).
func _glow(mb: MeshBuilder, alpha_cut: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, mat)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transparency = alpha_cut
	mi.visibility_range_end = outer() + float(SEEN[kind])
	mi.visibility_range_end_margin = 80.0
	mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(mi)
	return mi


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(island_id) ^ (kind * 7919)
	return rng


## Points round a ring of radius `r`, every `step` m or so.
func _ring(r: float, step: float) -> int:
	return maxi(12, int(TAU * r / step))


func _static_body() -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	add_child(body)
	return body


func _build_storm() -> void:
	var rng := _rng()
	var mid := inner + width * 0.5
	# Black cloud heaped up over the band in tiers, a wall from the sea's
	# edge to high above, darkest at the bottom.
	var clouds := PropBuilder.new()
	var n := _ring(mid, 12.0)
	for i in n:
		var a := TAU * i / n + rng.randf_range(-0.03, 0.03)
		for tier in 4:
			if tier == 3 and i % 2 == 1:
				continue
			var r := mid + rng.randf_range(-width * 0.35, width * 0.35) - tier * 4.0
			var size := rng.randf_range(16.0, 24.0) * (1.0 - tier * 0.15)
			var at := Vector3(cos(a) * r, 18.0 + tier * 11.0 + rng.randf_range(0.0, 5.0), sin(a) * r)
			var shape := Basis(Vector3.UP, -a) * Basis.from_scale(Vector3(size * 1.1, size * 0.6, size))
			clouds.sphere(1.0, Transform3D(shape, at), Color("2f343e").lerp(Color("666d7a"), clampf(tier * 0.28 + rng.randf() * 0.2, 0.0, 1.0)), 4, 8)
	_mesh(clouds, &"matte")
	# Curtains of rain from the cloud to the sea, streaked.
	var rain := MeshBuilder.new()
	for k in 2:
		var r := mid + (k - 0.5) * width * 0.4
		var m := _ring(r, 4.0)
		for i in m:
			var a0 := TAU * i / m
			var a1 := TAU * (i + 1) / m
			var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
			var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
			var col := Color("3e4452").lerp(Color("6f7888"), rng.randf())
			for side: float in [1.0, -1.0]:
				var top0 := p0 + Vector3.UP * 30.0
				var top1 := p1 + Vector3.UP * 30.0
				if side > 0.0:
					rain.triangle(p0, top0, top1, col)
					rain.triangle(p0, top1, p1, col)
				else:
					rain.triangle(p0, top1, top0, col)
					rain.triangle(p0, p1, top1, col)
	var curtain := _mesh(rain, &"soft", 0.35)
	curtain.name = "Rain"
	# Whitecaps streaking the sea under it.
	var caps := PropBuilder.new()
	for i in _ring(mid, 3.0):
		var a := rng.randf() * TAU
		var r := mid + rng.randf_range(-width * 0.5, width * 0.5)
		var at := Vector3(cos(a) * r, 0.2, sin(a) * r)
		var along := Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5)).rotated(Vector3.UP, rng.randf_range(-0.5, 0.5))
		var side := Vector3(-along.z, 0, along.x) * rng.randf_range(0.15, 0.3)
		var length := rng.randf_range(2.0, 5.0)
		caps.flat_quad(at - side, at + side, at + side + along * length, at - side + along * length, Vector3.UP, Color("eef4f8"))
	_mesh(caps, &"soft", 0.3)
	_bolt = MeshInstance3D.new()
	_bolt.visible = false
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bolt)
	_flash = OmniLight3D.new()
	_flash.omni_range = 260.0
	_flash.light_energy = 0.0
	_flash.light_color = Color(0.85, 0.9, 1.0)
	_flash.shadow_enabled = false
	add_child(_flash)


func _build_forts() -> void:
	var rng := _rng()
	var r := inner + width * 0.45
	for k in GUN_COUNT:
		var a := TAU * k / GUN_COUNT + deg_to_rad(15.0)
		var gun := FortGun.new()
		gun.hazard = self
		gun.gun_id = StringName("%s_fort_gun_%d" % [island_id, k])
		gun.position = Vector3(cos(a) * r, 0, sin(a) * r)
		gun.rotation.y = Player.yaw_of(Vector3(cos(a), 0, sin(a)))
		gun.build_seed = rng.randi()
		add_child(gun)


func _build_boiling() -> void:
	var rng := _rng()
	var mid := inner + width * 0.5
	# The whole band tinted hot, and patches of it boiling orange.
	var tint := PropBuilder.new()
	var m := _ring(mid, 6.0)
	for i in m:
		var a0 := TAU * i / m
		var a1 := TAU * (i + 1) / m
		var p := func(a: float, r: float) -> Vector3: return Vector3(cos(a) * r, 0.1, sin(a) * r)
		tint.flat_quad(p.call(a0, inner), p.call(a1, inner), p.call(a1, outer()), p.call(a0, outer()), Vector3.UP, Color("c4521c"))
	_glow(tint, 0.18)
	var hot := PropBuilder.new()
	for i in _ring(mid, 6.0):
		var a := rng.randf() * TAU
		var rr := mid + rng.randf_range(-width * 0.48, width * 0.48)
		var c := Vector3(cos(a) * rr, 0.18, sin(a) * rr)
		var size := rng.randf_range(3.0, 7.0)
		var col := Color("ff5a14").lerp(Color("ffb02e"), rng.randf())
		var pts := 9
		var spin := rng.randf() * TAU
		for j in pts:
			var b0 := spin + TAU * j / pts
			var b1 := spin + TAU * (j + 1) / pts
			var r0 := size * rng.randf_range(0.6, 1.0)
			var r1 := size * rng.randf_range(0.6, 1.0)
			hot.flat_tri(c, c + Vector3(cos(b1) * r1, 0, sin(b1) * r1), c + Vector3(cos(b0) * r0, 0, sin(b0) * r0), col, Vector3.UP)
		# Bubbles on it.
		for k in 3:
			var at := c + Vector3(rng.randf_range(-size, size) * 0.5, 0.05, rng.randf_range(-size, size) * 0.5)
			hot.ellipsoid(Vector3(0.5, 0.25, 0.5) * rng.randf_range(0.6, 1.3), Transform3D(Basis.IDENTITY, at), Color("ffe0a0"), 3, 6)
	_glow(hot, 0.15)
	# Steam drifting up in wisps, wider and thinner as it rises.
	var steam := PropBuilder.new()
	for i in _ring(mid, 22.0):
		var a := rng.randf() * TAU
		var rr := mid + rng.randf_range(-width * 0.45, width * 0.45)
		var base := Vector3(cos(a) * rr, 0, sin(a) * rr)
		var drift := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		for j in 7:
			var t := float(j) / 6.0
			var s := lerpf(1.6, 6.0, t) * rng.randf_range(0.75, 1.25)
			var at := base + drift * (t * t * 9.0) + Vector3(rng.randf_range(-1.5, 1.5) * t, 0.8 + t * 17.0, rng.randf_range(-1.5, 1.5) * t)
			steam.ellipsoid(Vector3(s, s * 0.6, s), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Color("f8f6f2"), 4, 8)
	_mesh(steam, &"soft", 0.6)
	# Smoking lava rocks, glowing where the sea boils against them.
	var rocks := PropBuilder.new()
	var body := _static_body()
	for i in _ring(mid, 26.0):
		var a := rng.randf() * TAU
		var rr := mid + rng.randf_range(-width * 0.4, width * 0.4)
		var at := Vector3(cos(a) * rr, -0.8, sin(a) * rr)
		var size := rng.randf_range(2.6, 5.5)
		var from := rocks.mark()
		rocks.append(HorizonIsland.lump(Vector3(size, size * rng.randf_range(0.7, 1.1), size * rng.randf_range(0.8, 1.1)), rng.randi(), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), 0.25, [], 5, 8))
		rocks.recolor(func(q: Vector3, _n: Vector3, _c: Color) -> Color: return Color("2e2a2c").lerp(Color("4a4244"), clampf(q.y / 3.0, 0.0, 1.0)), from)
		rocks.torus(size * 0.85, size * 1.2, Transform3D(Basis.from_scale(Vector3(1, 0.35, 1)), Vector3(at.x, 0.25, at.z)), Color("ff6a1a"), 14, 5)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = size * 0.9
		cyl.height = 8.0
		cs.shape = cyl
		cs.position = Vector3(at.x, 0, at.z)
		body.add_child(cs)
	_mesh(rocks, &"matte")


func _build_reef() -> void:
	var rng := _rng()
	var coral := PropBuilder.new()
	var body := _static_body()
	var colors := [Color("ff7aa8"), Color("ff9a4a"), Color("a070e0"), Color("f6d04d"), Color("4fd0c0"), Color("e8524a")]
	for k in REEF_RINGS.size():
		var r := inner + width * REEF_RINGS[k]
		var n := _ring(r, 3.2)
		# Coral heads all round, but for the gaps.
		for i in n:
			var a := TAU * i / n
			if _in_gap(k, a, r):
				continue
			var at := Vector3(cos(a) * r, 0, sin(a) * r) + Vector3(rng.randf_range(-1.2, 1.2), 0, rng.randf_range(-1.2, 1.2))
			var col: Color = colors[rng.randi() % colors.size()]
			match rng.randi() % 3:
				0:
					# Brain coral.
					var s := rng.randf_range(1.6, 2.6)
					coral.ellipsoid(Vector3(s, s * 0.7, s), Transform3D(Basis.IDENTITY, at + Vector3.UP * rng.randf_range(-0.4, 0.4)), col, 4, 7)
				1:
					# Branching coral.
					for b in 3:
						var tip := at + Vector3(rng.randf_range(-1.2, 1.2), rng.randf_range(1.2, 2.6), rng.randf_range(-1.2, 1.2))
						coral.tube(PackedVector3Array([at + Vector3.DOWN, at.lerp(tip, 0.5) + Vector3.UP * 0.2, tip]), PackedFloat32Array([0.45, 0.3, 0.18]), col, 5, true)
				_:
					# A rock crusted with coral.
					var s := rng.randf_range(1.8, 2.4)
					coral.ellipsoid(Vector3(s, s * 0.5, s * 0.8), Transform3D(Basis(Vector3.UP, rng.randf() * TAU), at), Color("8a8070"), 3, 6)
					coral.sphere(s * 0.45, Transform3D(Basis.IDENTITY, at + Vector3.UP * s * 0.45), col, 3, 6)
		# Walls of collision along the ring, gaps open.
		var seg := _ring(r, 14.0)
		for i in seg:
			var a := TAU * (i + 0.5) / seg
			if _in_gap(k, a, r, 6.0):
				continue
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(TAU * r / seg + 0.6, 6.0, 3.6)
			cs.shape = box
			cs.position = Vector3(cos(a) * r, 0, sin(a) * r)
			cs.rotation.y = -a - PI * 0.5
			body.add_child(cs)
	_mesh(coral, &"soft")
	# Foam streaks of current pouring out through the reef.
	var foam := PropBuilder.new()
	for i in _ring(inner + width * 0.5, 6.0):
		var a := rng.randf() * TAU
		var rr := inner + rng.randf_range(0.0, width)
		var at := Vector3(cos(a) * rr, 0.12, sin(a) * rr)
		var along := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-along.z, 0, along.x) * 0.25
		var length := rng.randf_range(3.0, 7.0)
		foam.flat_quad(at - side, at + side, at + side + along * length, at - side + along * length, Vector3.UP, Color("f2fbff"))
	_streaks = Node3D.new()
	add_child(_streaks)
	var mi := _mesh(foam, &"soft", 0.35)
	mi.reparent(_streaks, false)


## Whether angle `a` on ring `k` (radius `r`) is in one of its gaps (padded
## by `pad` m).
func _in_gap(k: int, a: float, r: float, pad := 0.0) -> bool:
	for g: float in REEF_GAPS[k]:
		var arc := absf(angle_difference(a, deg_to_rad(g))) * r
		if arc < REEF_GAP_WIDTH * 0.5 + pad:
			return true
	return false


## Where the gaps in the reef's rings are (world space, at sea level), ring
## by ring from the outside in.
func reef_gaps() -> Array:
	var out: Array = []
	for k in range(REEF_RINGS.size() - 1, -1, -1):
		var r := inner + width * REEF_RINGS[k]
		var ring: Array[Vector3] = []
		for g: float in REEF_GAPS[k]:
			var a := deg_to_rad(g)
			ring.append(to_global(Vector3(cos(a) * r, 0, sin(a) * r)))
		out.append(ring)
	return out


## The fort guns still firing.
func guns_firing() -> int:
	var n := 0
	for c in get_children():
		if c is FortGun and not (c as FortGun).is_silenced():
			n += 1
	return n


## One of Brock's gun towers round Cannonball Cliffs: a stone tower on a
## rock, a cannon on top that swings to follow Patchy's boat and lobs shot
## at it, and Brock's flag. A ball from Patchy's bow cannon silences it for
## good (WorldState `gun_id`): the flag comes down and it just smokes.
class FortGun extends StaticBody3D:
	const RANGE := 120.0
	const FLIGHT := 1.7
	## The whole fort, scaled up from its model to read from out at sea.
	const SIZE := 1.8

	var hazard: SeaHazard
	var gun_id: StringName
	var build_seed := 0
	var _cannon: Node3D
	var _flag: Node3D
	var _cool := 0.0
	var _smoke_t := 0.0

	func _ready() -> void:
		collision_layer = Layers.WORLD
		collision_mask = 0
		_cool = randf_range(0.5, 2.5)
		var rng := RandomNumberGenerator.new()
		rng.seed = build_seed
		var mb := PropBuilder.new()
		mb.append(HorizonIsland.lump(Vector3(7.5, 3.2, 6.5), rng.randi(), Transform3D(Basis.IDENTITY, Vector3(0, -0.8, 0)), 0.18, [], 6, 10))
		mb.recolor(func(p: Vector3, _n: Vector3, _c: Color) -> Color: return Color("7a6a58").lerp(Color("a39279"), clampf(p.y / 2.4, 0.0, 1.0)), 0)
		mb.cylinder(2.8, 3.1, 5.0, Transform3D(Basis.IDENTITY, Vector3(0, 4.0, 0)), Color("8d8a84"), 14)
		for k in 8:
			var a := TAU * k / 8.0
			mb.box(Vector3(0.9, 0.8, 0.6), Transform3D(Basis(Vector3.UP, -a), Vector3(cos(a) * 2.6, 6.9, sin(a) * 2.6)), Color("9c988f"))
		mb.cylinder(0.9, 1.0, 0.3, Transform3D(Basis.IDENTITY, Vector3(0, 1.6, -2.95)), Color("3a2a1e"), 8)
		var model := Node3D.new()
		model.scale = Vector3.ONE * SIZE
		add_child(model)
		var mi := MeshInstance3D.new()
		mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		mi.visibility_range_end = 900.0
		model.add_child(mi)
		_cannon = Node3D.new()
		_cannon.position = Vector3(0, 7.0, 0)
		model.add_child(_cannon)
		var cm := MeshBuilder.new()
		cm.cylinder(0.32, 0.42, 2.4, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.35, -1.0)), Color("2e3138"), 10)
		cm.torus(0.28, 0.44, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), Vector3(0, 0.35, -2.2)), Color("3a3f4a"), 12, 6)
		cm.box(Vector3(1.1, 0.5, 1.6), Transform3D(Basis.IDENTITY, Vector3(0, 0.0, -0.3)), Color("5b3920"))
		var cmi := MeshInstance3D.new()
		cmi.mesh = cm.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
		_cannon.add_child(cmi)
		_flag = Node3D.new()
		_flag.position = Vector3(1.6, 7.0, 1.6)
		model.add_child(_flag)
		var fm := MeshBuilder.new()
		fm.cylinder(0.07, 0.07, 4.5, Transform3D(Basis.IDENTITY, Vector3(0, 2.25, 0)), Color("5b3920"), 6)
		# Brock's colors: croc green with a row of white teeth.
		fm.triangle(Vector3(0, 4.4, 0), Vector3(0, 4.4, 1.8), Vector3(0, 3.2, 1.8), Color("3f8a3a"), true)
		fm.triangle(Vector3(0, 4.4, 0), Vector3(0, 3.2, 1.8), Vector3(0, 3.2, 0), Color("3f8a3a"), true)
		for t in 4:
			var z := 0.2 + t * 0.4
			fm.triangle(Vector3(0.02, 3.8, z), Vector3(0.02, 3.8, z + 0.36), Vector3(0.02, 3.5, z + 0.18), Color.WHITE, true)
		var fmi := MeshInstance3D.new()
		fmi.mesh = fm.build(null, MaterialLibrary.toon(Color.WHITE, &"soft"))
		_flag.add_child(fmi)
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 6.0 * SIZE
		cyl.height = 9.0 * SIZE
		cs.shape = cyl
		cs.position = Vector3(0, 2.5 * SIZE, 0)
		add_child(cs)
		if is_silenced():
			_show_silenced()

	func is_silenced() -> bool:
		return gun_id != &"" and WorldState.is_completed(gun_id)

	func on_cannon_hit(ball: Node) -> void:
		if is_silenced() or (ball as Cannonball) == null or (ball as Cannonball).shooter is FortGun:
			return
		WorldState.mark_completed(gun_id)
		AudioManager.play(&"explosion", global_position + Vector3.UP * 7.0 * SIZE, 2.0, 0.8)
		VFX.dust(get_tree().current_scene, global_position + Vector3.UP * 7.0 * SIZE, 14, 1.2 * SIZE, Color(0.35, 0.33, 0.32, 0.85), 3.0 * SIZE, 3.0)
		_show_silenced()
		var left := hazard.guns_firing() if hazard != null else 0
		if left == 0:
			AudioManager.play_stinger(&"stinger_treasure")
			Events.hud_message.emit("Brock's fort guns are all silenced!", 3.5)
		else:
			Events.hud_message.emit("A fort gun silenced! %d to go." % left, 2.5)

	func _show_silenced() -> void:
		_flag.visible = false
		_cannon.rotation = Vector3(-0.35, _cannon.rotation.y, 0.25)

	func _physics_process(delta: float) -> void:
		var p := GameManager.player as Player
		if p == null or not is_instance_valid(p):
			return
		var d := global_position.distance_to(p.global_position)
		if is_silenced():
			_smoke_t -= delta
			if d < 300.0 and _smoke_t <= 0.0:
				_smoke_t = 0.8
				VFX.dust(get_tree().current_scene, global_position + Vector3(0, 7.6 * SIZE, 0), 3, 0.9 * SIZE, Color(0.3, 0.3, 0.3, 0.6), 1.0 * SIZE, 2.5)
			return
		if d > RANGE * 1.6:
			return
		var target := p.global_position
		var vel := p.velocity
		var aim := Player.flat(target - _cannon.global_position)
		if aim.length() > 0.1:
			_cannon.global_rotation.y = lerp_angle(_cannon.global_rotation.y, Player.yaw_of(aim), 1.0 - exp(-delta * 3.0))
		_cool -= delta
		if d > RANGE or _cool > 0.0 or (p.state_id != &"boat" and p.state_id != &"swim"):
			return
		_cool = randf_range(2.2, 3.4)
		_fire(target + Player.flat(vel) * FLIGHT)

	func _fire(at: Vector3) -> void:
		# A near miss: Brock's gunners mean to scare, and do.
		var miss := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(3.5, 8.0)
		var goal := Vector3(at.x, 0.0, at.z) + miss
		var muzzle := _cannon.global_transform * Vector3(0, 0.35, -2.3)
		var ball := Cannonball.new()
		ball.shooter = self
		ball.sea_level = 0.0
		var v := (goal - muzzle) / FLIGHT
		v.y = (goal.y - muzzle.y + 0.5 * Cannonball.GRAVITY * FLIGHT * FLIGHT) / FLIGHT
		ball.velocity = v
		get_tree().current_scene.add_child(ball)
		ball.global_position = muzzle
		AudioManager.play(&"cannon_fire", muzzle, 2.0, 0.75)
		VFX.dust(get_tree().current_scene, muzzle, 8, 0.8, Color(0.9, 0.9, 0.9, 0.8), 1.4, 1.0)
