class_name LanternAttachment
extends AttachmentBase
## A little brass storm lantern hung from the hook (spec §57).
## - Traversal: dark caves are safe while it's out (DarknessZone checks it).
## - Puzzles: braziers light from its flame.
## - Combat: a bright flash dazzles nearby enemies; even armored crabs
##   topple over.
## - Secrets: its glow shows hidden glyphs and lights dark nooks.

const FLASH_RADIUS := 5.5
const FLASH_COOLDOWN := 1.1
const BASE_ENERGY := 1.5

var _light: OmniLight3D
var _cool := 0.0
var _flash := 0.0
var _t := 0.0


func _ready() -> void:
	var metal := MeshBuilder.new()
	var glow := MeshBuilder.new()
	var hang := Basis.from_euler(Vector3(0, 0, PI * 0.5))
	metal.torus(0.035, 0.055, Transform3D(hang, Vector3(0, -0.07, 0)), Palette.BRASS, 12, 5)
	metal.cylinder(0.045, 0.11, 0.07, Transform3D(Basis.IDENTITY, Vector3(0, -0.135, 0)), Palette.BRASS, 12)
	metal.cylinder(0.02, 0.02, 0.03, Transform3D(Basis.IDENTITY, Vector3(0, -0.095, 0)), Palette.BRASS.darkened(0.2), 6)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		metal.cylinder(0.011, 0.011, 0.18, Transform3D(Basis.IDENTITY, Vector3(cos(a) * 0.088, -0.255, sin(a) * 0.088)), Palette.BRASS.darkened(0.25), 5)
	metal.cylinder(0.105, 0.1, 0.045, Transform3D(Basis.IDENTITY, Vector3(0, -0.365, 0)), Palette.BRASS, 12)
	glow.cylinder(0.08, 0.08, 0.17, Transform3D(Basis.IDENTITY, Vector3(0, -0.255, 0)), Color("ffd27a"), 12)
	glow.sphere(0.035, Transform3D(Basis.IDENTITY, Vector3(0, -0.26, 0)), Color("fff3c4"), 5, 8)
	add_mesh(metal, &"metal")
	add_mesh(glow, &"emissive")
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.82, 0.5)
	_light.light_energy = BASE_ENERGY
	_light.omni_range = 7.5
	_light.omni_attenuation = 1.3
	_light.position = Vector3(0, -0.26, 0)
	add_child(_light)


func pickup_hint() -> String:
	return "Lantern! Dark caves are safe now. {tool_primary} makes a dazzling flash."


func equip(p: Player) -> void:
	super.equip(p)
	_light.visible = true
	AudioManager.play(&"lantern_on", p.global_position + Vector3.UP)


func unequip() -> void:
	super.unequip()
	_light.visible = false


func physics_update(delta: float) -> void:
	_t += delta
	_cool = maxf(_cool - delta, 0.0)
	_flash = maxf(_flash - delta * 2.2, 0.0)
	var flicker := sin(_t * 13.0) * 0.08 + sin(_t * 23.0 + 1.3) * 0.05
	_light.light_energy = BASE_ENERGY + flicker + _flash * 7.0
	_light.omni_range = 7.5 + _flash * 5.0


func primary_action() -> void:
	if player == null or _cool > 0.0:
		return
	_cool = FLASH_COOLDOWN
	_flash = 1.0
	player.play_tool_anim(&"flash", 0.55)
	var center := global_position
	AudioManager.play(&"lantern_on", center, 2.0, 1.5)
	VFX.sparkle(get_tree().current_scene, center, Color(1.0, 0.9, 0.55), 22, 6.0)
	VFX.ring(get_tree().current_scene, player.global_position + Vector3.UP * 0.1, FLASH_RADIUS, 20)
	for n in get_tree().get_nodes_in_group(&"enemy") + get_tree().get_nodes_in_group(&"brazier"):
		var target := n as Node3D
		if target == null or not target.has_method(&"on_light_flash"):
			continue
		if target.global_position.distance_to(player.global_position) <= FLASH_RADIUS:
			target.call(&"on_light_flash", player)
