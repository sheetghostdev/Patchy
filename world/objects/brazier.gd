@tool
class_name Brazier
extends Interactable
## A stone fire bowl (spec §57 lantern puzzles). Light it from the lantern:
## a flash nearby, or the tool button while standing at it. Stays lit
## (persistent) and reports to any Gate that lists it.

signal activated

@export var brazier_id: StringName = &""

var _lit := false
var _fire: Node3D
var _light: OmniLight3D
var _t := 0.0


func _ready() -> void:
	prompt = "{tool_primary} Light"
	action = &"tool_primary"
	radius = 1.8
	super._ready()
	var mb := MeshBuilder.new()
	mb.cylinder(0.18, 0.28, 0.9, Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)), Palette.STONE, 10)
	mb.cylinder(0.55, 0.32, 0.32, Transform3D(Basis.IDENTITY, Vector3(0, 1.05, 0)), Palette.STONE.darkened(0.1), 14)
	mb.cylinder(0.47, 0.47, 0.04, Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0)), Color("3a2c22"), 14)
	var mi := MeshInstance3D.new()
	mi.mesh = mb.build(null, MaterialLibrary.toon(Color.WHITE, &"matte"))
	add_child(mi, false, Node.INTERNAL_MODE_FRONT)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.45
	cyl.height = 1.2
	cs.shape = cyl
	cs.position = Vector3(0, 0.6, 0)
	body.add_child(cs)
	add_child(body, false, Node.INTERNAL_MODE_FRONT)
	_fire = Node3D.new()
	_fire.position = Vector3(0, 1.25, 0)
	add_child(_fire, false, Node.INTERNAL_MODE_FRONT)
	var fb := MeshBuilder.new()
	fb.sphere(0.3, Transform3D(Basis.from_scale(Vector3(1, 1.6, 1)), Vector3(0, 0.25, 0)), Color("ff9a3c"), 6, 10)
	fb.sphere(0.18, Transform3D(Basis.from_scale(Vector3(1, 1.7, 1)), Vector3(0, 0.22, 0)), Color("ffe08a"), 5, 8)
	var fm := MeshInstance3D.new()
	fm.mesh = fb.build(null, MaterialLibrary.toon(Color.WHITE, &"emissive"))
	fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire.add_child(fm)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.65, 0.3)
	_light.light_energy = 2.0
	_light.omni_range = 7.0
	_light.position = Vector3(0, 0.5, 0)
	_fire.add_child(_light)
	_fire.visible = false
	if Engine.is_editor_hint():
		return
	add_to_group(&"brazier")
	if brazier_id != &"" and WorldState.is_completed(brazier_id):
		_set_lit(false)


func _process(delta: float) -> void:
	if not _lit:
		return
	_t += delta
	_fire.scale = Vector3(1.0, 1.0 + sin(_t * 11.0) * 0.08 + sin(_t * 17.0) * 0.05, 1.0)
	_light.light_energy = 2.0 + sin(_t * 13.0) * 0.25


func can_interact(_player: Node3D) -> bool:
	return enabled and not _lit


func get_prompt() -> String:
	if InventoryManager.equipped_attachment == &"lantern":
		return prompt
	return "Needs a flame"


func interact(player: Node3D) -> void:
	if InventoryManager.equipped_attachment != &"lantern":
		AudioManager.play_ui(&"ui_back")
		return
	super.interact(player)
	light_up()


func on_light_flash(_player: Node3D) -> void:
	light_up()


func is_active() -> bool:
	return _lit


func light_up() -> void:
	if _lit:
		return
	_set_lit(true)
	if brazier_id != &"":
		WorldState.mark_completed(brazier_id)
	activated.emit()


func _set_lit(with_fx: bool) -> void:
	_lit = true
	enabled = false
	_fire.visible = true
	if with_fx:
		AudioManager.play(&"lantern_on", global_position, 0.0, 0.8)
		VFX.sparkle(get_tree().current_scene, global_position + Vector3.UP * 1.4, Color(1.0, 0.7, 0.3), 14, 3.0)
