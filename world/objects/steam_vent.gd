@tool
class_name SteamVent
extends Area3D
## A vent in a grotto floor (Teacup Isle) that, once unplugged, blows a
## column of steam: step in and it carries Patchy up `height` m. Plugged, it
## only fizzles. Its SugarPlug unplugs it.

signal opened

@export var height := 7.0
@export var lift := 7.0
@export var open := false

var _wisps: Array[MeshInstance3D] = []
var _t := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = Layers.PLAYER
	monitorable = false
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.2
	cyl.height = height
	cs.shape = cyl
	cs.position = Vector3(0, height * 0.5, 0)
	add_child(cs, false, Node.INTERNAL_MODE_FRONT)
	var mb := MeshBuilder.new()
	mb.cylinder(1.3, 1.5, 0.3, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Color("8c8478"), 14)
	mb.cylinder(0.85, 0.85, 0.32, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)), Color("3a3430"), 14)
	var rim := MeshInstance3D.new()
	rim.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(rim, false, Node.INTERNAL_MODE_FRONT)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 1, 1, 0.45)
	for i in 8:
		var w := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.6
		sph.height = 1.2
		sph.radial_segments = 8
		sph.rings = 4
		w.mesh = sph
		w.material_override = mat
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(w, false, Node.INTERNAL_MODE_FRONT)
		_wisps.append(w)


func unplug() -> void:
	if open:
		return
	open = true
	AudioManager.play(&"wind_gust", global_position + Vector3.UP, -4.0, 1.6)
	opened.emit()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not open:
		return
	for body in get_overlapping_bodies():
		var p := body as Player
		if p == null or p.state_id in [&"locked", &"swing", &"grapple", &"boat"]:
			continue
		if p.is_on_floor():
			p.start_jump(&"ledge_jump", lift)
		elif p.velocity.y < lift:
			p.velocity.y = move_toward(p.velocity.y, lift, 60.0 * get_physics_process_delta_time())


func _process(delta: float) -> void:
	_t += delta
	var top := height if open else 0.8
	for i in _wisps.size():
		var u := fposmod(_t * (0.9 if open else 0.3) + i / float(_wisps.size()), 1.0)
		var w := _wisps[i]
		w.position = Vector3(sin(i * 2.1 + _t) * 0.35, u * top, cos(i * 1.7 + _t) * 0.35)
		var s := lerpf(0.5, 1.6, u) * (1.0 if open else 0.5)
		w.scale = Vector3.ONE * s * (1.0 - u * 0.4)
		w.transparency = clampf(u * 1.1, 0.0, 1.0)
