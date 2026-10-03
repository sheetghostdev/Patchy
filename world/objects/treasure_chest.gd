@tool
class_name TreasureChest
extends Interactable
## Major treasure (spec §85): a chunky chest that may be locked by a puzzle
## (chained to posts that must be pounded down). Opening it is a moment: the
## lid swings, light and sparkles spill out, the treasure pops up and Patchy
## grabs it. Persistent by chest_id.

signal opened

@export var chest_id: StringName = &""
@export var island_id: StringName = &""
## Treasure kind inside (crown, goblet, relic, gem) and value (0 = default).
@export_enum("crown", "goblet", "relic", "gem", "pearl") var contents: String = "crown"
@export var contents_value := 0
@export var coins := 8
## Posts that must be driven down first (empty = unlocked).
@export var lock_posts: Array[PoundPost] = []
@export var gold_variant := false
## A hand attachment packed inside too (handed over after the treasure).
@export var attachment_reward: StringName = &""
## Treasure map tucked in with the prize (TreasureMaps id).
@export var map_reward: StringName = &""
## A key item packed inside too (KeyItemPickup id), handed over last.
@export var key_item_reward: StringName = &""

var _lid: Node3D
var _chains: Node3D
var _open := false


func _ready() -> void:
	prompt = "{interact} Open"
	radius = 1.8
	super._ready()
	_build()
	if Engine.is_editor_hint():
		return
	if chest_id != &"":
		add_to_group(&"treasure_source")
	add_to_group(&"look_at_target")
	if chest_id != &"" and WorldState.is_completed(chest_id):
		_open = true
		enabled = false
		_lid.rotation.x = -1.9
		_chains.visible = false
		return
	for post in lock_posts:
		if post != null:
			post.pounded.connect(func(_p: PoundPost) -> void: _update_lock(true))
	_update_lock(false)


## For IslandInfo's treasure totals (the prize inside).
func get_treasure_island() -> StringName:
	return island_id


func is_locked() -> bool:
	for post in lock_posts:
		if post != null and not post.down:
			return true
	return false


func _update_lock(with_fx: bool) -> void:
	var locked := is_locked()
	if not locked and _chains.visible:
		_chains.visible = false
		if with_fx:
			AudioManager.play(&"door_open", global_position)
			VFX.sparkle(self, global_position + Vector3.UP * 0.8, Palette.GOLD, 14)


func can_interact(_player: Node3D) -> bool:
	return enabled and not _open


func get_prompt() -> String:
	return "Chained shut..." if is_locked() else prompt


func interact(player: Node3D) -> void:
	if is_locked():
		AudioManager.play(&"switch_click", global_position, -4.0)
		Events.hud_message.emit("The chains are pinned by those posts.", 2.5)
		return
	super.interact(player)
	open(player as Player)


