class_name UIShipyard
extends Control
## Gus's shipyard (ShipUpgrades): Patchy's boat turning in a window on the
## left, and on the right what Gus can do to her for gold (a faster sail,
## a tougher hull, a bow cannon) and the looks, free to change: the sail's
## colors, a flag and a figurehead. Pointing at an upgrade tries it on the
## boat in the window. Opened by talking to Gus once the old dinghy is
## Patchy's (UIRoot.open_shipyard, awaitable); the game pauses while it's
## up. Done, Back or ui_cancel closes it.

signal closed

## The upgrades on Gus's list, in order (Betty's spare sail is Shellby's).
const FOR_SALE: Array[StringName] = [&"racing_rig", &"copper_hull", &"iron_hull", &"bow_cannon"]
const LOOK_SLOTS: Array[StringName] = [&"colors", &"flag", &"figurehead"]
const LOOK_NAMES := {&"colors": "Sail colors", &"flag": "Flag", &"figurehead": "Figurehead"}
const SAIL_NAMES: Array[String] = ["Gus's Patched Sail", "Betty's Spare Sail", "Racing Rig"]
const HULL_NAMES: Array[String] = ["Old Planks", "Copper Bottom", "Iron Hull"]

var is_open := false
var _panel: PanelContainer
var _gold: Label
var _view: SubViewport
var _turntable: Node3D
var _boat: Node3D
var _caption: Label
var _stats: Label
## id -> Button
var _buy := {}
## slot -> Button
var _looks := {}
var _done: Button
var _try: StringName = &""
var _shown := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.12, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme_type_variation = &"ParchmentPanel"
	_panel.custom_minimum_size = Vector2(1500, 0)
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	_panel.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 14)
	col.add_child(head)
	head.add_child(UIIconView.make(&"ship_wheel", 52))
	var title := Label.new()
	title.theme_type_variation = &"HeaderLabel"
	title.text = "Gus's Shipyard"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var gold := UIPage.make_stat(&"coin", "0", 44.0)
	head.add_child(gold)
	_gold = gold.get_child(1) as Label
	col.add_child(UIPage.make_divider())
	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 26)
	col.add_child(body)
	body.add_child(_make_window())
	body.add_child(_make_lists())
	UIFx.prepare(_panel)


## The boat on the water in a little window, turning slowly.
func _make_window() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"WoodPanel"
	box.add_child(frame)
	var vpc := SubViewportContainer.new()
	vpc.stretch = true
	vpc.custom_minimum_size = Vector2(600, 400)
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(vpc)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	vpc.add_child(_view)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("9fdcf2")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 0.92)
	e.ambient_light_energy = 0.55
	e.fog_enabled = true
	e.fog_light_color = Color("bfe8f6")
	e.fog_density = 0.02
	env.environment = e
	_view.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 0.95
	_view.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 38.0
	_view.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.4, 7.4), Vector3(0, 1.6, 0))
	var sea := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 30.0
	disc.bottom_radius = 30.0
	disc.height = 0.1
	disc.radial_segments = 48
	sea.mesh = disc
	sea.position = Vector3(0, -0.12, 0)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color("3aa6cf")
	water.roughness = 0.35
	sea.material_override = water
	_view.add_child(sea)
	_turntable = Node3D.new()
	_view.add_child(_turntable)
	_caption = Label.new()
	_caption.theme_type_variation = &"SubheaderLabel"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_caption)
	_stats = Label.new()
	_stats.theme_type_variation = &"SmallLabel"
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_stats)
	box.add_child(_section("Her looks", &"flag"))
	for slot in LOOK_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 14)
		box.add_child(row)
		var l := Label.new()
		l.text = LOOK_NAMES[slot]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var pick := Button.new()
		pick.custom_minimum_size = Vector2(380, 54)
		pick.pressed.connect(_cycle.bind(slot, 1))
		pick.gui_input.connect(_on_look_input.bind(slot))
		row.add_child(pick)
		_looks[slot] = pick
	return box


