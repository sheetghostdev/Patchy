extends Node3D
## Lines up the islanders (and Patchy for scale) for visual review.
## tools/photo/shoot.sh scene=res://tests/npc_gallery.tscn "cams=0,1.6,4.5>0,0.7,0"

func _ready() -> void:
	add_child(SkyEnvironment.new())
	var floor_block := LevelBlock.new()
	floor_block.size = Vector3(40, 1, 20)
	floor_block.surface = "sand"
	floor_block.position = Vector3(0, -1, 0)
	add_child(floor_block)
	var patchy := PatchyModel.new()
	patchy.position = Vector3(-2.4, 0, 0)
	patchy.rotation.y = PI
	add_child(patchy)
	var models: Array[Node3D] = [TurtleModel.new(), MonkeyModel.new(), OtterModel.new(), BrockModel.new()]
	for i in models.size():
		models[i].position = Vector3(-0.8 + i * 1.3, 0, 0)
		models[i].rotation.y = PI
		add_child(models[i])
	var boat := FishingBoat.new()
	boat.position = Vector3(2.5, 0.5, -4.0)
	boat.rotation.y = deg_to_rad(-60.0)
	boat.flag_until = &"never"
	add_child(boat)
