shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;
// Lightweight stylized water for pools and test scenes: turquoise-to-deep
// color by depth, soft edge foam where it meets geometry, gentle ripples
// and sparkles. The ocean uses world/ocean/ocean.gdshader.

uniform vec4 shallow_color : source_color = vec4(0.27, 0.86, 0.82, 0.72);
uniform vec4 deep_color : source_color = vec4(0.08, 0.45, 0.72, 0.9);
uniform vec4 foam_color : source_color = vec4(0.95, 1.0, 1.0, 1.0);
uniform float depth_range = 3.0;
uniform float foam_width = 0.35;
uniform float ripple_scale = 0.9;
uniform float ripple_speed = 0.6;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear_mipmap;

varying vec3 world_pos;

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
	float t = TIME * ripple_speed;
	VERTEX.y += 0.04 * sin(world_pos.x * 0.8 + t * 2.0) * cos(world_pos.z * 0.7 + t * 1.6);
}

void fragment() {
	float scene_depth = texture(depth_tex, SCREEN_UV).r;
	vec4 ndc = vec4(SCREEN_UV * 2.0 - 1.0, scene_depth, 1.0);
	vec4 view = INV_PROJECTION_MATRIX * ndc;
	view.xyz /= view.w;
	float water_depth = clamp(-view.z - (-VERTEX.z), 0.0, 100.0);

	float t = TIME * ripple_speed;
	float r1 = vnoise(world_pos.xz * ripple_scale + vec2(t, t * 0.7));
	float r2 = vnoise(world_pos.xz * ripple_scale * 2.3 - vec2(t * 0.8, t * 1.1));
	float ripple = r1 * 0.6 + r2 * 0.4;

	float dk = smoothstep(0.0, depth_range, water_depth);
	vec4 col = mix(shallow_color, deep_color, dk);
	float edge = 1.0 - smoothstep(0.0, foam_width * (0.7 + ripple * 0.6), water_depth);
	float bands = step(0.55, fract(water_depth / foam_width * 0.5 - t * 0.5 + ripple * 0.4)) * (1.0 - smoothstep(0.0, foam_width * 2.5, water_depth)) * 0.6;
	float foam = clamp(edge + bands, 0.0, 1.0);
	float sparkle = step(0.93, ripple) * 0.6;

	ALBEDO = mix(col.rgb + sparkle, foam_color.rgb, foam);
	ALPHA = mix(col.a, 1.0, foam);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
	NORMAL_MAP = vec3(0.5 + (r1 - 0.5) * 0.25, 0.5 + (r2 - 0.5) * 0.25, 1.0);
}
