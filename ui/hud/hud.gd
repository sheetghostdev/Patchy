class_name UIHud
extends Control
## In-game HUD. Minimal by design: hearts and the equipped attachment stay
## while a player exists; treasure and parrot counters appear on change and
## tuck away; prompts, requirements, island titles, toasts, subtitles and
## dialogue appear only when relevant. Hidden entirely when there is no
## player (title screen, menus without a level).

@export var screen_margin := Vector2(52, 40)
@export var counter_gap: float = 10.0

var hearts: UIHeartsDisplay
var treasure: UITreasureCounter
var parrots: UIParrotCounter
var attachment: UIAttachmentBadge
var requirement: UIParrotRequirement
var prompt: UIInteractionPrompt
var banner: UIIslandBanner
var swim: UISwimMeter
var toasts: UIToastStack
var subtitles: UISubtitles
var dialogue: UIDialogueBox

var _top_left: Control
var _bottom_right: Control
var _bottom_center: Control
var _player: Node = null
var _health_node: Node = null
var _gameplay := false
var _menu_open := false
var _forced_hidden := false
var _dialogue_active := false
var _scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	_connect_signals()
	UIPrefs.ensure_loaded()
	UIPrefs.notifier().changed.connect(func(key: StringName) -> void:
		if key == &"hud_scale":
			apply_hud_scale(UIPrefs.hud_scale))
	apply_hud_scale(UIPrefs.hud_scale)
	_set_gameplay_visible(false, true)


func _build() -> void:
	_top_left = Control.new()
	_top_left.name = "TopLeft"
	_top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_left.position = screen_margin
	add_child(_top_left)
	hearts = UIHeartsDisplay.new()
	hearts.name = "Hearts"
	_top_left.add_child(hearts)
	treasure = UITreasureCounter.new()
	treasure.name = "Treasure"
	_top_left.add_child(treasure)
	parrots = UIParrotCounter.new()
	parrots.name = "Parrots"
	_top_left.add_child(parrots)

	_bottom_right = Control.new()
	_bottom_right.name = "BottomRight"
	_bottom_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_right.anchor_left = 1.0
	_bottom_right.anchor_right = 1.0
	_bottom_right.anchor_top = 1.0
	_bottom_right.anchor_bottom = 1.0
	add_child(_bottom_right)
	attachment = UIAttachmentBadge.new()
	attachment.name = "Attachment"
	_bottom_right.add_child(attachment)
	attachment.position = Vector2(-screen_margin.x - attachment.badge_size, -screen_margin.y - attachment.badge_size)

	_bottom_center = Control.new()
	_bottom_center.name = "BottomCenter"
	_bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_bottom_center)
	# Captions stay visible in cutscenes (set_forced_hidden), so they live
	# outside the hideable gameplay groups.
	subtitles = UISubtitles.new()
	subtitles.name = "Subtitles"
	add_child(_center_row(subtitles, 300.0))
	requirement = UIParrotRequirement.new()
	requirement.name = "ParrotRequirement"
	_bottom_center.add_child(_center_row(requirement, 196.0))
	prompt = UIInteractionPrompt.new()
	prompt.name = "Prompt"
	_bottom_center.add_child(_center_row(prompt, 104.0))

	banner = UIIslandBanner.new()
	banner.name = "IslandBanner"
	add_child(banner)

	swim = UISwimMeter.new()
	swim.name = "SwimMeter"
	add_child(swim)

	toasts = UIToastStack.new()
	toasts.name = "Toasts"
	toasts.anchor_left = 0.5
	toasts.anchor_right = 0.5
	toasts.offset_top = 34.0
	toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(toasts)

	dialogue = UIDialogueBox.new()
	dialogue.name = "Dialogue"
	add_child(dialogue)
	# Timed messages freeze while the game is paused so nothing is missed
	# behind a menu (the HUD groups themselves keep fading in/out).
	for c: Control in [banner, toasts, subtitles]:
		c.process_mode = Node.PROCESS_MODE_PAUSABLE
	dialogue.line_started.connect(func(i: int) -> void:
		if i == 0:
			set_dialogue_active(true))
	dialogue.finished.connect(func() -> void: set_dialogue_active(false))


