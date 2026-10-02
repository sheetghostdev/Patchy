extends Node
## Pooled sound playback driven by audio/audio_manifest.json.
## Missing sounds never crash the game: they warn once and are skipped, so
## gameplay code can call play() freely before assets exist.

const MANIFEST_PATH := "res://audio/audio_manifest.json"
const POOL_3D := 28
const POOL_2D := 10
## Seconds the combat layer stays up after the last threat report.
const THREAT_HOLD := 4.0

var _sfx: Dictionary = {}       # name -> {stream, bus, volume_db, loop}
var _groups: Dictionary = {}    # name -> Array[name]
var _music_defs: Dictionary = {}
var _warned: Dictionary = {}
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d := 0
var _next_2d := 0

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_name: StringName = &""
var _music_layers: Array[StringName] = []
var _music_tween: Tween
var _layer_tweens: Dictionary = {}   # layer -> Tween
var _threat_t := 0.0
var _combat_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	_load_manifest()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.panning_strength = 0.8
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool_2d.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for m in [_music_a, _music_b]:
		m.bus = &"Music"
		add_child(m)
	_music_current = _music_a


func _process(delta: float) -> void:
	if not get_tree().paused:
		_threat_t = maxf(_threat_t - delta, 0.0)
	var want := _threat_t > 0.0
	if want != _combat_on:
		_combat_on = want
		for layer in _music_layers:
			if String(layer).contains("combat"):
				set_music_layer(layer, want, 0.6 if want else 2.5)


