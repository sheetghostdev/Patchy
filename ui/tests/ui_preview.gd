extends Node
## UI preview harness: instances the movement lab + ui_root.tscn (or uses the
## "UI" autoload when it is registered), then stages one UI state for
## screenshots. Pick it with a user arg:
##   tools/photo/shoot.sh scene=res://ui/tests/ui_preview.tscn out=/tmp/ui.png frames=80 size=1600x900 state=pause
## States: hud (default), hud_pad, dialogue, pause, map, map_all, collection,
##   attachments, quests, settings, controls, confirm, debug, debug_world,
##   title, title_settings, treasure_map (map=<id> zoom=<x> turn=<deg>).
## Extra args: pad=xbox|ps|nintendo forces gamepad glyphs; hud_scale=1.2
## previews the HUD size option (not saved); sighted=<id,...> pencils
## islands onto the chart as if seen through the Spyglass.
## Run without the photo tool to click around:
##   godot --path . res://ui/tests/ui_preview.tscn -- state=hud

const TITLE := "res://ui/title/title_screen.tscn"

@onready var lab: Node = $MovementLab
@onready var local_ui: UIRoot = $UI

var ui: UIRoot
var args := {}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var state := String(args.get("state", "hud"))
	_ensure_ui()
	_apply_pad_arg()
	if args.has("hud_scale"):
		UIPrefs.hud_scale = float(args["hud_scale"])
		ui.hud.apply_hud_scale(UIPrefs.hud_scale)
	if state.begins_with("title"):
		lab.queue_free()
		var title: Node = load(TITLE).instantiate()
		add_child(title)
		if state == "title_settings":
			await _frames(30)
			title.call(&"_open_settings")
		return
	_add_teleport_markers(lab)
	await _frames(4)
	_seed_progress()
	# sighted=bell_atoll,teacup_isle: islands seen through the Spyglass.
	for id in String(args.get("sighted", "")).split(",", false):
		GameManager.sight_island(StringName(id))
	await _frames(2)
	match state:
		"hud": _stage_hud(false)
		"hud_pad": _stage_hud(true)
		"dialogue": _stage_dialogue()
		"pause": ui.open_pause_menu()
		"map", "collection", "attachments", "quests":
			ui.open_pause_menu(StringName(state))
		"treasure_map":
			ui.open_pause_menu(&"collection")
			await _frames(2)
			var viewer := ui.pause_menu.map_viewer
			viewer.open(StringName(args.get("map", "castaway_map_1")))
			viewer.view.zoom = float(args.get("zoom", "1.0"))
			viewer.view.turn = deg_to_rad(float(args.get("turn", "0")))
		"map_all":
			var mp := ui.pause_menu.get_page(&"map") as UIMapPage
			mp.chart.reveal_all = true
			ui.open_pause_menu(&"map")
		"settings":
			ui.open_pause_menu(&"settings")
			await _frames(2)
			var sp := ui.pause_menu.get_page(&"settings") as UISettingsPanel
			sp.show_tab(StringName(args.get("tab", "camera")))
			sp.focus_first_row()
		"controls":
			ui.open_pause_menu(&"settings")
			await _frames(2)
			var sp := ui.pause_menu.get_page(&"settings") as UISettingsPanel
			sp.show_tab(&"controls")
			sp.focus_first_row()
		"confirm":
			ui.open_pause_menu(&"title")
			await _frames(2)
			ui.pause_menu.call(&"_ask_return_to_title")
		"shipyard":
			# upgrades=spare_sail,bow_cannon; look=colors:3,flag:1,figurehead:2
			for id in String(args.get("upgrades", "spare_sail")).split(",", false):
				ShipUpgrades.grant(StringName(id))
			for kv in String(args.get("look", "")).split(",", false):
				var pair := kv.split(":")
				ShipUpgrades.set_look(StringName(pair[0]), int(pair[1]))
			ui.open_shipyard()
		"debug":
			Settings.show_movement_hud = true
			ui.movement_hud.visible = true
			ui.debug_menu.open()
		"debug_world":
			Settings.show_movement_hud = true
			ui.movement_hud.visible = true
			ui.world_draw.show_vectors = true
			ui.world_draw.show_anchors = true
		_:
			push_warning("ui_preview: unknown state '%s'" % state)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Prefer the registered "UI" autoload; otherwise use the instanced copy.
func _ensure_ui() -> void:
	var existing := get_node_or_null(^"/root/UI")
	if existing is UIRoot and existing != local_ui:
		ui = existing
		local_ui.queue_free()
		return
	ui = local_ui