## Full-width row anchored `bottom_offset` px above the bottom edge that keeps
## `c` horizontally centered whatever its size, growing upward.
func _center_row(c: Control, bottom_offset: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = String(c.name) + "Row"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 1.0
	row.anchor_bottom = 1.0
	row.offset_bottom = -bottom_offset
	row.offset_top = -bottom_offset
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(c)
	return row


func _connect_signals() -> void:
	Events.player_spawned.connect(func(_p: Node3D) -> void: _refresh_player())
	Events.player_damaged.connect(_on_player_health_event)
	Events.player_healed.connect(_on_player_health_event)
	Events.attachment_equipped.connect(func(id: StringName) -> void:
		attachment.set_attachment(id, _gameplay))
	Events.attachment_unlocked.connect(_on_attachment_unlocked)
	Events.interaction_prompt_changed.connect(prompt.push)
	Events.parrot_requirement_shown.connect(requirement.set_requirement)
	Events.island_discovered.connect(func(_id: StringName, display_name: String) -> void:
		banner.show_title(display_name))
	Events.hud_message.connect(func(text: String, duration: float) -> void:
		toasts.show_toast(text, duration))
	Events.checkpoint_reached.connect(func(_id: StringName) -> void:
		if _gameplay:
			toasts.show_toast("Checkpoint!", 1.6, &"flag"))
	Events.ship_part_recovered.connect(func(_id: StringName) -> void:
		toasts.show_toast("Ship part recovered!", 2.6, &"ship_wheel"))
	Events.treasure_map_found.connect(func(_id: StringName) -> void:
		toasts.show_toast("Treasure map found! Read it in Pause > Treasure", 3.2, &"treasure_map"))
	InventoryManager.gold_changed.connect(func(total: int) -> void:
		treasure.set_value(total, _gameplay))
	ParrotManager.flock_changed.connect(func(total: int) -> void:
		parrots.set_total(total, _gameplay))


func _on_attachment_unlocked(id: StringName) -> void:
	toasts.show_toast("New attachment: %s!" % UIAttachmentInfo.display_name(id), 3.0, UIAttachmentInfo.icon(id))
	attachment.show_cycle_hints()


func _on_player_health_event(_amount: int, health: int) -> void:
	# Fallback when the player's PlayerHealth isn't bound directly.
	if _health_node == null:
		hearts.set_health(health, hearts.max_health, _gameplay)


func _process(delta: float) -> void:
	_refresh_player()
	_layout_stack(delta)


func _refresh_player() -> void:
	var p: Node = GameManager.player
	if p != null and not is_instance_valid(p):
		p = null
	if p == _player:
		return
	_bind_player(p)


func _bind_player(p: Node) -> void:
	if _health_node != null and is_instance_valid(_health_node) \
			and _health_node.is_connected(&"health_changed", _on_health_changed):
		_health_node.disconnect(&"health_changed", _on_health_changed)
	_player = p
	_health_node = null
	if p != null:
		var h: Variant = p.get(&"health")
		if h is Node and (h as Node).has_signal(&"health_changed"):
			_health_node = h
			_health_node.connect(&"health_changed", _on_health_changed)
			hearts.set_health(int(_health_node.get(&"health")), int(_health_node.get(&"max_health")), false)
		else:
			hearts.set_health(InventoryManager.max_health, InventoryManager.max_health, false)
		treasure.set_value(InventoryManager.gold_value, false)
		parrots.set_total(ParrotManager.get_total(), false)
		attachment.set_attachment(InventoryManager.equipped_attachment, false)
	else:
		prompt.clear()
		requirement.set_requirement(0, 0, false)
	_update_visibility()


func _on_health_changed(health: int, max_health: int) -> void:
	hearts.set_health(health, max_health, _gameplay)


## Hide everything for cutscenes / photo mode (dialogue still works).
func set_forced_hidden(on: bool) -> void:
	_forced_hidden = on
	_update_visibility()


func set_menu_open(open: bool) -> void:
	_menu_open = open
	_update_visibility()


func is_gameplay_visible() -> bool:
	return _gameplay


func _update_visibility() -> void:
	var want := _player != null and not _menu_open and not _forced_hidden
	_set_gameplay_visible(want, false)


func _set_gameplay_visible(on: bool, instant: bool) -> void:
	var changed := on != _gameplay
	_gameplay = on
	for c: Control in [_top_left, _bottom_right, _bottom_center]:
		# Prompts/requirements make room for the dialogue box.
		var want := on and not (c == _bottom_center and _dialogue_active)
		if instant:
			c.modulate.a = 1.0 if want else 0.0
			c.visible = want
		elif changed or c == _bottom_center or not want:
			# (Hidden before the player ever bound, e.g. an opening cutscene,
			# nothing "changed", but what's showing still has to go.)
			if want != (c.visible and c.modulate.a > 0.5):
				UIFx.fade(c, 1.0 if want else 0.0, 0.25 if want else 0.18)
	if on and changed and not instant:
		UIFx.pop(hearts, 0.06, 0.3)


## Called by the UI root while a conversation is on screen.
func set_dialogue_active(on: bool) -> void:
	_dialogue_active = on
	prompt.suppressed = on
	_set_gameplay_visible(_gameplay, false)


## Briefly shows the contextual counters (e.g. on arriving at an island).
func peek(duration: float = 3.0) -> void:
	if not _gameplay:
		return
	treasure.reveal(duration)
	parrots.reveal(duration)


func apply_hud_scale(s: float) -> void:
	_scale = s
	_top_left.scale = Vector2(s, s)
	_bottom_right.scale = Vector2(s, s)
	for c: Control in [prompt, requirement, subtitles]:
		var row := c.get_parent() as Control
		row.pivot_offset_ratio = Vector2(0.5, 1.0)
		row.scale = Vector2(s, s)


func _layout_stack(delta: float) -> void:
	var y := hearts.get_combined_minimum_size().y + counter_gap + 6.0
	var k := 1.0 - exp(-delta * 16.0)
	for c: Control in [treasure, parrots]:
		var presence := c.modulate.a if c.visible else 0.0
		c.position.y = lerpf(c.position.y, y, k) if presence > 0.01 else y
		y += (c.get_combined_minimum_size().y + counter_gap) * presence
