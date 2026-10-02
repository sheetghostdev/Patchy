class_name Interactable
extends Area3D
## Base for anything Patchy can use (spec §133): NPCs, doors, levers, parrot
## cages, dig spots, treasure chests, parrot tasks, boats. Patchy's
## PlayerInteraction picks the best candidate in range and shows a small
## prompt like "[E] Open" (spec §125). Subclasses override can_interact,
## get_prompt and interact.

signal interacted(player: Node3D)
signal focused(player: Node3D)
signal unfocused

## Prompt text; tokens like {interact} or {tool_primary} become button glyphs.
@export var prompt := "{interact} Use"
@export var enabled := true
## Input action that triggers this interaction.
@export var action: StringName = &"interact"
## Higher wins when several interactables are in reach.
@export var interact_priority := 0
## Patchy must roughly face it (dot of facing vs direction).
@export_range(-1.0, 1.0, 0.05) var min_facing := -0.2
## Radius of the auto-created detection sphere (0 = use child shapes).
@export_range(0.0, 10.0, 0.1) var radius := 1.6


func _ready() -> void:
	collision_layer = Layers.INTERACTABLE
	collision_mask = 0
	monitoring = false
	monitorable = true
	if radius > 0.0 and not _has_shape():
		var cs := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = radius
		cs.shape = sph
		add_child(cs, false, Node.INTERNAL_MODE_FRONT)


func _has_shape() -> bool:
	for c in get_children():
		if c is CollisionShape3D:
			return true
	return false


func can_interact(_player: Node3D) -> bool:
	return enabled


func get_prompt() -> String:
	return prompt


func interact(player: Node3D) -> void:
	interacted.emit(player)


## Where Patchy should look/turn when interacting.
func get_focus_point() -> Vector3:
	return global_position


func on_focus(player: Node3D) -> void:
	focused.emit(player)


func on_unfocus() -> void:
	unfocused.emit()
