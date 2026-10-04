class_name OpeningSequence
extends Node3D
## The game's first minute (spec §73–74): how Patchy came to be a castaway.
##  1. Homeward bound: the Jolly Patch under full sail in the golden evening,
##     Captain Patchy at the wheel, Castaway Cay low on the horizon.
##  2. The storm: the sky goes black, rain, a heavy swell, the ship pitching
##     and rolling, lightning.
##  3. The wreck: a bolt snaps the mainmast, Patchy goes overboard, his
##     treasure slides into the sea and the Jolly Patch goes down.
##  4. Morning on Wreck Shore: Patchy lies out cold while a gang of crabs
##     carries his sea chest off inland and another drags a coin away. He
##     comes to; a third crab freezes ("!"), grabs one more coin and bolts.
##  5. Control returns at once: chase them.
## Esc (pause or back) skips straight to step 5. Plays once (WorldState
## flag); later loads go straight to gameplay. The world director (or the
## island's IslandInfo) waits for `finished` before announcing the island
## and starting its music.

signal finished

## Patchy (the world's player when left empty).
@export var player: Player
@export var crab_dragging: Crab
@export var crab_noticing: Crab
## Where the Jolly Patch sails into the storm (she heads along its -Z).
@export var sea_stage: Marker3D
## The crabs' road with Patchy's sea chest: from beside him, inland.
@export var chest_route: PackedVector3Array = PackedVector3Array()
@export var intro_flag: StringName = &"castaway_intro_seen"
@export var skip := false

const SAIL_SPEED := 5.5
const PORTER_SPEED := 3.6
const CAPTIONS := [
	"Captain Patchy, homeward bound with a hold full of treasure...",
	"...when out of nowhere, a storm!",
	"The next morning...",
]

var _done := false
var _running := false
var _skipped := false

var _cam: Camera3D
var _ui: Control
var _flash: ColorRect
var _bars: Array[ColorRect] = []
var _caption: Label
var _skip_hint: Control
var _rain: CPUParticles3D
var _wind: AudioStreamPlayer3D
var _sky_before := -1
var _swell_before := -1.0

# The sea stage: _rig travels along the heading, _rock pitches and rolls.
var _rig: Node3D
var _rock: Node3D
var _ship: PirateShip
var _wreck: PirateShip
var _captain: Node3D
var _sea_t := 0.0
var _swell := 0.15
var _sinking := false
var _shot := &""
var _shot_t := 0.0
var _shake := 0.0
var _strike_cam := Vector3.ZERO
var _debris: Array[Node3D] = []

# The crabs making off with Patchy's sea chest.
var _porters: Node3D
var _porter_legs: Array[Node3D] = []
var _porter_d := 0.0


func _ready() -> void:
	add_to_group(&"opening_sequence")
	set_process(false)
	if not is_pending():
		_done = true
		# Seen it already: the thieves are just cove crabs now, scuttling
		# around their burrow instead of waiting at Patchy's spawn.
		var k := 0
		for c: Crab in [crab_dragging, crab_noticing]:
			if c == null:
				continue
			c.dormant = false
			if c.burrow != null:
				var spot := c.burrow.global_position + Vector3(-2.5 + k * 5.0, 0.1, -2.0)
				c.global_position = spot
				c.home = spot
			k += 1
		return
	# Hold Patchy down before the first rendered frame (once the world has
	# him: he's the world's, not the island's).
	_hold_player.call_deferred()
	await get_tree().process_frame
	await get_tree().process_frame
	if player == null:
		player = GameManager.player as Player
	if player == null:
		_begin_play(false)
		return
	_run()


func _hold_player() -> void:
	if player == null:
		player = GameManager.player as Player
	if player != null:
		player.set_locked(true, {"anim": &"knocked_out"})


func is_pending() -> bool:
	return not _done and not skip and not WorldState.is_completed(intro_flag)


func is_running() -> bool:
	return _running


func _input(event: InputEvent) -> void:
	if not _running or _skipped or event.is_echo():
		return
	if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip_intro()


## Jumps to the end: Patchy awake on the beach, the thieves running off.
func skip_intro() -> void:
	if not _running or _skipped:
		return
	_skipped = true
	_skip_to_end()


## Waits `t` seconds of the intro; false once it has been skipped.
func _hold(t: float) -> bool:
	await get_tree().create_timer(t, false).timeout
	return not _skipped


# --- The sequence ------------------------------------------------------------------

