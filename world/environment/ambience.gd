class_name Ambience
extends Node3D
## Island ambience: looping surf and wind beds on the Ambience bus, plus
## occasional seagull calls placed around the listener (spec §121, §166).

@export var surf := true
@export var wind := true
@export var gulls := true
@export_range(-40.0, 6.0, 0.5) var surf_db := -8.0
@export_range(-40.0, 6.0, 0.5) var wind_db := -16.0

var _beds: Array[AudioStreamPlayer] = []
var _gull_t := 4.0


func _ready() -> void:
	if surf:
		_bed(&"ocean_waves_loop", surf_db)
	if wind:
		_bed(&"wind_loop", wind_db)


func _bed(sound: StringName, db: float) -> void:
	if not AudioManager.has_sound(sound):
		return
	var p := AudioStreamPlayer.new()
	p.bus = &"Ambience"
	var holder := AudioManager.create_loop(sound, self, db)
	p.stream = holder.stream
	p.volume_db = db
	holder.queue_free()
	add_child(p)
	if p.stream != null:
		p.play()
	_beds.append(p)


func _process(delta: float) -> void:
	if not gulls:
		return
	_gull_t -= delta
	if _gull_t <= 0.0:
		_gull_t = randf_range(6.0, 14.0)
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var offset := Vector3(randf_range(-25, 25), randf_range(8, 16), randf_range(-25, 25))
			AudioManager.play(&"seagull", cam.global_position + offset, -6.0, randf_range(0.9, 1.1))
