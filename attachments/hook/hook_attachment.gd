class_name HookAttachment
extends AttachmentBase
## Patchy's own hook (spec §51–52): never obsolete. Swipes, catches rings to
## swing, and grabs hook handles. Its visual is the model's built-in hook.

func equip(p: Player) -> void:
	super.equip(p)
	var m := p.get_node_or_null("Visual/PatchyModel") as PatchyModel
	if m != null and m.hook_mesh != null:
		m.hook_mesh.visible = true


func unequip() -> void:
	super.unequip()
	if player == null:
		return
	var m := player.get_node_or_null("Visual/PatchyModel") as PatchyModel
	if m != null and m.hook_mesh != null:
		m.hook_mesh.visible = false


func primary_action() -> void:
	if player == null:
		return
	if not player.is_on_floor() and player.combat.try_hook_latch():
		return
	# On the ground the hook's primary use is a quick swipe.
	player.combat.request_swipe()