func _run() -> void:
	_running = true
	player.set_locked(true, {"anim": &"knocked_out"})
	_hud_hidden(true)
	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 3000.0
	add_child(_cam)
	_build_overlay()
	await SceneTransition.fade_out(0.01)
	if _skipped:
		return

	# 1. Homeward bound in the golden evening.
	if sea_stage != null:
		_build_sea()
		_weather(&"evening")
		_cam.make_current()
		_set_shot(&"sail")
		set_process(true)
		_letterbox(true)
		await SceneTransition.fade_in(1.0)
		if _skipped:
			return
		_say(CAPTIONS[0], 3.4)
		_hint_skip()
		if not await _hold(3.6):
			return

		# 2. The storm hits.
		_lightning()
		_weather(&"storm")
		_set_shot(&"storm")
		create_tween().tween_property(self, "_swell", 1.0, 1.6).set_trans(Tween.TRANS_SINE)
		for s: PirateShip in [_ship, _wreck]:
			s.billow(1.5)
		_say(CAPTIONS[1], 2.6)
		if not await _hold(1.6):
			return
		_lightning(_rig.global_position + _rig.global_basis * Vector3(-30, 0, -40))
		if not await _hold(1.5):
			return
		_lightning(_rig.global_position + _rig.global_basis * Vector3(26, 0, -55))
		if not await _hold(1.1):
			return

		# 3. Struck: the mast snaps, Patchy and his gold go overboard, she sinks.
		_set_shot(&"wreck")
		if not await _hold(0.45):
			return
		_strike()
		if not await _hold(4.6):
			return
		await SceneTransition.fade_out(0.8)
		if _skipped:
			return
		_clear_sea()
		_weather(&"clear")
		_say(CAPTIONS[2], 1.8)
		if not await _hold(1.6):
			return
	else:
		_letterbox(true)
		_hint_skip()

	# 4. Morning on the beach: out cold, his sea chest carried off.
	_set_shot(&"")
	set_process(true)
	var w := player.global_position
	_cam.global_position = w + Vector3(-4.6, 1.5, 4.2)
	_cam.look_at(w + Vector3(3.5, 0.5, -5.0))
	_cam.make_current()
	_start_porters()
	var loot := _coin_near(crab_dragging)
	if crab_dragging != null and loot != null:
		crab_dragging.start_with_loot(loot)
	AudioManager.play(&"seagull", null, -6.0)
	await SceneTransition.fade_in(0.8)
	if not await _hold(1.6):
		return

	# He comes to...
	player.set_locked(true, {"anim": &"wake_up"})
	AudioManager.play(&"hurt", player.global_position, -10.0, 0.8)
	if not await _hold(1.25):
		return
	var pull := _cam.create_tween()
	pull.tween_property(_cam, "global_position", w + Vector3(-6.0, 3.2, 6.5), 0.9).set_trans(Tween.TRANS_SINE)
	if not await _hold(0.9):
		return

	# ...just in time to see a crab grab one more coin and run.
	var extra := _coin_near(crab_noticing)
	if crab_noticing != null and extra != null:
		crab_noticing.notice_then_grab(extra)
	player.set_locked(true, {"anim": &"skid"})
	if not await _hold(1.0):
		return

	# 5. Go!
	_letterbox(false)
	_begin_play(true)


func _skip_to_end() -> void:
	await SceneTransition.fade_out(0.25)
	_clear_sea()
	_weather(&"clear")
	_say("", 0.0)
	if _porters != null:
		_porters.queue_free()
		_porters = null
	set_process(false)
	# The thieves are already off with Patchy's coins.
	for c: Crab in [crab_dragging, crab_noticing]:
		if c != null and c.dormant:
			var coin := _coin_near(c)
			if c == crab_dragging:
				c.start_with_loot(coin)
			else:
				c.notice_then_grab(coin)
	_letterbox(false, true)
	_begin_play(true)
	await SceneTransition.fade_in(0.4)


func _begin_play(first_time: bool) -> void:
	_running = false
	if player != null:
		var rig := player.camera_rig as CameraRig
		if rig != null:
			rig.get_camera().make_current()
			rig.snap_behind_target()
		if player.state_id == &"locked":
			player.set_locked(false)
	if _cam != null:
		_cam.queue_free()
		_cam = null
	if _ui != null:
		# Let the cinema bars slide away first.
		var layer := _ui.get_parent()
		_ui = null
		get_tree().create_timer(0.8, false).timeout.connect(layer.queue_free)
	_hud_hidden(false)
	WorldState.mark_completed(intro_flag)
	_done = true
	finished.emit()
	if first_time:
		AudioManager.play_stinger(&"stinger_discovery")


