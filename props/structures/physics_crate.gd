@tool
class_name PhysicsCrate
extends RigidBody3D
## A loose, physics-driven crate on Layers.PROPS: it tumbles, stacks, can be
## stood on and gets shoved by attacks that don't break it (gameplay can also
## call push()). Same look as Crate (Crate.build_mesh) and, when
## `breakable`, the same smash behavior (PropBreaker: debris, dust, sound,
## contents, persistence, `broken` signal). Origin at the bottom center.

signal broken(prop: Node3D)

@export var size := Vector3.ONE * 0.9:
	set(v):
		size = v.max(Vector3.ONE * 0.2)
		_queue_rebuild()
@export var style := Crate.Style.AUTO:
	set(v):
		style = v
		_queue_rebuild()
@warning_ignore("shadowed_global_identifier")
@export var seed := 1:
	set(v):
		seed = v
		_queue_rebuild()
@export var breakable := false:
	set(v):
		breakable = v
		_queue_rebuild()
## Hits with at least this much damage smash a breakable crate; weaker hits
## just shove it.
@export_range(1, 5) var break_damage := 1
@export var contents: PackedScene
@export_range(0, 30) var contents_count := 1
@export var persistent_id: StringName = &""
@export var break_sound: StringName = &"crate_break"
## Impulse applied by a hit that doesn't break the crate.
@export_range(0.0, 30.0, 0.1) var hit_impulse := 5.0

var is_broken := false
var _pending := false
var _visual: MeshInstance3D


func _init() -> void:
	mass = 3.0


func _ready() -> void:
	collision_layer = Layers.PROPS
	collision_mask = Layers.WORLD | Layers.PROPS | Layers.PLAYER
	set_meta(&"surface", &"wood")
	_rebuild()
	if not Engine.is_editor_hint() and persistent_id != &"" and WorldState.is_completed(persistent_id):
		is_broken = true
		queue_free()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _pending:
		return
	_pending = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	PropKit.clear_generated(self)
	var st := style
	if st == Crate.Style.AUTO:
		st = Crate.Style.BRACED if breakable else Crate.Style.BANDED
	var light := breakable
	var mesh := PropKit.cached_mesh("crate_%s_%d_%d_%d" % [size, st, int(light), seed], func() -> Mesh:
		return Crate.build_mesh(size, st, light, seed)
	)
	_visual = PropKit.mesh_instance(self, mesh, "Crate")
	PropKit.collision(self, PropKit.box_shape(size), Transform3D(Basis.IDENTITY, Vector3.UP * size.y * 0.5))


## Shoves the crate along a world-space direction: a velocity change of
## `hit_impulse * strength` m/s plus a little hop.
func push(direction: Vector3, strength: float = 1.0) -> void:
	sleeping = false
	var flat := Vector3(direction.x, 0.0, direction.z)
	flat = flat.normalized() if flat.length_squared() > 0.0001 else Vector3.ZERO
	apply_central_impulse((flat + Vector3.UP * 0.3) * hit_impulse * strength * mass)


func take_hit(hit: Dictionary) -> void:
	if is_broken:
		return
	var damage := int(hit.get("damage", 1))
	if breakable and damage >= break_damage:
		break_apart(hit)
		return
	var from: Vector3 = hit.get("position", global_position - Vector3.FORWARD)
	var dir: Vector3 = hit.get("direction", Vector3.ZERO)
	var away := global_position - from
	away.y = 0.0
	push(dir if dir.length_squared() > 0.01 else away, 1.0 + 0.5 * (damage - 1))
	PropBreaker.bonk(self, _visual)


func on_ground_pound(player: Node) -> void:
	var pos: Vector3 = (player as Node3D).global_position if player is Node3D else global_position + Vector3.UP
	take_hit({"damage": 2, "kind": &"ground_pound", "source": player, "position": pos, "direction": Vector3.DOWN})


func break_apart(hit: Dictionary = {}) -> void:
	if is_broken or not is_inside_tree():
		return
	is_broken = true
	var center := global_transform * (Vector3.UP * size.y * 0.5)
	PropBreaker.shatter(self, center, hit, _debris_pieces(), 8, break_sound, contents, contents_count, persistent_id)
	broken.emit(self)
	collision_layer = 0
	visible = false
	queue_free()


func _debris_pieces() -> Array:
	var light := breakable
	var key := "physics_crate_debris_%s_%d" % [size, int(light)]
	return PropKit.cached(key, func() -> Array:
		var plank: Color = PropPalette.CRATE_BREAKABLE if light else PropPalette.PLANK
		var m := minf(size.x, minf(size.y, size.z))
		var specs := [Vector3(size.x * 0.78, m * 0.06, m * 0.22), Vector3(size.x * 0.48, m * 0.06, m * 0.22), Vector3(m * 0.15, m * 0.15, size.y * 0.62)]
		var out := []
		for sz: Vector3 in specs:
			var mb := PropBuilder.new()
			mb.chamfer_box(sz, minf(sz.y, sz.z) * 0.22, Transform3D.IDENTITY, plank)
			out.append([mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte")), sz])
		return out
	)
