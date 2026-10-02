@tool
class_name ParrotCage
extends Interactable
## A caged parrot (spec §64): pry it open with the hook ({interact}), smash
## it with an attack, or ground-pound it. The parrot bursts out, circles
## Patchy chirping, then flies off to join the flock. Cages chirp faintly
## when Patchy is nearby so they can be found by ear (spec §154), and stay
## open forever once rescued.

signal rescued(parrot_id: StringName)

@export var parrot_id: StringName = &""
@export var island_id: StringName = &""
@export var plumage := ParrotModel.Plumage.SCARLET:
	set(v):
		plumage = v
		if _parrot != null:
			_parrot.plumage = v
@export var hanging := false:
	set(v):
		hanging = v
		_build_visual()

var _visual: Node3D
var _door: Node3D
var _parrot: Parrot
var _open := false
var _chirp_t := 2.0


func _ready() -> void:
	prompt = "{interact} Open"
	radius = 1.7
	super._ready()
	_build_visual()
	if Engine.is_editor_hint():
		return
	add_to_group(&"look_at_target")
	if parrot_id == &"":
		push_warning("ParrotCage %s has no parrot_id; it will not persist" % name)
	if ParrotManager.is_rescued(parrot_id):
		_open = true
		enabled = false
		_door.rotation.y = -1.9
		return
	_parrot = Parrot.new()
	_parrot.plumage = plumage
	_parrot.chirps = false
	_parrot.position = Vector3(0, 0.42, 0)
	add_child(_parrot)


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or _open:
		return
	var p := GameManager.player
	if p == null:
		return
	_chirp_t -= delta
	var d := p.global_position.distance_to(global_position)
	if _chirp_t <= 0.0 and d < 22.0:
		_chirp_t = randf_range(2.5, 5.0)
		AudioManager.play(&"parrot_chirp", global_position, linear_to_db(clampf(1.2 - d / 22.0, 0.15, 1.0)), randf_range(0.95, 1.2), 0.0)


func can_interact(_player: Node3D) -> bool:
	return enabled and not _open


func interact(player: Node3D) -> void:
	super.interact(player)
	open(player)


func take_hit(hit: Dictionary) -> void:
	open(hit.get("source", GameManager.player))


func on_ground_pound(player: Node3D) -> void:
	open(player)


func open(by: Node3D = null) -> void:
	if _open or Engine.is_editor_hint():
		return
	_open = true
	enabled = false
	remove_from_group(&"look_at_target")
	AudioManager.play(&"cage_break", global_position)
	VFX.dust(self, global_position + Vector3.UP * 0.5, 8, 0.35, Color(1, 1, 1, 0.8), 2.0)
	var tw := create_tween()
	tw.tween_property(_door, "rotation:y", -1.9, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var player := by as Player
	if player == null:
		player = GameManager.player as Player
	ParrotManager.rescue(parrot_id, island_id)
	rescued.emit(parrot_id)
	AudioManager.play(&"parrot_rescue", global_position)
	AudioManager.play_stinger(&"stinger_parrot")
	VFX.sparkle(self, global_position + Vector3.UP * 0.8, Palette.PARROT_YELLOW, 18, 5.0)
	if _parrot != null:
		var bird := _parrot
		bird.chirps = true
		bird.reparent(get_tree().current_scene)
		if player != null:
			bird.orbit(player, 1.3, 2.1)
			_celebrate(player)
		get_tree().create_timer(2.4, false).timeout.connect(func() -> void:
			if is_instance_valid(bird):
				bird.fly_away())


func _celebrate(player: Player) -> void:
	if player.state_id != &"ground":
		return
	var face := Player.flat(global_position - player.global_position)
	player.set_locked(true, {"anim": &"cheer", "face": face.normalized() if face.length() > 0.1 else player.facing})
	await get_tree().create_timer(0.9, false).timeout
	if is_instance_valid(player) and player.state_id == &"locked":
		player.set_locked(false)


func _build_visual() -> void:
	if not is_inside_tree():
		return
	if _visual != null:
		_visual.queue_free()
	_visual = Node3D.new()
	_visual.name = "CageVisual"
	add_child(_visual, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	var wood := MeshBuilder.new()
	var bars := 12
	var r := 0.42
	var h := 0.8
	var brass := Palette.BRASS
	for k in bars:
		var a := TAU * k / bars
		if k == 0:
			continue
		var pts := PackedVector3Array()
		for j in 7:
			var t := float(j) / 6.0
			var y := t * h
			var rr := r if y < h * 0.7 else r * cos((y - h * 0.7) / (h * 0.3 + 0.12) * PI * 0.5) + 0.03
			pts.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		pts.append(Vector3(0, h + 0.12, 0))
		mb.tube(pts, PackedFloat32Array([0.022]), brass, 5, false)
	mb.torus(r - 0.03, r + 0.03, Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), brass.darkened(0.15), 24, 6)
	mb.torus(r - 0.03, r + 0.03, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.62, 0)), brass.darkened(0.15), 24, 6)
	mb.torus(0.05, 0.1, Transform3D(Basis.from_euler(Vector3(PI * 0.5, 0, 0)), Vector3(0, h + 0.2, 0)), brass, 12, 6)
	wood.cylinder(r + 0.04, r + 0.08, 0.08, Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0)), Palette.WOOD_DARK, 20)
	wood.cylinder(0.02, 0.02, r * 1.6, Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(0, 0.36, 0)), Palette.WOOD, 6)
	var mesh := ArrayMesh.new()
	mb.build(mesh, MaterialLibrary.toon(Color.WHITE, &"metal"))
	wood.build(mesh, MaterialLibrary.toon(Color.WHITE, &"matte"))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	_visual.add_child(mi)
	# Door: the missing bar's gap gets a little hinged gate.
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(cos(TAU / bars) * r, 0, sin(TAU / bars) * r)
	_visual.add_child(_door)
	var db := MeshBuilder.new()
	for k in 3:
		var a := -TAU / bars * (k * 0.5)
		db.cylinder(0.02, 0.02, h * 0.6, Transform3D(Basis.IDENTITY, Vector3(r * cos(a) - _door.position.x, h * 0.3, r * sin(a) - _door.position.z)), brass.lightened(0.1), 5)
	var dm := MeshInstance3D.new()
	dm.mesh = db.build(null, MaterialLibrary.toon(Color.WHITE, &"metal"))
	_door.add_child(dm)
	if hanging:
		var rope := MeshBuilder.new()
		rope.cylinder(0.03, 0.03, 2.0, Transform3D(Basis.IDENTITY, Vector3(0, h + 1.2, 0)), Palette.ROPE, 6)
		var rm := MeshInstance3D.new()
		rm.mesh = rope.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
		_visual.add_child(rm)