func _make_lists() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_section("Work on her", &"anchor"))
	for id in FOR_SALE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 14)
		col.add_child(row)
		var words := VBoxContainer.new()
		words.add_theme_constant_override(&"separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(words)
		var name_label := Label.new()
		name_label.theme_type_variation = &"SubheaderLabel"
		name_label.text = ShipUpgrades.display_name(id)
		words.add_child(name_label)
		var blurb := Label.new()
		blurb.theme_type_variation = &"SmallLabel"
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		blurb.custom_minimum_size = Vector2(420, 0)
		blurb.set_meta(&"text", String(ShipUpgrades.UPGRADES[id].blurb))
		words.add_child(blurb)
		var buy := Button.new()
		buy.custom_minimum_size = Vector2(250, 62)
		buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		buy.pressed.connect(_on_buy.bind(id))
		buy.focus_entered.connect(_try_on.bind(id))
		buy.mouse_entered.connect(_try_on.bind(id))
		buy.focus_exited.connect(_try_on.bind(&""))
		buy.set_meta(&"blurb", blurb)
		row.add_child(buy)
		_buy[id] = buy
	var foot := HBoxContainer.new()
	foot.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(foot)
	_done = Button.new()
	_done.text = "Done"
	_done.custom_minimum_size = Vector2(250, 64)
	_done.pressed.connect(close)
	foot.add_child(_done)
	return col


func _section(text: String, icon: StringName) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	h.add_child(UIIconView.make(icon, 34))
	var l := Label.new()
	l.theme_type_variation = &"SubheaderLabel"
	l.text = text
	h.add_child(l)
	return h


# --- Open / close ---------------------------------------------------------------------

## Shows the shipyard and returns once Patchy's done (awaitable).
func open() -> void:
	if is_open:
		await closed
		return
	is_open = true
	_try = &""
	_refresh()
	visible = true
	modulate.a = 0.0
	UIFx.fade(self, 1.0, 0.15)
	_panel.offset_transform_scale = Vector2(0.92, 0.92)
	var tw := _panel.create_tween()
	tw.tween_property(_panel, "offset_transform_scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	get_tree().paused = true
	UIFx.sound(&"ui_pause")
	(_buy[FOR_SALE[0]] as Button).grab_focus()
	await closed


func close() -> void:
	if not is_open:
		return
	is_open = false
	UIFx.sound(&"ui_back")
	UIFx.fade(self, 0.0, 0.12)
	get_tree().paused = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if is_open and _turntable != null:
		_turntable.rotation.y += delta * 0.45
		if _boat != null:
			var t := Time.get_ticks_msec() * 0.001
			_boat.position.y = sin(t * 1.7) * 0.05
			_boat.rotation = Vector3(sin(t * 1.3) * 0.025, 0, sin(t * 1.1) * 0.04)


# --- Buying and looks -----------------------------------------------------------------

func _on_buy(id: StringName) -> void:
	var b := _buy[id] as Button
	if not ShipUpgrades.buy(id):
		UIFx.sound(&"ui_back")
		UIFx.shake(b, 8.0, 0.3)
		return
	UIFx.sound(&"treasure_big")
	UIFx.sound(&"wood_creak", -4.0)
	UIFx.pop(b)
	_try = &""
	_refresh()
	var ui := UIRoot.instance
	if ui != null:
		ui.show_toast("Gus fits the %s!" % ShipUpgrades.display_name(id), 2.4, &"ship_wheel")


func _cycle(slot: StringName, step: int) -> void:
	var now := _look_index(slot)
	ShipUpgrades.set_look(slot, now + step)
	UIFx.sound(&"ui_move")
	UIFx.pop(_looks[slot] as Control, 0.12, 0.2)
	_refresh()


func _on_look_input(event: InputEvent, slot: StringName) -> void:
	if event.is_action_pressed(&"ui_left"):
		_cycle(slot, -1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		_cycle(slot, 1)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT:
		_cycle(slot, -1)
		accept_event()


## The look in use for `slot` (the sail's own colors resolved).
func _look_index(slot: StringName) -> int:
	if slot == &"colors":
		return ShipUpgrades.sail_colors(ShipUpgrades.sail_level(), ShipUpgrades.look(&"colors"))
	return ShipUpgrades.look(slot)


func _try_on(id: StringName) -> void:
	if not is_open:
		return
	_try = id if id != &"" and not ShipUpgrades.has(id) else &""
	_show_boat()


# --- Drawing ------------------------------------------------------------------------------

func _refresh() -> void:
	_gold.text = str(InventoryManager.gold_value)
	for id: StringName in FOR_SALE:
		var b := _buy[id] as Button
		var why := ShipUpgrades.why_not(id)
		if why == "":
			b.text = "Buy   %d gold" % ShipUpgrades.price(id)
		else:
			b.text = why
		b.disabled = why != ""
		var blurb := b.get_meta(&"blurb") as Label
		blurb.text = String(blurb.get_meta(&"text")).replace("{tool_primary}", InputGlyphs.action_text(&"tool_primary"))
	for slot: StringName in LOOK_SLOTS:
		(_looks[slot] as Button).text = "<   %s   >" % ShipUpgrades.look_name(slot, _look_index(slot))
	_show_boat()


## The boat as she is, or with the upgrade being pointed at tried on.
func _spec() -> Dictionary:
	var spec := ShipUpgrades.spec()
	if _try != &"":
		var u: Dictionary = ShipUpgrades.UPGRADES[_try]
		match StringName(u.track):
			&"sail":
				spec.sail = maxi(spec.sail, int(u.level))
				if ShipUpgrades.look(&"colors") < 0:
					spec.colors = ShipUpgrades.sail_colors(spec.sail, -1)
			&"hull":
				spec.hull = maxi(spec.hull, int(u.level))
			&"cannon":
				spec.cannon = true
	return spec


func _show_boat() -> void:
	var spec := _spec()
	if spec != _shown or _boat == null:
		_shown = spec
		if _boat != null:
			_boat.free()
		_boat = BoatModel.make(spec)
		_turntable.add_child(_boat)
	_caption.text = ("Trying on: %s" % ShipUpgrades.display_name(_try)) if _try != &"" else "Patchy's boat"
	_stats.text = "Sail: %s     Hull: %s     Cannon: %s" % [SAIL_NAMES[spec.sail], HULL_NAMES[spec.hull], "Bow Cannon" if spec.cannon else "none"]


## The boat in the window (tests).
func shown_spec() -> Dictionary:
	return _shown
