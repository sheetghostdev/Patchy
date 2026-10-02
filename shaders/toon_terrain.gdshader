shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Stylized ground: walkable tops take the top color (grass, sand, deck),
// steep faces take the side color with a painted vertical gradient, and a
// wobbly lip of top color hangs over each cliff edge. Readable walkable vs.
// wall at a glance (spec §6).

#include "res://shaders/includes/toon_light.gdshaderinc"

uniform vec4 top_color : source_color = vec4(0.48, 0.8, 0.29, 1.0);
uniform vec4 side_color : source_color = vec4(0.72, 0.5, 0.31, 1.0);
uniform vec4 side_dark_color : source_color = vec4(0.52, 0.34, 0.24, 1.0);
uniform float top_threshold : hint_range(0.0, 1.0) = 0.66;
uniform float top_blend : hint_range(0.0, 0.5) = 0.05;
uniform float lip_height : hint_range(0.0, 1.0) = 0.16;
uniform float gradient_depth = 3.5;
uniform float noise_scale = 0.45;
uniform float noise_strength : hint_range(0.0, 0.5) = 0.07;
uniform float stripe_strength : hint_range(0.0, 0.5) = 0.05;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
// World height of this block's top surface, set per instance.
instance uniform float top_y = 0.0;

varying vec3 world_pos;
varying vec3 world_normal;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n = vnoise(world_pos.xz * noise_scale) * 0.65 + vnoise(world_pos.xz * noise_scale * 3.3 + 11.0) * 0.35;
	float is_top = smoothstep(top_threshold - top_blend, top_threshold + top_blend, world_normal.y);

	float depth = top_y - world_pos.y;
	float wobble = (vnoise(vec2(world_pos.x + world_pos.z, 0.0) * 2.7) - 0.5) * lip_height * 0.9;
	float lip = 1.0 - smoothstep(lip_height + wobble - 0.02, lip_height + wobble + 0.02, depth);
	lip *= step(0.0, depth + 0.05);

	float sn = vnoise(vec2(world_pos.x * 0.7 + world_pos.z * 0.7, world_pos.y * 2.2));
	float g = smoothstep(0.0, gradient_depth, depth + (sn - 0.5) * 0.6);
	vec3 side = mix(side_color.rgb, side_dark_color.rgb, g);
	// Painterly horizontal strata on cliffs.
	side *= 1.0 - stripe_strength * step(0.5, fract(world_pos.y * 1.3 + sn * 0.6));

	vec3 top = top_color.rgb * (1.0 + (n - 0.5) * 2.0 * noise_strength);
	vec3 col = mix(side, top, max(is_top, lip * (1.0 - is_top) * 0.95));
	ALBEDO = col;
	ROUGHNESS = roughness;
}
