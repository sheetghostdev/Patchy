class_name CompanionParrot
extends Node3D
## Crackers (spec §67), the first parrot Patchy frees, who rides on his left
## shoulder from then on. Never in the way and rarely heard:
## - flaps for balance whenever Patchy is airborne;
## - squawks a warning (at most every few seconds) when an enemy close by
##   winds up an attack;
## - cocks his head, with a soft chirp, at a secret within a few steps
##   (a hidden dig spot, an unclaimed gem): once per secret, now and then.
## Lives under the player; the bird itself sits on the model's chest.

const DANGER_RANGE := 7.0
const CURIOUS_RANGE := 7.5
const DANGER_COOLDOWN := 7.0
const CURIOUS_COOLDOWN := 14.0
## Perch on the model's chest pivot (left shoulder).
const PERCH := Vector3(-0.28, 0.21, 0.04)

signal warned
signal noticed(target: Node3D)

var player: Player
var bird: ParrotModel
var _danger_cool := 0.0
var _curious_cool := 6.0
var _look_target: Node3D = null
var _look_t := 0.0
var _noticed := {}
var _scan := 0.0
var _flap := 0.0
var _t := 0.0


## Gives Patchy his companion now if a parrot is already free, or as soon
## as the first one is rescued.
static func setup(p: Player) -> CompanionParrot:
	var c := CompanionParrot.new()
	c.name = "Crackers"
	c.player = p
	p.add_child(c)
	return c


func _ready() -> void:
	if ParrotManager.get_total() > 0:
		_perch(false)
	else:
		Events.parrot_rescued.connect(_on_first_rescue, CONNECT_ONE_SHOT)


func is_perched() -> bool:
	return bird != null and is_instance_valid(bird)


func _on_first_rescue(_id: StringName, _total: int) -> void:
	await get_tree().create_timer(1.6, false).timeout
	if is_inside_tree() and not is_perched():
		_perch(true)


func _model_chest() -> Node3D:
	var m := player.get_node_or_null(^"Visual/PatchyModel") as PatchyModel
	return m.chest if m != null else null


func _perch(fly_in: bool) -> void:
	var chest := _model_chest()
	if chest == null:
		return
	bird = ParrotModel.new()
	bird.plumage = ParrotModel.Plumage.SCARLET
	bird.scale = Vector3.ONE * 0.72
	chest.add_child(bird)
	bird.position = PERCH
	bird.set_folded()
	if fly_in:
		# Swoops down from above and settles on the shoulder.
		bird.position = PERCH + Vector3(-1.2, 2.4, 1.4)
		var tw := create_tween()
		tw.tween_property(bird, "position", PERCH, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_flap = 1.0
		AudioManager.play(&"parrot_squawk", player.global_position, -4.0, 1.25)
		Events.hud_message.emit("Crackers the parrot hops onto your shoulder!", 3.0)


func _process(delta: float) -> void:
	if not is_perched() or player == null:
		return
	_t += delta
	_danger_cool = maxf(_danger_cool - delta, 0.0)
	_curious_cool = maxf(_curious_cool - delta, 0.0)
	# Balance flaps in the air, folded wings on the ground.
	var airborne := not player.is_on_floor() and player.state_id in [&"air", &"dive", &"ground_pound", &"swing", &"grapple"]
	_flap = move_toward(_flap, 1.0 if airborne else 0.0, delta * 4.0)
	if _flap > 0.05:
		bird.set_flap(sin(_t * 22.0) * _flap)
	else:
		bird.set_folded()
	bird.body.position.y = sin(_t * 2.1) * 0.01
	_scan -= delta
	if _scan <= 0.0:
		_scan = 0.25
		_check_danger()
		_check_secrets()
	_update_head(delta)


func _check_danger() -> void:
	if _danger_cool > 0.0:
		return
	for n in get_tree().get_nodes_in_group(&"enemy"):
		var e := n as Node3D
		if e == null or not e.has_method(&"is_winding_up") or not e.call(&"is_winding_up"):
			continue
		if e.global_position.distance_to(player.global_position) < DANGER_RANGE:
			_danger_cool = DANGER_COOLDOWN
			_look_target = e
			_look_t = 1.2
			_flap = 1.0
			AudioManager.play(&"parrot_squawk", player.global_position, -3.0, 1.35)
			warned.emit()
			return


func _check_secrets() -> void:
	if _curious_cool > 0.0:
		return
	var best: Node3D = null
	var best_d := CURIOUS_RANGE
	for n in get_tree().get_nodes_in_group(&"dig_spot"):
		var spot := n as DigSpot
		if spot != null and spot.hidden and spot.can_dig() and not _noticed.has(spot.get_instance_id()):
			var d := spot.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = spot
	for n in get_tree().get_nodes_in_group(&"look_at_target"):
		var c := n as Collectible
		if c != null and c.treasure_id != &"" and not _noticed.has(c.get_instance_id()):
			var d := c.global_position.distance_to(player.global_position)
			if d < best_d:
				best_d = d
				best = c
	if best == null:
		return
	_noticed[best.get_instance_id()] = true
	_curious_cool = CURIOUS_COOLDOWN
	_look_target = best
	_look_t = 2.0
	AudioManager.play(&"parrot_chirp", player.global_position, -10.0, 1.3)
	noticed.emit(best)


func _update_head(delta: float) -> void:
	var head := bird.head
	if head == null:
		return
	_look_t -= delta
	if _look_t > 0.0 and is_instance_valid(_look_target):
		# Cock the head toward whatever caught Crackers' eye.
		var to := _look_target.global_position - head.global_position
		var local := bird.global_basis.inverse() * to
		var yaw := clampf(atan2(-local.x, -local.z), -1.4, 1.4)
		var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.6, 0.6)
		head.rotation = head.rotation.lerp(Vector3(pitch, yaw, 0.25), 1.0 - exp(-delta * 10.0))
	else:
		# Idle: little curious glances around.
		var idle := Vector3(sin(_t * 0.7) * 0.15, sin(_t * 0.43) * 0.6, sin(_t * 1.1) * 0.1)
		head.rotation = head.rotation.lerp(idle, 1.0 - exp(-delta * 3.0))
