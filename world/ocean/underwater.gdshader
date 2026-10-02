shader_type canvas_item;
render_mode unshaded;
// Screen-space underwater look for UnderwaterEffect (world/ocean/
// underwater_effect.gd): wavy distortion, blue-green tint that deepens with
// depth, soft light shafts and caustic shimmer, a gentle vignette and a
// wobbly waterline when the camera straddles the surface.
//
// Which pixels are under water is decided per pixel on a "lens" plane just in
// front of the camera (corners set by the script), against the same Gerstner
// waves the ocean draws, so a half-submerged camera shows a moving split.

#include "res://world/ocean/ocean_waves.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
// Smoothed 0..1 blend (0.2 s in/out) driven by the script.
uniform float amount : hint_range(0.0, 1.0) = 0.0;
uniform float effect_time = 0.0;
// World positions of the screen corners on the lens plane.
uniform vec3 lens_tl = vec3(0.0);
uniform vec3 lens_tr = vec3(0.0);
uniform vec3 lens_bl = vec3(0.0);
uniform vec3 lens_br = vec3(0.0);
uniform float water_level = 0.0;
uniform bool use_waves = false;
// Camera depth below the surface (m), for darkening.
uniform float camera_depth = 0.0;
uniform float aspect = 1.7778;

uniform vec3 tint : source_color = vec3(0.32, 0.76, 1.0);
uniform vec3 deep_tint : source_color = vec3(0.12, 0.36, 0.62);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.55;
uniform float depth_darkening = 28.0;
uniform float distortion = 0.0045;
uniform float vignette : hint_range(0.0, 1.0) = 0.42;
uniform float shimmer : hint_range(0.0, 1.0) = 0.15;
uniform float light_shafts : hint_range(0.0, 1.0) = 0.16;
uniform vec3 waterline_color : source_color = vec3(0.9, 1.0, 1.0);
uniform float waterline_width = 0.012;

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

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = effect_time;
	vec3 lens = mix(mix(lens_tl, lens_tr, uv.x), mix(lens_bl, lens_br, uv.x), uv.y);
	float surface = water_level + (use_waves ? ocean_height_at(lens.xz) : 0.0);
	// Small wobble so the split line ripples like a meniscus.
	surface += (vnoise(vec2(uv.x * 9.0 + t * 1.3, t * 0.7)) - 0.5) * 0.012;
	float below = surface - lens.y;
	float aa = max(fwidth(below), 1.0e-4);
	float under = smoothstep(-aa, aa, below) * amount;
	float line = (1.0 - smoothstep(waterline_width * 0.4, waterline_width, abs(below))) * amount;

	vec4 result = vec4(0.0);
	if (under > 0.0 || line > 0.0) {
		vec2 d = vec2(sin(uv.y * 21.0 + t * 1.7) + sin(uv.y * 7.0 - t * 0.9) * 0.6,
				cos(uv.x * 17.0 + t * 1.3) + cos(uv.x * 5.0 + t * 0.7) * 0.6) * distortion;
		vec3 col = texture(screen_tex, uv + d * under).rgb;
		float dk = smoothstep(0.0, depth_darkening, camera_depth);
		vec3 tc = mix(tint, deep_tint, dk);
		// Tint: multiply toward the water color, then lift toward it.
		col = mix(col, col * tc * 1.35, tint_strength);
		col = mix(col, tc * 0.6, tint_strength * 0.4);
		// Light shafts slanting down from the surface and a caustic shimmer.
		vec2 sp = vec2((uv.x - 0.5) * aspect, uv.y);
		float rays = vnoise(vec2(sp.x * 7.0 + sp.y * 2.2 + t * 0.08, t * 0.12));
		rays = pow(rays, 3.0) * smoothstep(1.0, 0.0, uv.y) * (1.0 - dk);
		// Soft flickering light, brighter toward the surface (no hard lines:
		// the floor caustics live in world space in underwater_fog).
		float fl = vnoise(sp * 4.5 + vec2(t * 0.55, -t * 0.4)) * vnoise(sp * 2.7 - vec2(t * 0.35, t * 0.5) + 4.2);
		col *= 1.0 + (fl - 0.25) * shimmer * 4.0 * (1.0 - dk) * (1.2 - uv.y);
		col += tint * rays * light_shafts * 1.6;
		// Vignette.
		float r = length((uv - 0.5) * vec2(aspect / 1.7778, 1.0));
		col *= 1.0 - vignette * smoothstep(0.32, 0.85, r);
		col = mix(col, waterline_color, line * 0.7);
		result = vec4(col, max(under, line));
	}
	COLOR = result;
}