func _ensure_buses() -> void:
	# The bus layout normally comes from default_bus_layout.tres; this keeps
	# the game working if that file is missing.
	for bus_name in [&"Music", &"SFX", &"UI", &"Ambience"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")


func _load_manifest() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_warning("AudioManager: no manifest at %s; audio disabled" % MANIFEST_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if not parsed is Dictionary:
		push_warning("AudioManager: manifest unreadable")
		return
	var sfx: Dictionary = parsed.get("sfx", {})
	for n in sfx:
		var d: Dictionary = sfx[n]
		_sfx[StringName(n)] = {
			"file": String(d.get("file", "")),
			"stream": null,
			"bus": StringName(d.get("bus", "SFX")),
			"volume_db": float(d.get("volume_db", 0.0)),
			"loop": bool(d.get("loop", false)),
		}
	var groups: Dictionary = parsed.get("groups", {})
	for g in groups:
		var members: Array[StringName] = []
		for m in groups[g]:
			members.append(StringName(m))
		_groups[StringName(g)] = members
	_music_defs = parsed.get("music", {})


func has_sound(sound: StringName) -> bool:
	return _sfx.has(sound) or _groups.has(sound)


func _resolve(sound: StringName) -> Dictionary:
	var key := sound
	if _groups.has(sound):
		var members: Array = _groups[sound]
		key = members[randi() % members.size()]
	if not _sfx.has(key):
		if not _warned.has(sound):
			_warned[sound] = true
			push_warning("AudioManager: unknown sound '%s'" % sound)
		return {}
	var d: Dictionary = _sfx[key]
	if d.stream == null and d.file != "":
		if ResourceLoader.exists(d.file):
			d.stream = load(d.file)
			if d.loop:
				_set_stream_loop(d.stream)
		else:
			d.file = ""
	return d if d.stream != null else {}


func _set_stream_loop(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var w := stream as AudioStreamWAV
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		var frames := w.data.size() / (2 * (2 if w.stereo else 1))
		w.loop_end = frames
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true


## Play a one-shot. Pass a Vector3 for positional audio, or null for 2D.
func play(sound: StringName, at: Variant = null, volume_db: float = 0.0, pitch: float = 1.0, pitch_jitter: float = 0.06) -> void:
	var d := _resolve(sound)
	if d.is_empty():
		return
	var final_pitch := pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
	if at is Vector3:
		var p := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _pool_3d.size()
		p.stream = d.stream
		p.bus = d.bus
		p.volume_db = d.volume_db + volume_db
		p.pitch_scale = final_pitch
		p.global_position = at
		p.play()
	else:
		var p := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % _pool_2d.size()
		p.stream = d.stream
		p.bus = d.bus
		p.volume_db = d.volume_db + volume_db
		p.pitch_scale = final_pitch
		p.play()


func play_ui(sound: StringName, volume_db: float = 0.0) -> void:
	play(sound, null, volume_db, 1.0, 0.0)


## Creates a looping positional player parented to `owner_node`.
## The caller owns it (queue_free or stop() when done).
func create_loop(sound: StringName, owner_node: Node3D, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var d := _resolve(sound)
	var p := AudioStreamPlayer3D.new()
	p.unit_size = 5.0
	p.max_distance = 40.0
	if not d.is_empty():
		p.stream = d.stream
		p.bus = d.bus
		p.volume_db = d.volume_db + volume_db
	owner_node.add_child(p)
	return p


# --- Music ------------------------------------------------------------------

## Plays a music track, cross-fading from the current one. Tracks that other
## tracks declare `layer_of` are combined into an AudioStreamSynchronized so
## layers stay sample-aligned and can be faded independently (spec §123).
func play_music(track: StringName, fade: float = 1.5) -> void:
	if track == _music_name:
		return
	if not _music_defs.has(String(track)):
		if not _warned.has(track):
			_warned[track] = true
			push_warning("AudioManager: unknown music '%s'" % track)
		return
	var stream := _build_music_stream(track)
	if stream == null:
		return
	var incoming := _music_b if _music_current == _music_a else _music_a
	var outgoing := _music_current
	incoming.stream = stream
	incoming.volume_db = -40.0
	incoming.play()
	_music_current = incoming
	_music_name = track
	_combat_on = false          # a new track's layers start silent
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, fade).set_trans(Tween.TRANS_SINE)
	if outgoing.playing:
		_music_tween.tween_property(outgoing, "volume_db", -40.0, fade).set_trans(Tween.TRANS_SINE)
		_music_tween.chain().tween_callback(outgoing.stop)


func stop_music(fade: float = 1.0) -> void:
	_music_name = &""
	_music_layers.clear()
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_current, "volume_db", -40.0, fade)
	_music_tween.tween_callback(_music_current.stop)


func _build_music_stream(track: StringName) -> AudioStream:
	var def: Dictionary = _music_defs[String(track)]
	var path := String(def.get("file", ""))
	if not ResourceLoader.exists(path):
		return null
	var base: AudioStream = load(path)
	_set_stream_loop(base)
	_music_layers.clear()
	var layer_streams: Array[AudioStream] = []
	for other in _music_defs:
		var od: Dictionary = _music_defs[other]
		if String(od.get("layer_of", "")) == String(track) and ResourceLoader.exists(String(od.get("file", ""))):
			var ls: AudioStream = load(String(od.file))
			_set_stream_loop(ls)
			layer_streams.append(ls)
			_music_layers.append(StringName(other))
	if layer_streams.is_empty():
		return base
	var sync := AudioStreamSynchronized.new()
	sync.stream_count = 1 + layer_streams.size()
	sync.set_sync_stream(0, base)
	for i in layer_streams.size():
		sync.set_sync_stream(i + 1, layer_streams[i])
		sync.set_sync_stream_volume(i + 1, -60.0)
	return sync


## The music track currently playing (or fading in), or &"" for none.
func get_music() -> StringName:
	return _music_name


## Plays a short music cue (fanfare) over the current music, ducking it.
func play_stinger(track: StringName, duck_db: float = -9.0) -> void:
	var stream := _start_stinger(track)
	if stream == null:
		return
	if _music_current != null and _music_current.playing:
		var hold := maxf(stream.get_length() - 0.5, 0.2)
		var tw := create_tween()
		tw.tween_property(_music_current, "volume_db", duck_db, 0.2)
		tw.tween_interval(hold)
		tw.tween_property(_music_current, "volume_db", 0.0, 0.8)


## Ends the current music on a fanfare (a boss beaten): the track fades out
## under the stinger and `next` fades in once it has rung out, unless other
## music has started by then.
func play_finale(stinger: StringName, next: StringName = &"", fade_out: float = 0.5) -> void:
	stop_music(fade_out)
	var stream := _start_stinger(stinger)
	if next == &"":
		return
	var wait := stream.get_length() + 0.2 if stream != null else fade_out
	get_tree().create_timer(wait).timeout.connect(func() -> void:
		if _music_name == &"":
			play_music(next, 2.5))


func _start_stinger(track: StringName) -> AudioStream:
	if not _music_defs.has(String(track)):
		if not _warned.has(track):
			_warned[track] = true
			push_warning("AudioManager: unknown stinger '%s'" % track)
		return null
	var path := String((_music_defs[String(track)] as Dictionary).get("file", ""))
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Music"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return stream


## Enemies call this every tick while they are actively fighting Patchy: the
## current track's combat layer fades in and stays up until things have been
## calm for THREAT_HOLD seconds (spec §123).
func report_threat() -> void:
	_threat_t = THREAT_HOLD


## True while enemies are fighting Patchy (and the combat layer, if the
## current track has one, is up).
func is_combat_music() -> bool:
	return _combat_on


## Fade a named layer (e.g. "castaway_combat_layer") in or out.
func set_music_layer(layer: StringName, enabled: bool, fade: float = 1.0) -> void:
	var idx := _music_layers.find(layer)
	if idx == -1:
		return
	var sync := _music_current.stream as AudioStreamSynchronized
	if sync == null:
		return
	var old: Tween = _layer_tweens.get(layer)
	if old != null and old.is_valid():
		old.kill()
	var from := sync.get_sync_stream_volume(idx + 1)
	var to := 0.0 if enabled else -60.0
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: sync.set_sync_stream_volume(idx + 1, v), from, to, fade)
	_layer_tweens[layer] = tw
