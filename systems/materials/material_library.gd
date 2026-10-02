class_name MaterialLibrary
## Cached, shared stylized materials. Procedural meshes carry vertex colors
## and share a handful of materials per finish, keeping draw state small.

const TOON_SHADER := preload("res://shaders/toon.gdshader")
const TERRAIN_SHADER := preload("res://shaders/toon_terrain.gdshader")
const WATER_SHADER := preload("res://shaders/water_simple.gdshader")

static var _cache: Dictionary = {}


## Finishes: &"matte" (cloth, wood, foliage), &"soft" (skin), &"glossy"
## (painted, shell), &"metal" (hook, brass), &"emissive" (glows).
static func toon(color: Color = Color.WHITE, finish: StringName = &"matte") -> ShaderMaterial:
	var key := "toon_%s_%s" % [color.to_html(), finish]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter(&"albedo", color)
	match finish:
		&"soft":
			m.set_shader_parameter(&"rim_strength", 0.3)
			m.set_shader_parameter(&"spec_strength", 0.06)
			m.set_shader_parameter(&"form_shading", 0.3)
		&"glossy":
			m.set_shader_parameter(&"spec_strength", 0.35)
			m.set_shader_parameter(&"spec_size", 0.9)
			m.set_shader_parameter(&"roughness", 0.45)
		&"metal":
			m.set_shader_parameter(&"spec_strength", 0.8)
			m.set_shader_parameter(&"spec_size", 0.86)
			m.set_shader_parameter(&"rim_strength", 0.45)
			m.set_shader_parameter(&"roughness", 0.3)
			m.set_shader_parameter(&"metallic", 0.35)
		&"emissive":
			m.set_shader_parameter(&"emission_color", color)
			m.set_shader_parameter(&"emission_energy", 1.4)
		_:
			pass
	_cache[key] = m
	return m


## A unique (non-shared) toon material, for things that animate parameters
## like hit flashes.
static func toon_unique(color: Color = Color.WHITE, finish: StringName = &"matte") -> ShaderMaterial:
	return toon(color, finish).duplicate() as ShaderMaterial


static func terrain(surface: StringName) -> ShaderMaterial:
	var key := "terrain_%s" % surface
	if _cache.has(key):
		return _cache[key]
	var preset: Array = Palette.TERRAIN.get(surface, Palette.TERRAIN[&"grass"])
	var m := ShaderMaterial.new()
	m.shader = TERRAIN_SHADER
	m.set_shader_parameter(&"top_color", preset[0])
	m.set_shader_parameter(&"side_color", preset[1])
	m.set_shader_parameter(&"side_dark_color", preset[2])
	if surface == &"sand" or surface == &"lab" or String(surface).begins_with("lab_"):
		m.set_shader_parameter(&"lip_height", 0.0)
		m.set_shader_parameter(&"stripe_strength", 0.0)
	if surface == &"wood":
		m.set_shader_parameter(&"lip_height", 0.0)
		m.set_shader_parameter(&"stripe_strength", 0.12)
	_cache[key] = m
	return m


static func water_simple() -> ShaderMaterial:
	if _cache.has("water_simple"):
		return _cache["water_simple"]
	var m := ShaderMaterial.new()
	m.shader = WATER_SHADER
	_cache["water_simple"] = m
	return m


## Plain unshaded color (debug lines, labels' backing, VFX).
static func unshaded(color: Color) -> StandardMaterial3D:
	var key := "unshaded_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = m
	return m