func _hud_hidden(on: bool) -> void:
	var ui := get_node_or_null(^"/root/UI")
	if ui != null and ui.has_method(&"set_hud_hidden"):
		ui.call(&"set_hud_hidden", on)


func _coin_near(crab: Crab) -> Collectible:
	if crab == null:
		return null
	var c := Collectible.new()
	c.kind = "coin"
	c.add_to_group(&"loose_treasure")
	get_tree().current_scene.add_child(c)
	c.global_position = crab.global_position + Vector3(0.6, 0.4, -0.4)
	return c


# --- Every frame: the ship at sea, the cameras, the porters -----------------------

func _process(delta: float) -> void:
	if _rig != null:
		_sea_t += delta
		if not _sinking:
			_rig.global_position += -_rig.global_basis.z * SAIL_SPEED * delta
			var pitch := sin(_sea_t * 1.35) * lerpf(0.025, 0.15, _swell)
			var roll := sin(_sea_t * 0.92 + 1.3) * lerpf(0.035, 0.19, _swell)
			_rock.rotation = Vector3(pitch, 0.0, roll)
			_rock.position.y = sin(_sea_t * 1.1) * lerpf(0.12, 1.0, _swell)
		_update_camera(delta)
	if _porters != null:
		_move_porters(delta)


func _set_shot(shot: StringName) -> void:
	_shot = shot
	_shot_t = 0.0
	if shot == &"wreck" and _rig != null:
		# A wide, fixed view off the ship's port bow for the strike and the sinking.
		_strike_cam = _rig.global_position + _rig.global_basis * Vector3(-20.0, 6.0, -10.0)


func _update_camera(delta: float) -> void:
	if _cam == null or _rig == null:
		return
	_shot_t += delta
	var b := _rig.global_basis
	var at := _rig.global_position
	match _shot:
		&"sail":
			# Alongside to starboard, drifting aft as she sails past.
			var t := clampf(_shot_t / 4.6, 0.0, 1.0)
			_cam.global_position = at + b * Vector3(15.0, 4.6, -15.0).lerp(Vector3(13.0, 3.4, 4.0), t)
			_cam.look_at(at + b * Vector3(0, 5.5, -1.0))
		&"storm":
			# Low off the port quarter, in the spray.
			_shake = 0.18
			_cam.global_position = at + b * Vector3(-11.5, 2.2, 14.0) + _shake_offset()
			_cam.look_at(at + b * Vector3(0, 6.0, -3.0) + Vector3.UP * _rock.position.y * 0.6)
		&"wreck":
			_shake = maxf(_shake - delta * 0.6, 0.05)
			_cam.global_position = _strike_cam + _shake_offset()
			# Follow her down only as far as the waterline: the masts going
			# under, the flotsam left behind.
			var r := _rock.global_position
			_cam.look_at(Vector3(r.x, maxf(r.y + 3.5, 0.8), r.z))


func _shake_offset() -> Vector3:
	return Vector3(sin(_sea_t * 23.0), sin(_sea_t * 31.0 + 1.0), sin(_sea_t * 19.0 + 2.0)) * _shake


# --- The sea stage -------------------------------------------------------------------

func _build_sea() -> void:
	_rig = Node3D.new()
	_rig.name = "SeaStage"
	add_child(_rig)
	_rig.global_transform = Transform3D(Basis(Vector3.UP, sea_stage.global_rotation.y), Vector3(sea_stage.global_position.x, 0.0, sea_stage.global_position.z))
	_rock = Node3D.new()
	_rig.add_child(_rock)
	_ship = PirateShip.new()
	_rock.add_child(_ship)
	# The same ship after the strike (built now so the swap doesn't hitch).
	_wreck = PirateShip.new()
	_wreck.damaged = true
	_wreck.visible = false
	_rock.add_child(_wreck)
	# Captain Patchy at the wheel.
	var helm_z := PirateShip.WHEEL_Z + 0.95
	var captain := PatchyModel.new()
	captain.position = Vector3(0.0, PirateShip.deck_at(helm_z), helm_z)
	_rock.add_child(captain)
	_captain = captain
	var wind := Node3D.new()
	_rig.add_child(wind)
	_wind = AudioManager.create_loop(&"wind_loop", wind, -6.0)
	if _wind != null and _wind.stream != null:
		_wind.play()


