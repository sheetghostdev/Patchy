shader_type spatial;
render_mode unshaded, fog_disabled, depth_test_disabled, depth_draw_never, cull_disabled, shadows_disabled, blend_premul_alpha;
// Depth-aware underwater fog for UnderwaterEffect, drawn as a full-screen
// quad after the transparent pass: water between the camera and whatever it
// sees (seabed, or the surface when looking up) fades to a fog color that is
// lighter toward the surface and darker below, and caustic light dances on
// up-facing submerged surfaces. Uses the same per-pixel lens test as
// underwater.gdshader so a half-submerged camera only fogs the lower part.

#include "res://world/ocean/ocean_waves.gdshaderinc"

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D normal_rough_tex : hint_normal_roughness_texture, filter_nearest;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;
uniform float water_level = 0.0;
uniform bool use_waves = false;
uniform float lens_distance = 0.25;
uniform vec3 fog_color : source_color = vec3(0.22, 0.66, 0.72);
uniform vec3 fog_deep_color : source_color = vec3(0.07, 0.3, 0.46);
uniform float fog_density = 0.055;
uniform float fog_max : hint_range(0.0, 1.0) = 0.96;
uniform float depth_darkening = 30.0;
uniform vec3 caustic_color : source_color = vec3(0.75, 1.0, 0.95);
uniform float caustic_strength = 1.3;
uniform float caustic_scale = 0.5;
uniform float caustic_depth_fade = 0.12;

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
	// Full-screen triangle pair straight in clip space (QuadMesh 2 x 2).
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

void fragment() {
	float raw = texture(depth_tex, SCREEN_UV).r;
	vec4 vp = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	vp.xyz /= vp.w;
	vec3 wp = (INV_VIEW_MATRIX * vec4(vp.xyz, 1.0)).xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 ray = wp - cam;
	float dist = length(ray);
	vec3 dir = ray / max(dist, 1.0e-4);

	// Is this pixel's lens point under water? (matches the screen pass)
	vec3 fwd = -INV_VIEW_MATRIX[2].xyz;
	vec3 lens = cam + dir * (lens_distance / max(dot(dir, fwd), 0.05));
	float surface = water_level + (use_waves ? ocean_height_at(lens.xz) : 0.0);
	float under = step(lens.y, surface) * amount;

	// Water travelled before reaching the scene or the surface overhead.
	float travel = dist;
	if (dir.y > 1.0e-4) {
		float to_surface = (water_level - cam.y) / dir.y;
		if (to_surface > 0.0) {
			travel = min(travel, to_surface);
		}
	}
	float fog = (1.0 - exp(-travel * fog_density)) * fog_max;
	float cam_depth = max(water_level - cam.y, 0.0);
	float dk = clamp(smoothstep(0.0, depth_darkening, cam_depth) - dir.y * 0.35 + 0.1, 0.0, 1.0);
	vec3 fcol = mix(fog_color, fog_deep_color, dk);

	// Caustic light on submerged surfaces that face up.
	vec3 n_view = texture(normal_rough_tex, SCREEN_UV).xyz * 2.0 - 1.0;
	float up = clamp((INV_VIEW_MATRIX * vec4(n_view, 0.0)).y, 0.0, 1.0);
	float sub = water_level - wp.y;
	vec2 q = wp.xz * caustic_scale;
	float t = effect_time;
	float ca_a = vnoise(q + vec2(t * 0.31, t * 0.17));
	float ca_b = vnoise(q * 1.37 + vec2(-t * 0.23, t * 0.29) + 17.3);
	float ca = pow(clamp(1.0 - abs(ca_a - ca_b) * 3.2, 0.0, 1.0), 3.5);
	ca *= up * smoothstep(0.0, 0.4, sub) * exp(-max(sub, 0.0) * caustic_depth_fade) * step(raw, 0.99999) * step(0.0000001, raw);
	vec3 add = caustic_color * ca * caustic_strength * (1.0 - fog);

	// Premultiplied: fog mixes over the scene, caustics add light.
	ALBEDO = (fcol * fog + add) * under;
	ALPHA = fog * under;
}
