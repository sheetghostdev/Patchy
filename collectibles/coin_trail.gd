@tool
class_name CoinTrail
extends Node3D
## Lays out a trail of coins for guiding players and teaching jumps
## (spec §84, §126): a straight line, a jump arc, or a ring. Coins are
## generated at load, so moving the trail in the editor just works.

enum TrailShape { LINE, ARC, RING }

@export var shape := TrailShape.ARC:
	set(v):
		shape = v
		_queue()
## Local end point for LINE and ARC trails.
@export var end_point := Vector3(0, 0, -6):
	set(v):
		end_point = v
		_queue()
## Extra height at the middle of an ARC (matches a jump).
@export_range(0.0, 10.0, 0.05) var arc_height := 2.2:
	set(v):
		arc_height = v
		_queue()
@export_range(0.2, 20.0, 0.1) var ring_radius := 1.8:
	set(v):
		ring_radius = v
		_queue()
@export_range(1, 60) var count := 7:
	set(v):
		count = v
		_queue()
@export_enum("coin", "gem", "pearl") var kind: String = "coin":
	set(v):
		kind = v
		_queue()
## Coins float this high above the trail line.
@export var lift := 0.6:
	set(v):
		lift = v
		_queue()

var _pending := false


func _ready() -> void:
	_rebuild()


func _queue() -> void:
	if is_inside_tree() and not _pending:
		_pending = true
		_rebuild.call_deferred()


func _rebuild() -> void:
	_pending = false
	for c in get_children(true):
		if c is Collectible and c.get_meta(&"trail_generated", false):
			c.free()
	for i in count:
		var t := float(i) / maxf(count - 1, 1)
		var pos := Vector3.ZERO
		match shape:
			TrailShape.LINE:
				pos = Vector3.ZERO.lerp(end_point, t)
			TrailShape.ARC:
				pos = Vector3.ZERO.lerp(end_point, t) + Vector3.UP * arc_height * 4.0 * t * (1.0 - t)
			TrailShape.RING:
				var a := TAU * float(i) / count
				pos = Vector3(cos(a) * ring_radius, 0, sin(a) * ring_radius)
		var c := Collectible.new()
		c.kind = kind
		c.position = pos + Vector3.UP * lift
		c.set_meta(&"trail_generated", true)
		add_child(c, false, Node.INTERNAL_MODE_FRONT)
