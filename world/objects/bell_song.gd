class_name BellSong
extends Node
## Bell Atoll's puzzle (docs/ARCHIPELAGO.md): ring the five ReefBells in the
## order carved on the SongStone. The first right note brings the Tide in;
## finish before it's high or start again. A wrong note sets the gulls
## laughing (ReefGull) and the tide goes out. The song done, the RisingDais
## comes up out of the lagoon with the chest. The great bell in the belfry
## plays the song through, lighting each reef bell in turn.

signal solved

@export var song_id: StringName = &"bell_atoll_song"
@export var bells: Array[ReefBell] = []
## The great bell in the belfry (note 0).
@export var great_bell: ReefBell
## The song, as notes (1 = the biggest bell).
@export var song := PackedInt32Array([4, 3, 5, 2, 1])
@export var tide: Tide
@export var dais: RisingDais
@export var gulls: Array[Node3D] = []

var progress := 0
var done := false
var _playing := false


func _ready() -> void:
	for b in bells:
		if b != null:
			b.rung.connect(_on_rung)
	if great_bell != null:
		great_bell.rung.connect(func(_b: ReefBell) -> void: play_song())
	if tide != null:
		tide.peaked.connect(_on_tide_high)
	if WorldState.is_completed(song_id):
		done = true
		if dais != null:
			dais.raise(false)


func bell_for(n: int) -> ReefBell:
	for b in bells:
		if b != null and b.note == n:
			return b
	return null


func _on_rung(bell: ReefBell) -> void:
	if done or _playing:
		return
	if bell.note == song[progress]:
		bell.set_lit(true)
		progress += 1
		if progress == 1 and tide != null:
			tide.rise()
			Events.hud_message.emit("That's the first note... and the tide is coming in!", 2.5)
		if progress == song.size():
			_solve()
		return
	_fail("The gulls laugh at your tune. Start the song again.")


func _on_tide_high() -> void:
	if not done and progress > 0:
		_fail("The tide's in, and the song's lost on the wind. Start again.")


func _fail(message: String) -> void:
	progress = 0
	for b in bells:
		if b != null:
			b.set_lit(false)
	if tide != null:
		tide.fall()
	var near := _nearest_gull()
	AudioManager.play(&"gull_laugh", near.global_position if near != null else null)
	for g in gulls:
		if g != null and g.has_method(&"laugh"):
			g.call(&"laugh")
	Events.hud_message.emit(message, 2.5)


func _nearest_gull() -> Node3D:
	var p := GameManager.player as Node3D
	var best: Node3D = null
	for g in gulls:
		if g != null and (best == null or (p != null and g.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position))):
			best = g
	return best


func _solve() -> void:
	done = true
	WorldState.mark_completed(song_id)
	if tide != null:
		tide.fall()
	AudioManager.play_stinger(&"stinger_treasure")
	Events.hud_message.emit("The sailor's song! Something stirs in the lagoon...", 3.0)
	await get_tree().create_timer(1.0, false).timeout
	if dais != null:
		dais.raise()
	solved.emit()
	await get_tree().create_timer(2.5, false).timeout
	for b in bells:
		if b != null:
			b.set_lit(false)


## The great bell's hint: the song played through on the reef bells, each
## one glowing as its note sounds.
func play_song() -> void:
	if _playing:
		return
	_playing = true
	await get_tree().create_timer(0.8, false).timeout
	for n in song:
		var b := bell_for(n)
		if b != null:
			AudioManager.play(&"reef_bell", b.get_aim_point(), 0.0, b.pitch(), 0.0)
			b.pulse()
		await get_tree().create_timer(0.55, false).timeout
	_playing = false
