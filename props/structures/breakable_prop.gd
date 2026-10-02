@tool
class_name BreakableProp
extends PropBody
## Base for smashable static props (Crate, Barrel). When `breakable`, any hit
## (take_hit with any damage: swipe, dive, stomp, ground pound, cannon,
## explosion) or a ground pound (on_ground_pound) breaks it: tumbling debris
## (PropDebris), a dust puff, AudioManager.play(break_sound), optional
## `contents` spawned, the `broken` signal, and WorldState.mark_completed()
## when `persistent_id` is set (such props remove themselves on load once
## broken). Breakables sit on Layers.PROPS so Patchy's attack hitboxes see
## them (he still stands on them; the camera ignores them). Non-breakable
## props are plain static scenery on Layers.WORLD that just wobble when hit.
##
## Spawned contents are added next to the prop; if an item has
## `launch(velocity: Vector3)` it is called (deferred), RigidBody3D items get
## a linear velocity instead. See PropBreaker for the shared break logic.

signal broken(prop: Node3D)

@export var breakable := true:
	set(v):
		breakable = v
		_queue_rebuild()
## Scene spawned when broken (coins, hearts...).
@export var contents: PackedScene
@export_range(0, 30) var contents_count := 1
## Stable save id (e.g. &"castaway_crate_07"). Broken props stay broken.
@export var persistent_id: StringName = &""
@export var break_sound: StringName = &"crate_break"

var is_broken := false
var _wobble: Tween


func _layer() -> int:
	return Layers.PROPS if breakable else Layers.WORLD


func _prop_ready() -> void:
	if Engine.is_editor_hint():
		return
	if persistent_id != &"" and WorldState.is_completed(persistent_id):
		is_broken = true
		queue_free()


## Local center of the prop (debris and effects originate here).
func _center() -> Vector3:
	return Vector3.UP * 0.5


## [[Mesh, Vector3 box_size], ...] fragments; override per prop.
func _debris_pieces() -> Array:
	return []


func _debris_count() -> int:
	return 8


func take_hit(hit: Dictionary) -> void:
	if not breakable or is_broken:
		_bonk()
		return
	break_apart(hit)


func on_ground_pound(player: Node) -> void:
	var pos: Vector3 = (player as Node3D).global_position if player is Node3D else global_position + Vector3.UP
	take_hit({"damage": 2, "kind": &"ground_pound", "source": player, "position": pos, "direction": Vector3.DOWN})


## Smashes the prop (also callable directly by scripts, e.g. explosions).
func break_apart(hit: Dictionary = {}) -> void:
	if is_broken or not is_inside_tree():
		return
	is_broken = true
	PropBreaker.shatter(self, global_transform * _center(), hit, _debris_pieces(), _debris_count(), break_sound, contents, contents_count, persistent_id)
	broken.emit(self)
	collision_layer = 0
	visible = false
	queue_free()


func _bonk() -> void:
	if Engine.is_editor_hint():
		return
	if _wobble != null and _wobble.is_valid():
		_wobble.kill()
	_wobble = PropBreaker.bonk(self, _visual_root())


func _visual_root() -> Node3D:
	for c in get_children(true):
		if c is MeshInstance3D and c.has_meta(PropKit.GEN_META):
			return c
	return null
