@tool
class_name TreasureDisplay
extends PropNode
## Decorative treasure using the PropMeshes collectible meshes: a single
## (optionally spinning and bobbing) coin or gem, or a loose pile of coins
## and gems for caves and treasure rooms. Purely visual - real pickups live
## in the collectible scripts, which use PropMeshes directly.

enum Kind { COIN, GEM, PILE }

@export var kind := Kind.COIN:
	set(v):
		kind = v
		_queue_rebuild()
@export var gem_color := Palette.GEM_RED:
	set(v):
		gem_color = v
		_queue_rebuild()
## PILE: number of coins.
@export_range(3, 80) var count := 24:
	set(v):
		count = v
		_queue_rebuild()
## Spin and bob at runtime (COIN / GEM).
@export var spin := true
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()

var _visual: Node3D
var _t := 0.0


func _build() -> void:
	match kind:
		Kind.COIN:
			_visual = add_mesh(PropMeshes.coin(), "Coin")
			_visual.position.y = 0.45
		Kind.GEM:
			_visual = add_mesh(PropMeshes.gem(gem_color), "Gem")
			_visual.position.y = 0.45
		Kind.PILE:
			_visual = null
			add_mesh(PropKit.cached_mesh("treasure_pile_%d_%d" % [count, seed], func() -> Mesh:
				return _pile_mesh()
			), "Pile")


func _pile_mesh() -> ArrayMesh:
	var rng := PropKit.make_rng(seed, 88)
	var parts := PropParts.new()
	var radius := 0.25 + sqrt(float(count)) * 0.08
	var height := radius * 0.6
	parts.soft.ellipsoid(Vector3(radius, height, radius), Transform3D(Basis.IDENTITY, Vector3.UP * height * 0.1), PropPalette.CHEST_GOLD_DARK, 6, 14)
	# Loose coins: simple discs (the pile is seen from a distance).
	for k in count:
		var a := rng.randf() * TAU
		var rr := sqrt(rng.randf()) * radius * 0.95
		var y := height * 0.1 + height * sqrt(maxf(1.0 - pow(rr / radius, 2.0), 0.0)) - 0.01
		var tilt := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		parts.metal.cylinder(0.11, 0.11, 0.03, Transform3D(tilt, Vector3(cos(a) * rr, y, sin(a) * rr)), PropPalette.COIN if k % 3 else PropPalette.COIN_RIM, 10)
	var gems := [Palette.GEM_RED, Palette.GEM_BLUE, PropPalette.GEM_GREEN, PropPalette.GEM_PURPLE]
	for k in maxi(floori(count / 8.0), 1):
		var a := rng.randf() * TAU
		var rr := rng.randf() * radius * 0.6
		var y := height * 0.1 + height * sqrt(maxf(1.0 - pow(rr / radius, 2.0), 0.0)) + 0.03
		parts.gem.append(PropMeshes.gem_builder(gems[k % gems.size()], 0.14), Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, 0.2)), Vector3(cos(a) * rr, y, sin(a) * rr)))
	return parts.build()


func _process(delta: float) -> void:
	if _visual == null or not spin or Engine.is_editor_hint():
		return
	_t += delta
	_visual.rotation.y = _t * 2.2
	_visual.position.y = 0.45 + sin(_t * 2.6) * 0.06
