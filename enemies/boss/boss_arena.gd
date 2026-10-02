class_name BossArena
extends Area3D
## The ring where a boss waits (spec §167). Stepping in wakes the boss;
## walking back out (or fainting) resets the fight, so there is never a
## locked-in soft fail. Pairs with a FocusCameraZone that frames the boss.

@export var boss: Node3D
@export_range(2.0, 60.0, 0.5) var radius := 12.0
## Grace before a fight resets after Patchy steps out (s).
@export var leave_grace := 1.5

var _shape: CollisionShape3D
var _outside_t := -1.0


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.PLAYER
	monitorable = false
	_shape = CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 10.0
	_shape.shape = cyl
	_shape.position = Vector3(0, 4.0, 0)
	add_child(_shape, false, Node.INTERNAL_MODE_FRONT)
	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)
	Events.player_respawned.connect(func(_p: Vector3) -> void: _reset())


func _on_enter(body: Node3D) -> void:
	if not body is Player or boss == null or not is_instance_valid(boss):
		return
	_outside_t = -1.0
	boss.call(&"begin_fight")


func _on_exit(body: Node3D) -> void:
	if body is Player:
		_outside_t = 0.0


func _physics_process(delta: float) -> void:
	if _outside_t < 0.0:
		return
	_outside_t += delta
	if _outside_t >= leave_grace:
		_outside_t = -1.0
		_reset()


func _reset() -> void:
	if boss == null or not is_instance_valid(boss) or not boss.has_method(&"reset_fight"):
		return
	boss.call(&"reset_fight")
	# Respawned inside the ring (a slip off a ledge): the king wakes again.
	await get_tree().create_timer(2.0, false).timeout
	if not is_instance_valid(boss):
		return
	for b in get_overlapping_bodies():
		if b is Player:
			boss.call(&"begin_fight")
			return
