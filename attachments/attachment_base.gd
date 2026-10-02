class_name AttachmentBase
extends Node3D
## Base for Patchy's interchangeable hand attachments (spec §53). Mounted in
## the arm's HookSocket while equipped. Every attachment should offer
## traversal, puzzle, combat and secret-finding uses; keep that logic here,
## never in Player.gd.

var player: Player
var data: AttachmentData


func equip(p: Player) -> void:
	player = p
	visible = true


func unequip() -> void:
	visible = false


## tool_primary pressed while this attachment is equipped.
func primary_action() -> void:
	pass


## tool_secondary pressed.
func secondary_action() -> void:
	pass


## Called every physics tick while equipped (held actions, aiming).
func physics_update(_delta: float) -> void:
	pass


func can_interact(_target: Node) -> bool:
	return false


func interact(_target: Node) -> void:
	pass


## Kind reported by the melee swipe while equipped (enemies may react).
func melee_kind() -> StringName:
	return &"swipe"


## Whether primary_action may also run mid-air (grapple, cannon hop).
func allows_air_action() -> bool:
	return false


## One-line how-to shown when the attachment is first found.
func pickup_hint() -> String:
	return ""


## Adds a mesh built in socket space (the forearm points down -Y).
func add_mesh(mb: MeshBuilder, finish: StringName = &"soft") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, finish))
	add_child(mi)
	return mi
