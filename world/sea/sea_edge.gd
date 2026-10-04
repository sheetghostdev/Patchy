class_name SeaEdge
extends Node3D
## The edge of the chart: past `radius` from here there's nothing but fog
## and open sea. Keep sailing out and the fog turns Patchy round: the iris
## closes and opens on his boat coming back out of the fog, heading home.
## Not a wall: the sea still looks endless, and every island lies inside.

@export var radius := 1500.0
## How far into the fog before it turns him round.
@export var depth := 90.0

var _busy := false
var _hint_cool := 0.0


func _physics_process(delta: float) -> void:
	_hint_cool = maxf(_hint_cool - delta, 0.0)
	var p := GameManager.player as Player
	if p == null or _busy or SceneTransition.is_busy():
		return
	var body := _carrier(p)
	var off := Vector3(body.global_position.x - global_position.x, 0, body.global_position.z - global_position.z)
	var d := off.length()
	if d < radius:
		return
	if _hint_cool <= 0.0:
		_hint_cool = 12.0
		Events.hud_message.emit("Nothing out here but fog and open sea... the islands all lie the other way.", 3.0)
	if d > radius + depth:
		_turn_round(p, off.normalized())


## What carries Patchy: his boat while he sails, else Patchy himself.
func _carrier(p: Player) -> Node3D:
	if p.state_id == &"boat":
		for b in get_tree().get_nodes_in_group(&"boat"):
			var boat := b as TinyBoat
			if boat != null and boat.driver == p:
				return boat
	return p


func _turn_round(p: Player, out: Vector3) -> void:
	_busy = true
	await SceneTransition.fade_out(0.6)
	if is_instance_valid(p):
		var body := _carrier(p)
		var at := global_position + out * (radius - 40.0)
		at.y = 0.0
		if body is TinyBoat:
			var boat := body as TinyBoat
			boat.place(at, -out, boat.get_speed())
			# Still seated: the boat state keeps him in his seat.
			p.global_position = boat.get_seat_transform().origin
			p.reset_physics_interpolation()
		else:
			p.teleport(at + Vector3.UP * 0.5, -out)
		var rig := p.camera_rig as CameraRig
		if rig != null:
			rig.snap_behind_target()
		Events.hud_message.emit("The fog turns you round. Land must lie the other way!", 3.0)
	await SceneTransition.fade_in(0.6)
	_busy = false
