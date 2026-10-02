shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;
// Swaying, double-sided foliage & cloth for the props kit (palm fronds, ferns,
// grass, flowers, sails, bridge planks). Same soft cel lighting as the toon
// shader; vertex color is the albedo (authored in sRGB like the Palette).
// UV carries animation data written by PropBuilder:
//   UV.y = sway weight (0 = rooted, 1 = free tip), UV.x = phase offset.
// Vertex alpha 0 keeps authored (upward) normals on both faces.
// Wind is evaluated in world space so rotated / MultiMesh instances agree.

#include "res://shaders/includes/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
uniform float specular : hint_range(0.0, 1.0) = 0.15;
uniform vec2 wind_direction = vec2(0.85, 0.5);
// World-space sway at full weight (m).
uniform float sway_strength = 0.06;
uniform float sway_speed = 1.2;
// Small fast ripple (leaf flutter, cloth).
uniform float flutter_strength = 0.012;
uniform float flutter_speed = 4.0;
// Vertical bob (bridge planks, floating debris).
uniform float bob_strength = 0.0;
uniform float bob_speed = 1.5;
// Shapes the weight curve: >1 keeps the base calm and the tips loose.
uniform float weight_power = 1.5;
// Undersides read slightly darker so thin sheets look two-sided.
uniform float backface_darken : hint_range(0.0, 1.0) = 0.12;

vec3 srgb_to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	float w = pow(clamp(UV.y, 0.0, 1.0), weight_power);
	vec3 origin = MODEL_MATRIX[3].xyz;
	float phase = UV.x * 6.2831 + origin.x * 0.31 + origin.z * 0.23;
	vec2 wd = normalize(wind_direction);
	float gust = sin(TIME * sway_speed + phase) * 0.7 + sin(TIME * sway_speed * 2.17 + phase * 1.3) * 0.3;
	vec3 disp = vec3(wd.x, 0.0, wd.y) * gust * sway_strength * w;
	float fl = sin(TIME * flutter_speed + dot(VERTEX, vec3(3.1, 2.3, 4.7)) + phase * 2.0);
	disp += vec3(0.25, 1.0, 0.25) * fl * flutter_strength * w;
	disp.y += sin(TIME * bob_speed + phase) * bob_strength * w;
	// World-space offset -> model space; scaled instances sway proportionally.
	mat3 m = mat3(MODEL_MATRIX);
	float s2 = max(dot(m[0], m[0]), 1e-6);
	VERTEX += transpose(m) * disp / sqrt(s2);
}

void fragment() {
	// Clamp: with MSAA, edge pixels of thin leaves are shaded outside the
	// triangle and gradients would extrapolate into blown-out colors.
	vec3 c = albedo.rgb * srgb_to_linear(clamp(COLOR.rgb, vec3(0.0), vec3(1.0)));
	// Godot already flips NORMAL on back faces of cull_disabled materials.
	// Vertex alpha 0 tags "up-normal" foliage (grass, flowers, leaf cards):
	// undo the flip so both faces keep the authored upward normal.
	if (!FRONT_FACING) {
		if (COLOR.a < 0.5) {
			NORMAL = -NORMAL;
		} else {
			c *= 1.0 - backface_darken;
		}
	}
	ALBEDO = c;
	ROUGHNESS = roughness;
	// Leaves are matte: keep the sky reflection from washing them out.
	SPECULAR = specular;
}