func _strike() -> void:
	# Every tween here is bound to the stage, so a skip (which frees it)
	# stops them all.
	var mast_top := _rock.global_transform * Vector3(0, PirateShip.BREAK_Y + 6.0, PirateShip.MAIN_Z)
	_lightning(mast_top)
	_shake = 0.45
	AudioManager.play(&"wood_creak", null, -2.0, 0.7)
	_ship.visible = false
	_wreck.visible = true
	var top := _wreck.main_mast_top
	if top != null:
		var snap := _rig.create_tween()
		snap.tween_property(top, "rotation:z", deg_to_rad(-74.0), 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Patchy is thrown clear...
	var fling := _rig.create_tween()
	fling.tween_interval(0.3)
	fling.tween_property(_captain, "position", _captain.position + Vector3(3.5, 4.0, 1.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	fling.parallel().tween_property(_captain, "rotation", Vector3(-1.2, 2.4, 0.8), 0.9)
	fling.tween_property(_captain, "position", _captain.position + Vector3(8.5, -3.5, 2.0), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fling.tween_callback(func() -> void:
		_splash(_captain.global_position + Vector3.UP * 1.5, 1.3)
		_captain.visible = false)
	# ...and his treasure slides off the deck after him.
	var gold := _wreck.treasure
	if gold != null:
		var slide := _rig.create_tween()
		slide.tween_interval(0.7)
		slide.tween_property(gold, "position", gold.position + Vector3(4.6, -1.6, 0.6), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		slide.parallel().tween_property(gold, "rotation:z", -0.9, 1.0)
		slide.tween_callback(func() -> void: _splash(gold.global_position, 1.0))
		slide.tween_property(gold, "position:y", gold.position.y - 6.0, 1.2)
	# Then she goes down by the bow.
	var sink := _rig.create_tween()
	sink.tween_interval(1.3)
	sink.tween_callback(func() -> void:
		_sinking = true
		AudioManager.play(&"splash_big", null, -4.0, 0.6))
	sink.tween_property(_rock, "rotation", Vector3(-0.5, 0.12, 0.34), 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	sink.parallel().tween_property(_rock, "position:y", -22.0, 3.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for k in 4:
		var bubble := _rig.create_tween()
		bubble.tween_interval(1.6 + k * 0.7)
		bubble.tween_callback(func() -> void:
			_splash(_rig.global_position + _rig.global_basis * Vector3(randf_range(-2.5, 2.5), 0.0, -5.0 + k * 3.5), 1.4))
	var flotsam := _rig.create_tween()
	flotsam.tween_interval(3.0)
	flotsam.tween_callback(_spawn_debris.bind(_rig.global_position))
	var bolt := _rig.create_tween()
	bolt.tween_interval(2.6)
	bolt.tween_callback(func() -> void: _lightning(_rig.global_position + _rig.global_basis * Vector3(40, 0, 30)))


func _splash(at: Vector3, size: float) -> void:
	VFX.splash(get_tree().current_scene, Vector3(at.x, 0.2, at.z), size)


func _clear_sea() -> void:
	if _rig != null:
		_rig.queue_free()
	_rig = null
	_rock = null
	_ship = null
	_wreck = null
	_captain = null
	_wind = null
	for d in _debris:
		if is_instance_valid(d):
			d.queue_free()
	_debris.clear()


## Flotsam left where she went down: planks bobbing, coins sinking.
func _spawn_debris(center: Vector3) -> void:
	if _rig == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 10:
		var b := LevelBlock.new()
		b.size = Vector3(rng.randf_range(1.5, 3.5), 0.25, rng.randf_range(0.4, 0.7))
		b.surface = "wood"
		b.bevel = 0.05
		b.collision_layer = 0
		add_child(b)
		b.global_position = center + Vector3(rng.randf_range(-8, 8), -0.1, rng.randf_range(-7, 7))
		b.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		_debris.append(b)
		var bob := b.create_tween().set_loops()
		bob.tween_property(b, "position:y", b.position.y + 0.3, 1.0 + rng.randf()).set_trans(Tween.TRANS_SINE)
		bob.tween_property(b, "position:y", b.position.y - 0.1, 1.0 + rng.randf()).set_trans(Tween.TRANS_SINE)


# --- Weather, lightning, overlay --------------------------------------------------

## The evening before, the squall that wrecked the ship, the morning after.
func _weather(mode: StringName) -> void:
	var sky := _find(get_tree().current_scene, "SkyEnvironment") as SkyEnvironment
	var ocean := _find(get_tree().current_scene, "Ocean") as Ocean
	if sky != null and _sky_before < 0:
		_sky_before = sky.preset
	if ocean != null and _swell_before < 0.0:
		_swell_before = ocean.amplitude_scale
	match mode:
		&"evening":
			if sky != null:
				sky.preset = SkyEnvironment.Preset.GOLDEN_HOUR
		&"storm":
			if sky != null:
				sky.preset = SkyEnvironment.Preset.STORM
			if ocean != null:
				ocean.amplitude_scale = 2.6
			_start_rain()
		&"clear":
			if sky != null and _sky_before >= 0:
				sky.preset = _sky_before as SkyEnvironment.Preset
			if ocean != null and _swell_before >= 0.0:
				ocean.amplitude_scale = _swell_before
			if _rain != null:
				_rain.queue_free()
				_rain = null


func _start_rain() -> void:
	if _rain != null or _cam == null:
		return
	_rain = CPUParticles3D.new()
	var drop := BoxMesh.new()
	drop.size = Vector3(0.025, 0.7, 0.025)
	_rain.mesh = drop
	_rain.material_override = MaterialLibrary.unshaded(Color(0.75, 0.82, 0.95, 0.45))
	_rain.amount = 900
	_rain.lifetime = 0.9
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(24, 1, 24)
	_rain.direction = Vector3(0.35, -1, 0.1)
	_rain.spread = 3.0
	_rain.gravity = Vector3.ZERO
	_rain.initial_velocity_min = 26.0
	_rain.initial_velocity_max = 30.0
	_rain.particle_flag_align_y = true
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cam.add_child(_rain)
	_rain.position = Vector3(0, 9, -10)


static func _find(root: Node, type_name: String) -> Node:
	if root == null:
		return null
	var found := root.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null


## A flash of lightning and a thunderclap; with `strike_at`, a bolt comes
## down there.
func _lightning(strike_at: Variant = null) -> void:
	var peak := 0.35 if Settings.reduce_flashing else 0.85
	AudioManager.play(&"explosion", null, -8.0, 0.55)
	if _flash != null:
		var tw := _flash.create_tween()
		tw.tween_property(_flash, "color:a", peak, 0.05)
		tw.tween_property(_flash, "color:a", 0.0, 0.55)
	if strike_at is Vector3:
		_bolt(strike_at)


func _bolt(to: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var mb := MeshBuilder.new()
	var from := to + Vector3(rng.randf_range(-12, 12), 70.0, rng.randf_range(-12, 12))
	var pts := PackedVector3Array()
	var radii := PackedFloat32Array()
	for k in 10:
		var t := k / 9.0
		var jitter := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * 4.0 * sin(t * PI)
		pts.append(from.lerp(to, t) + jitter)
		radii.append(lerpf(0.5, 0.18, t))
	mb.tube(pts, radii, Color.WHITE, 5, false)
	var fork := pts[4]
	mb.tube(PackedVector3Array([fork, fork + Vector3(rng.randf_range(-7, 7), -9, rng.randf_range(-7, 7)), fork + Vector3(rng.randf_range(-10, 10), -18, rng.randf_range(-10, 10))]),
		PackedFloat32Array([0.25, 0.15, 0.08]), Color.WHITE, 4, false)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.unshaded(Color(0.88, 0.93, 1.0)))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func() -> void: mi.visible = false)
	tw.tween_interval(0.06)
	tw.tween_callback(func() -> void: mi.visible = true)
	tw.tween_interval(0.1)
	tw.tween_callback(mi.queue_free)


func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = UIStyle.get_theme()
	layer.add_child(_ui)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color(0.02, 0.02, 0.04)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.anchor_left = 0.0
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = -1.0 if top else 1.0
		bar.offset_bottom = -1.0 if top else 1.0
		_ui.add_child(bar)
		_bars.append(bar)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.anchor_left = 0.0
	_caption.anchor_right = 1.0
	_caption.anchor_top = 0.885
	_caption.anchor_bottom = 1.0
	_caption.add_theme_font_override(&"font", UIStyle.font(&"body"))
	_caption.add_theme_font_size_override(&"font_size", 34)
	_caption.add_theme_color_override(&"font_color", Color("f6ecd6"))
	_caption.modulate.a = 0.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_caption)
	var hint := UIPromptRow.new()
	hint.prompt = "{pause} Skip"
	hint.font_size = 24
	hint.glyph_height = 34.0
	hint.anchor_left = 1.0
	hint.anchor_right = 1.0
	hint.offset_left = -220.0
	hint.offset_right = -28.0
	hint.offset_top = 16.0
	hint.offset_bottom = 60.0
	hint.alignment = BoxContainer.ALIGNMENT_END
	hint.modulate.a = 0.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(hint)
	_skip_hint = hint
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_flash)


## Cinema bars in (or out).
func _letterbox(on: bool, instant := false) -> void:
	if _ui == null:
		return
	var h := 0.115 * _ui.get_viewport_rect().size.y
	for k in _bars.size():
		var bar := _bars[k]
		var top := k == 0
		var to_top := 0.0 if top else (-h if on else 0.0)
		var to_bottom := (h if on else 0.0) if top else 0.0
		if instant:
			bar.offset_top = to_top
			bar.offset_bottom = to_bottom
			continue
		var tw := bar.create_tween().set_parallel()
		tw.tween_property(bar, "offset_top", to_top, 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(bar, "offset_bottom", to_bottom, 0.6).set_trans(Tween.TRANS_SINE)


## A line of narration in the bottom bar for `time` seconds ("" clears it).
func _say(text: String, time: float) -> void:
	if _caption == null:
		return
	if text == "":
		_caption.modulate.a = 0.0
		return
	_caption.text = text
	var tw := _caption.create_tween()
	tw.tween_property(_caption, "modulate:a", 1.0, 0.4)
	tw.tween_interval(maxf(time - 0.8, 0.2))
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)


func _hint_skip() -> void:
	if _skip_hint != null:
		_skip_hint.create_tween().tween_property(_skip_hint, "modulate:a", 0.85, 0.5)


# --- The chest's porters ------------------------------------------------------------

func _start_porters() -> void:
	if chest_route.size() < 2:
		return
	_porters = Node3D.new()
	_porters.name = "ChestPorters"
	add_child(_porters)
	_porters.global_position = chest_route[0]
	var chest := TreasureChestModel.new()
	chest.position = Vector3(0, 0.62, 0)
	chest.rotation.y = PI * 0.5
	_porters.add_child(chest)
	for k in 4:
		var crab := CrabModel.new()
		crab.position = Vector3(-0.42 if k % 2 == 0 else 0.42, 0.0, -0.32 if k < 2 else 0.32)
		# Crabs scuttle sideways.
		crab.rotation.y = PI * 0.5 if k % 2 == 0 else -PI * 0.5
		crab.scale = Vector3.ONE * 0.85
		_porters.add_child(crab)
		_porter_legs.append_array(crab.legs)
		for claw: Node3D in [crab.claw_l, crab.claw_r]:
			if claw != null:
				claw.rotation.x = -0.9
	_porter_d = 0.0


func _move_porters(delta: float) -> void:
	_porter_d += PORTER_SPEED * delta
	var left := _porter_d
	for i in chest_route.size() - 1:
		var a := chest_route[i]
		var b := chest_route[i + 1]
		var seg := a.distance_to(b)
		if left <= seg:
			var p := a.lerp(b, left / seg)
			_porters.global_position = p + Vector3.UP * absf(sin(_porter_d * 4.0)) * 0.05
			var flat := Vector3(b.x - a.x, 0, b.z - a.z)
			if flat.length() > 0.01:
				_porters.rotation.y = lerp_angle(_porters.rotation.y, Player.yaw_of(flat), minf(delta * 6.0, 1.0))
			for k in _porter_legs.size():
				var leg := _porter_legs[k]
				if is_instance_valid(leg):
					leg.rotation.x = sin(_porter_d * 9.0 + k * 1.7) * 0.5
			if randf() < delta * 3.0:
				AudioManager.play(&"crab_step", _porters.global_position, -14.0, randf_range(0.9, 1.2))
			return
		left -= seg
	# Over the rise and away: gone, chest and all.
	VFX.dust(get_tree().current_scene, _porters.global_position + Vector3.UP * 0.4, 8, 0.4)
	_porters.queue_free()
	_porters = null
	_porter_legs.clear()