func open(player: Player) -> void:
	if _open:
		return
	_open = true
	enabled = false
	remove_from_group(&"look_at_target")
	if player != null:
		player.set_locked(true, {"anim": &"idle", "face": Player.flat(global_position - player.global_position).normalized()})
	AudioManager.play(&"chest_open", global_position)
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_property(_lid, "rotation:x", -1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished
	VFX.sparkle(self, global_position + Vector3.UP * 0.9, Palette.GOLD, 26, 6.0)
	var prize := Collectible.new()
	prize.kind = contents
	prize.value = contents_value
	prize.treasure_id = StringName("%s_prize" % chest_id) if chest_id != &"" else &""
	prize.island_id = island_id
	prize.magnet_radius = 0.0
	prize.float_motion = false
	get_tree().current_scene.add_child(prize)
	prize.global_position = global_position + Vector3.UP * 0.6
	var rise := create_tween()
	rise.tween_property(prize, "global_position", global_position + Vector3.UP * 2.2, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	AudioManager.play_stinger(&"stinger_treasure")
	await get_tree().create_timer(1.3, false).timeout
	if player != null and is_instance_valid(prize):
		prize.collect(player)
	for i in coins:
		var c := Collectible.new()
		c.kind = "coin"
		c.launched = true
		get_tree().current_scene.add_child(c)
		c.global_position = global_position + Vector3.UP * 0.8
	if map_reward != &"" and not InventoryManager.has_treasure_map(map_reward):
		InventoryManager.add_treasure_map(map_reward)
	if chest_id != &"":
		WorldState.mark_completed(chest_id)
	opened.emit()
	if key_item_reward != &"" and not InventoryManager.has_key_item(key_item_reward):
		var item := KeyItemPickup.new()
		item.item_id = key_item_reward
		item.bare = true
		get_tree().current_scene.add_child(item)
		item.global_position = global_position + Vector3.UP * 0.4
		await get_tree().create_timer(0.9, false).timeout
		if player != null and is_instance_valid(item):
			if player.state_id == &"locked":
				player.set_locked(false)
			item.call(&"_on_body", player)
		return
	if attachment_reward != &"" and not InventoryManager.has_attachment(attachment_reward):
		var gift := AttachmentPickup.new()
		gift.attachment_id = attachment_reward
		gift.bare = true
		get_tree().current_scene.add_child(gift)
		gift.global_position = global_position + Vector3.UP * 0.2
		await get_tree().create_timer(0.9, false).timeout
		if player != null and is_instance_valid(gift):
			if player.state_id == &"locked":
				player.set_locked(false)
			gift.call(&"_on_body", player)
		return
	await get_tree().create_timer(0.4, false).timeout
	if player != null and player.state_id == &"locked":
		player.set_locked(false)


func _build() -> void:
	var wood := Palette.WOOD if not gold_variant else Palette.GOLD
	var band := Palette.BRASS if not gold_variant else Palette.GOLD.lightened(0.2)
	var body := MeshBuilder.new()
	var metal := MeshBuilder.new()
	body.rounded_box(Vector3(1.1, 0.6, 0.7), 0.06, Transform3D(Basis.IDENTITY, Vector3(0, 0.3, 0)), wood, 2)
	for x: float in [-0.38, 0.38]:
		metal.box(Vector3(0.1, 0.62, 0.74), Transform3D(Basis.IDENTITY, Vector3(x, 0.31, 0)), band)
	var base_mesh := ArrayMesh.new()
	body.build(base_mesh, MaterialLibrary.toon(Color.WHITE, &"matte"))
	metal.build(base_mesh, MaterialLibrary.toon(Color.WHITE, &"metal"))
	var mi := MeshInstance3D.new()
	mi.mesh = base_mesh
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.6, 0.35)
	add_child(_lid, false, Node.INTERNAL_MODE_FRONT)
	var lid := MeshBuilder.new()
	var lid_metal := MeshBuilder.new()
	lid.cylinder(0.35, 0.35, 1.1, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)).scaled(Vector3(1, 1, 0.9)), Vector3(0, 0.0, -0.35)), wood.lightened(0.05), 14)
	for x: float in [-0.38, 0.38]:
		lid_metal.torus(0.33, 0.39, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(x, 0.0, -0.35)), band, 16, 4)
	lid_metal.rounded_box(Vector3(0.16, 0.2, 0.06), 0.02, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.72)), band.darkened(0.1), 1)
	var lid_mesh := ArrayMesh.new()
	lid.build(lid_mesh, MaterialLibrary.toon(Color.WHITE, &"matte"))
	lid_metal.build(lid_mesh, MaterialLibrary.toon(Color.WHITE, &"metal"))
	var lmi := MeshInstance3D.new()
	lmi.mesh = lid_mesh
	_lid.add_child(lmi)
	# Chains crossing the chest while locked.
	_chains = Node3D.new()
	add_child(_chains, false, Node.INTERNAL_MODE_FRONT)
	var chain := MeshBuilder.new()
	for k in 2:
		var a := deg_to_rad(35.0 if k == 0 else -35.0)
		for j in 9:
			var t := (j - 4) * 0.15
			var p := Vector3(cos(a) * t, 0.95 - absf(t) * 0.5, sin(a) * t)
			chain.torus(0.035, 0.06, Transform3D(Basis.from_euler(Vector3(0, a, (j % 2) * PI * 0.5)), p), Palette.METAL, 8, 4)
	var cmi := MeshInstance3D.new()
	cmi.mesh = chain.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	_chains.add_child(cmi)