func _apply_pad_arg() -> void:
	match String(args.get("pad", "")):
		"xbox": InputGlyphs.set_gamepad(true, InputGlyphs.PadStyle.XBOX)
		"ps": InputGlyphs.set_gamepad(true, InputGlyphs.PadStyle.PLAYSTATION)
		"nintendo": InputGlyphs.set_gamepad(true, InputGlyphs.PadStyle.NINTENDO)


func _add_teleport_markers(parent: Node) -> void:
	var spots := {"TP Spawn": Vector3(0, 0.1, 0), "TP Hook Pit": Vector3(0, 0.1, -66),
		"TP Pool": Vector3(30, 0.1, -20), "TP Wall Kicks": Vector3(-30, 0.1, -20)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.add_to_group(&"debug_teleport")
		parent.add_child(m)
		m.global_position = spots[n]


## Plausible mid-game progress so menus have something to show.
func _seed_progress() -> void:
	GameManager.current_island = &"castaway_cay"
	for id: StringName in [&"castaway_cay", &"crabby_coast", &"lantern_lagoon"]:
		if not GameManager.is_island_discovered(id):
			GameManager.get(&"_discovered_islands").append(id)
	GameManager.play_time = 3725.0
	for i in 4:
		ParrotManager.rescue(StringName("cc_parrot_%d" % i), &"castaway_cay")
	for i in 2:
		ParrotManager.rescue(StringName("crab_parrot_%d" % i), &"crabby_coast")
	ParrotManager.register_island_total(&"castaway_cay", 5)
	ParrotManager.register_island_total(&"crabby_coast", 6)
	ParrotManager.rescue(&"lagoon_parrot_0", &"lantern_lagoon")
	for i in 9:
		InventoryManager.collect_treasure(StringName("cc_gem_%d" % i), &"gem", 25, &"castaway_cay")
	for i in 4:
		InventoryManager.collect_treasure(StringName("crab_gem_%d" % i), &"gem", 25, &"crabby_coast")
	InventoryManager.collect_treasure(&"", &"coin", 940)
	InventoryManager.add_treasure_map(&"castaway_map_1")
	InventoryManager.add_treasure_map(&"castaway_map_2")
	InventoryManager.add_treasure_map(&"driftwood_map_1")
	WorldState.mark_completed(&"castaway_x_spot")
	InventoryManager.add_ship_part(&"castaway_cay_mast")
	ui.set_island_totals(&"castaway_cay", {"treasure": 12, "maps": 2, "ship_parts": 1})
	ui.set_island_totals(&"crabby_coast", {"treasure": 20})
	for id: StringName in [&"grapple", &"shovel", &"lantern"]:
		InventoryManager.unlock_attachment(id)
	InventoryManager.equipped_attachment = &"grapple"
	Events.attachment_equipped.emit(&"grapple")
	ui.set_quests([
		{"title": "Flock Together", "description": "Rescue 6 parrots to wake the Lantern Lagoon lighthouse.", "done": false},
		{"title": "A Hook in Need", "description": "Find the blacksmith's lost anvil somewhere on Crabby Coast.", "done": false},
		{"title": "Shipwrecked!", "description": "Recover the mast from the wreck at Castaway Cay.", "done": true},
	])
	ui.hud.toasts.clear()


func _stage_hud(pad: bool) -> void:
	if pad and String(args.get("pad", "")) == "":
		InputGlyphs.set_gamepad(true, InputGlyphs.PadStyle.XBOX)
	if not pad:
		Events.island_discovered.emit(&"castaway_cay", "Castaway Cay")
	InventoryManager.collect_treasure(&"", &"coin", 25)
	ParrotManager.rescue(&"cc_parrot_9", &"castaway_cay")
	if pad:
		Events.interaction_prompt_changed.emit("{tool_primary} Dig", true)
		Events.parrot_requirement_shown.emit(6, ParrotManager.get_total(), true)
		InventoryManager.equipped_attachment = &"shovel"
		Events.attachment_equipped.emit(&"shovel")
		Events.hud_message.emit("Something glints in the sand...", 3.0)
	else:
		Events.interaction_prompt_changed.emit("{interact} Talk to Captain Gull", true)
		Events.parrot_requirement_shown.emit(10, ParrotManager.get_total(), true)
		Events.hud_message.emit("Treasure map found! Check it with {map}", 3.0)
	var p := GameManager.player
	if p != null:
		var h: Node = p.get(&"health")
		h.set(&"health", 3)
		h.emit_signal(&"health_changed", 3, 4)
	ui.show_subtitle("Squawk! Shiny! Shiny!", 4.0, "Parrot")


func _stage_dialogue() -> void:
	ui.show_dialogue("Captain Gull", [
		"Ahoy there, Patchy! That's a [b]fine hook[/b] ye've got, but it won't dig up treasure on its own.",
		"Find the shovel on Crabby Coast and come back. I'll show ye where X marks the spot!",
	])
