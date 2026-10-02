shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, world_vertex_coords;
// Patchy's stylized ocean (driven by world/ocean/ocean.gd).
//
// Vertex: four world-space Gerstner waves (ocean_waves.gdshaderinc), faded
// with distance so the coarse far LOD rings never alias. Fragment: the same
// waves evaluated per pixel for normals and crest tint, small scrolling
// ripples, depth-banded turquoise -> blue color, see-through refracted
// shallows with caustics, wobbly animated shoreline foam bands, soft crest
// foam, sky-matched fresnel and horizon fade, and twinkling sun glints. The
// light() function is a water flavour of shaders/includes/toon_light.

#include "res://world/ocean/ocean_waves.gdshaderinc"

group_uniforms colors;
uniform vec3 shallow_color : source_color = vec3(0.27, 0.87, 0.83);
uniform vec3 mid_color : source_color = vec3(0.12, 0.68, 0.82);
uniform vec3 deep_color : source_color = vec3(0.086, 0.475, 0.725);
uniform vec3 crest_color : source_color = vec3(0.3, 0.8, 0.9);
// Vertical depths (m) of the soft color bands.
uniform float shallow_depth = 0.5;
uniform float mid_depth = 2.4;
uniform float deep_depth = 7.5;
uniform float crest_tint : hint_range(0.0, 1.0) = 0.38;
uniform float trough_darken : hint_range(0.0, 1.0) = 0.1;
uniform float color_noise : hint_range(0.0, 1.0) = 0.3;
// How much the water thickness along the view ray (vs. straight down)
// deepens the color: grazing views through shallows turn bluer.
uniform float view_depth_mix : hint_range(0.0, 1.0) = 0.3;
// Large-scale variation of the wave shading (breaks up the wave pattern).
uniform float swell_variation : hint_range(0.0, 1.0) = 0.55;

group_uniforms clarity;
// Opacity right at the shoreline and how fast water turns opaque (per m of
// water along the view ray).
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.1;
uniform float opacity_absorb = 0.65;
// Tint applied to the seabed seen through the water (red absorbed first).
uniform vec3 seabed_tint : source_color = vec3(0.45, 0.93, 0.9);
uniform float seabed_tint_depth = 1.6;
uniform float refraction_strength = 0.03;
uniform float caustic_strength = 0.55;
uniform float caustic_depth = 4.5;
uniform float caustic_scale = 0.55;

group_uniforms foam;
uniform vec3 foam_color : source_color = vec3(0.96, 1.0, 1.0);
// Vertical water depth (m) covered by the solid shoreline foam.
uniform float foam_width = 0.13;
uniform float foam_wobble : hint_range(0.0, 1.0) = 0.85;
// Always-on thin foam line right at the waterline (m of depth).
uniform float contact_width = 0.025;
// Animated foam lines running toward the shore.
uniform float band_spacing = 0.36;
uniform float band_width : hint_range(0.0, 1.0) = 0.2;
uniform float band_speed = 0.3;
uniform float band_reach = 0.9;
uniform float band_breakup : hint_range(0.0, 1.0) = 0.5;
uniform float crest_foam : hint_range(0.0, 1.0) = 0.3;
uniform float crest_foam_start : hint_range(0.0, 1.0) = 0.72;
uniform float foam_emission = 0.45;

group_uniforms surface;
// Exaggerates wave slopes in diffuse shading so gentle swells still read.
uniform float normal_boost = 2.4;
// Shore calming (fragment only, the geometry stays uniform): wave shading,
// crest tint and crest foam fade toward `shore_calm` in water shallower
// than `shore_calm_depth` m.
uniform float shore_calm : hint_range(0.0, 1.0) = 0.35;
uniform float shore_calm_depth = 3.0;
uniform float ripple_strength = 0.14;
uniform float ripple_scale = 0.45;
uniform float ripple_speed = 0.6;

group_uniforms reflection;
uniform float fresnel_strength : hint_range(0.0, 1.0) = 0.5;
// How much the wave normal bends the sky reflection (1 = full shading normal).
uniform float reflection_normal : hint_range(0.0, 1.0) = 0.55;
uniform float fresnel_power = 5.0;
// Far water turns mirror-like so it carries the sky's hue into the horizon
// (avoids a grey band when the sky is warm and the water blue).
uniform float mirror_start = 150.0;
uniform float mirror_end = 1400.0;
uniform float mirror_strength : hint_range(0.0, 1.0) = 0.85;
uniform float horizon_fade_start = 220.0;
uniform float horizon_fade_end = 2400.0;
uniform float horizon_fade_curve = 0.8;

group_uniforms sparkle;
uniform float sparkle_intensity = 10.0;
uniform float sparkle_density : hint_range(0.0, 1.0) = 0.16;
uniform float sparkle_size = 0.16;
uniform float sparkle_scale = 1.6;
// Width of the sun reflection lobe (N.H) where glints appear.
uniform float glint_lobe : hint_range(0.5, 1.0) = 0.9;
// Glint normal: unboosted swell plus strongly exaggerated ripples, so the
// sun path breaks into many small sparkles.
uniform float glint_ripple_boost = 3.5;

group_uniforms lighting;
uniform float light_band_softness : hint_range(0.0, 0.5) = 0.12;
uniform float light_band_offset : hint_range(-1.0, 1.0) = -0.2;
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.25;
uniform float shadow_strength : hint_range(0.0, 1.0) = 0.5;
uniform float spec_strength = 5.0;
uniform float spec_size : hint_range(0.5, 1.0) = 0.9993;
uniform float spec_softness : hint_range(0.0, 0.1) = 0.0006;
// The cel sun highlight fades out this close to the camera (m), where it
// would cover a big chunk of the screen.
uniform float spec_near_fade = 9.0;

group_uniforms underside;
uniform vec3 underside_color : source_color = vec3(0.1, 0.5, 0.62);
uniform vec3 underside_window_tint : source_color = vec3(0.78, 1.0, 0.98);

// Driven by Ocean (every frame / once a second): leave these alone. The sky
// defaults mirror shaders/sky_stylized.gdshader.
group_uniforms scene;
uniform float ocean_time = 0.0;
uniform vec3 sun_direction = vec3(-0.38, 0.79, 0.48);
uniform vec3 sun_sky_color : source_color = vec3(1.0, 0.96, 0.82);
uniform float sun_halo = 0.35;
uniform vec3 sky_zenith : source_color = vec3(0.24, 0.55, 0.9);
uniform vec3 sky_mid : source_color = vec3(0.47, 0.75, 0.97);
uniform vec3 sky_horizon : source_color = vec3(0.8, 0.93, 1.0);
uniform vec3 sky_below : source_color = vec3(0.33, 0.62, 0.78);
uniform float total_amplitude = 0.4;
group_uniforms;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

varying vec2 v_base;
// Fragment -> light.
varying float v_spec;
varying float v_glint;
varying vec3 v_glint_normal;

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

// Value noise with analytic derivatives: (value, d/dx, d/dy).
vec3 noised(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	vec2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	float k = a - b - c + d;
	return vec3(a + (b - a) * u.x + (c - a) * u.y + k * u.x * u.y,
			du * (vec2(b - a, c - a) + k * u.yx));
}

// Sky gradient matching shaders/sky_stylized.gdshader (without clouds).
vec3 sky_color(vec3 d) {
	vec3 col;
	if (d.y >= 0.0) {
		col = mix(sky_horizon, sky_mid, smoothstep(0.0, 0.18, d.y));
		col = mix(col, sky_zenith, smoothstep(0.12, 0.85, d.y));
	} else {
		col = mix(sky_horizon, sky_below, smoothstep(0.0, 0.12, -d.y));
	}
	float sd = max(dot(d, sun_direction), 0.0);
	col += sun_sky_color * (pow(sd, 24.0) * sun_halo + pow(sd, 4.0) * sun_halo * 0.15);
	return col;
}

// Cheap animated caustic web: ridges where two drifting noise fields meet.
float caustic(vec2 p, float t) {
	vec2 q = p * caustic_scale;
	float a = vnoise(q + vec2(t * 0.31, t * 0.17));
	float b = vnoise(q * 1.37 + vec2(-t * 0.23, t * 0.29) + 17.3);
	float c = 1.0 - abs(a - b) * 4.0;
	return pow(clamp(c, 0.0, 1.0), 5.0);
}

// Sparse four-point star glints that twinkle.
float glints(vec2 p, float t, float size) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float r = hash12(cell);
	if (r > sparkle_density) {
		return 0.0;
	}
	vec2 jit = vec2(hash12(cell + 19.19), hash12(cell + 47.7)) * 0.5 + 0.25;
	vec2 d = abs(f - jit);
	float core = smoothstep(size, size * 0.2, length(d));
	float arms = smoothstep(size * 2.4, 0.0, d.x) * smoothstep(size * 0.22, 0.0, d.y)
			+ smoothstep(size * 2.4, 0.0, d.y) * smoothstep(size * 0.22, 0.0, d.x);
	float tw = 0.5 + 0.5 * sin(t * (2.2 + 3.0 * fract(r * 31.7)) + r * 60.0);
	return max(core, arms * 0.7) * tw * tw;
}

vec3 world_from_depth(vec2 uv, float raw, mat4 inv_proj, mat4 inv_view) {
	vec4 v = inv_proj * vec4(uv * 2.0 - 1.0, raw, 1.0);
	v.xyz /= v.w;
	return (inv_view * vec4(v.xyz, 1.0)).xyz;
}

void vertex() {
	// world_vertex_coords: VERTEX is the undisplaced world position (y = sea level).
	v_base = VERTEX.xz;
	VERTEX += ocean_offset(VERTEX.xz, ocean_lod_weights(VERTEX.xz));
}

void fragment() {
	float t = ocean_time;
	vec3 wpos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 to_cam = CAMERA_POSITION_WORLD - wpos;
	float frag_dist = length(to_cam);
	vec3 V = to_cam / frag_dist;
	float px = max(length(fwidth(v_base)), 1.0e-4);

	// --- Waves, per pixel at the undisplaced position (full detail) ---------
	vec4 th = ocean_theta(v_base);
	vec4 s = sin(th);
	vec4 c = cos(th);
	vec4 klen = sqrt(wave_kx * wave_kx + wave_kz * wave_kz);
	vec4 lambda = 6.2831853 / max(klen, vec4(1.0e-4));
	vec4 aa = vec4(1.0) - smoothstep(lambda * 0.04, lambda * 0.2, vec4(px));
	vec4 a = wave_amp * aa;
	float wave_h = dot(a, s);
	vec2 slope = vec2(dot(a * wave_kx, c), dot(a * wave_kz, c));
	vec4 pinch = (wave_hx * wave_kx + wave_hz * wave_kz) * aa;
	float h_norm = wave_h / max(total_amplitude, 0.01);
	// Slow, large patches where the swell reads stronger or calmer.
	float swell_n = vnoise(v_base * 0.0045 + vec2(t * 0.004, 0.0)) * 0.65 + vnoise(v_base * 0.013 + 7.7) * 0.35;
	float swell_k = mix(1.0, smoothstep(0.15, 0.85, swell_n) * 1.5 + 0.2, swell_variation);

	// Small ripples riding on the swell.
	float rt = t * ripple_speed;
	float ripple_fade = 1.0 - smoothstep(0.15, 1.2, px * ripple_scale * 2.0);
	vec2 ripple = vec2(0.0);
	if (ripple_fade > 0.0) {
		vec3 r1 = noised(v_base * ripple_scale + vec2(rt * 0.21, rt * 0.09));
		vec2 q2 = vec2(v_base.y, -v_base.x) * ripple_scale * 2.3 + vec2(-rt * 0.13, rt * 0.27);
		vec3 r2 = noised(q2);
		vec2 rg = r1.yz * ripple_scale + vec2(-r2.z, r2.y) * ripple_scale * 2.3 * 0.55;
		ripple = rg * ripple_strength * ripple_fade;
	}

	float ny = 1.0 - dot(pinch, s);
	vec2 boosted = slope * normal_boost * swell_k;

	float hz = pow(smoothstep(horizon_fade_start, horizon_fade_end, frag_dist), horizon_fade_curve);

	if (!FRONT_FACING) {
		// Seen from below: a bright Snell's window overhead, total internal
		// reflection (deep teal) toward the sides.
		vec3 N = normalize(vec3(-boosted.x - ripple.x, ny, -boosted.y - ripple.y));
		vec3 Nd = -N;
		float cos_v = clamp(dot(V, Nd), 0.0, 1.0);
		float window = smoothstep(0.6, 0.74, cos_v);
		vec2 uv_up = clamp(SCREEN_UV + Nd.xz * 0.04, vec2(0.0), vec2(1.0));
		vec3 above = texture(screen_tex, uv_up).rgb * underside_window_tint;
		float shimmer = caustic(v_base * 1.3, t * 1.4) * 0.35;
		vec3 col = mix(underside_color * (0.85 + shimmer), above, window);
		NORMAL = normalize((VIEW_MATRIX * vec4(Nd, 0.0)).xyz);
		ALBEDO = vec3(0.0);
		EMISSION = col;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = 1.0;
		v_spec = 0.0;
		v_glint = 0.0;
		v_glint_normal = NORMAL;
	} else {
		// --- What lies under the water --------------------------------------
		float raw = texture(depth_tex, SCREEN_UV).r;
		vec3 floor_ws = world_from_depth(SCREEN_UV, raw, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
		float depth_v = max(wpos.y - floor_ws.y, 0.0);

		// Calmer, flatter-looking water near the shore.
		float calm = mix(shore_calm, 1.0, smoothstep(0.0, shore_calm_depth, depth_v));
		vec3 n_wave = normalize(vec3(-boosted.x * calm, ny, -boosted.y * calm));
		vec3 N = normalize(n_wave + vec3(-ripple.x, 0.0, -ripple.y));
		vec3 n_glint = normalize(vec3(-slope.x * calm - ripple.x * glint_ripple_boost, ny, -slope.y * calm - ripple.y * glint_ripple_boost));

		// Refraction: nudge the lookup by the surface slope, but never pull in
		// things that stand in front of the water.
		float refr_fade = smoothstep(0.0, 0.6, depth_v) * (1.0 - hz);
		vec2 offs = (N.xz - n_wave.xz * 0.6) * refraction_strength * refr_fade / max(1.0, frag_dist * 0.08);
		vec2 ruv = clamp(SCREEN_UV + offs, vec2(0.001), vec2(0.999));
		float rraw = texture(depth_tex, ruv).r;
		vec3 rfloor = world_from_depth(ruv, rraw, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
		if (rfloor.y > wpos.y) {
			ruv = SCREEN_UV;
			rfloor = floor_ws;
		}
		float thick = max(distance(CAMERA_POSITION_WORLD, rfloor) - frag_dist, 0.0);
		float rdepth = max(wpos.y - rfloor.y, 0.0);
		vec3 behind = texture(screen_tex, ruv).rgb;
		behind *= mix(vec3(1.0), seabed_tint, smoothstep(0.0, seabed_tint_depth, thick));
		if (rdepth < caustic_depth && hz < 1.0) {
			float ca = caustic(rfloor.xz, t) * (1.0 - smoothstep(0.0, caustic_depth, rdepth)) * smoothstep(0.02, 0.25, rdepth);
			behind *= 1.0 + ca * caustic_strength * (1.0 - hz);
		}

		// --- Water color: soft depth bands, crest tint, gentle variation ------
		float big_n = vnoise(wpos.xz * 0.025 + vec2(t * 0.01, 0.0)) * 0.6 + vnoise(wpos.xz * 0.11 - vec2(0.0, t * 0.02)) * 0.4;
		float dv = max(depth_v, thick * view_depth_mix) * (1.0 + (big_n - 0.5) * color_noise * 1.6);
		vec3 water = mix(shallow_color, mid_color, smoothstep(shallow_depth * 0.3, mid_depth, dv));
		water = mix(water, deep_color, smoothstep(mid_depth * 0.8, deep_depth, dv));
		float crest_k = smoothstep(0.0, 0.9, h_norm) * crest_tint * swell_k * calm;
		water = mix(water, crest_color, clamp(crest_k, 0.0, 1.0));
		water *= 1.0 - trough_darken * smoothstep(0.0, -0.8, h_norm) * swell_k * calm;
		water *= 1.0 + (big_n - 0.5) * color_noise * 0.25;

		float opacity = 1.0 - exp(-thick * opacity_absorb);
		opacity = mix(edge_opacity, 1.0, opacity);

		// --- Foam --------------------------------------------------------------
		// Derivatives first (they must be taken outside the branches below).
		float aa_d = min(fwidth(depth_v), 0.02) + 0.003;
		float bw = fwidth(depth_v) / band_spacing;
		float shore = 0.0;
		if (depth_v < band_reach + foam_width * 2.0) {
			float fn = vnoise(wpos.xz * 0.7 + vec2(t * 0.06, -t * 0.05));
			float fn2 = vnoise(wpos.xz * 1.9 + vec2(-t * 0.09, t * 0.07));
			// Lobed shoreline foam that surges in and out, plus a crisp contact
			// line hugging the waterline everywhere.
			float surge = 0.5 + 0.5 * sin(t * 0.85 + fn * 5.0 + (wpos.x - wpos.z) * 0.04);
			float lobes = smoothstep(0.25, 0.8, fn * 0.75 + fn2 * 0.25);
			float edge_w = foam_width * mix(1.0, 0.2 + 1.7 * lobes, foam_wobble) * (0.5 + surge);
			float edge = 1.0 - smoothstep(edge_w - aa_d, edge_w + aa_d, depth_v);
			edge = max(edge, 1.0 - smoothstep(contact_width, contact_width + aa_d, depth_v));
			// Cartoon foam lines drifting toward the shore, broken up by noise.
			float bphase = depth_v / band_spacing + t * band_speed + (fn2 - 0.5) * 0.8 + fn * 0.4;
			float bf = fract(bphase);
			float aa_b = min(bw, 0.12) * 1.5 + 0.02;
			float band = smoothstep(0.0, aa_b, bf) * (1.0 - smoothstep(band_width, band_width + aa_b, bf));
			band *= 1.0 - smoothstep(band_reach * 0.3, band_reach, depth_v);
			band *= smoothstep(band_breakup - 0.1, band_breakup + 0.1, fn2 * 0.55 + fn * 0.45 + 0.12);
			band *= smoothstep(edge_w, edge_w + 0.05, depth_v);
			band *= 1.0 - smoothstep(0.25, 0.6, bw);
			shore = max(edge, band * 0.85);
		}
		float crest = 0.0;
		float crest_h = h_norm * swell_k * calm;
		if (crest_foam > 0.0 && crest_h > crest_foam_start && px < 0.3) {
			float cn = vnoise(v_base * 0.8 + vec2(t * 0.15, t * 0.1)) * 0.6 + vnoise(v_base * 2.1 - vec2(t * 0.2, 0.0)) * 0.4;
			crest = smoothstep(crest_foam_start, 1.0, crest_h) * smoothstep(0.55, 0.7, cn);
			crest *= 1.0 - smoothstep(0.08, 0.3, px);
		}
		float foam = clamp(shore + crest * crest_foam, 0.0, 1.0);
		foam *= 1.0 - hz;

		// --- Fresnel sky reflection -----------------------------------------
		vec3 n_refl = normalize(mix(vec3(0.0, 1.0, 0.0), N, reflection_normal));
		float ndv = clamp(dot(n_refl, V), 0.0, 1.0);
		float fres = fresnel_strength * pow(1.0 - ndv, fresnel_power);
		fres = mix(fres, max(fres, mirror_strength), smoothstep(mirror_start, mirror_end, frag_dist));
		vec3 R = reflect(-V, n_refl);
		R.y = max(R.y, 0.0);
		vec3 refl = sky_color(normalize(R));

		vec3 albedo = water * opacity * (1.0 - fres);
		vec3 emission = behind * (1.0 - opacity) * (1.0 - fres) + refl * fres;
		albedo = mix(albedo, foam_color, foam);
		emission = emission * (1.0 - foam) + foam_color * foam * foam_emission;

		// Horizon: melt into the sky color behind the far edge. The angle below
		// the horizon is compressed: the real edge sits within a degree or two
		// of it, and steeper below-horizon sky tints would muddy the fade.
		vec3 horizon = sky_color(normalize(vec3(-V.x, min(-V.y, 0.0) * 0.35, -V.z)));
		albedo *= 1.0 - hz;
		emission = mix(emission, horizon, hz);

		// Sun glints: two scales so they stay crisp near and do not alias far.
		float gs = px * sparkle_scale;
		float near_g = 0.0;
		float far_g = 0.0;
		if (gs < 0.18) {
			near_g = glints(v_base * sparkle_scale + vec2(rt * 0.1, 0.0), t, sparkle_size) * (1.0 - smoothstep(0.06, 0.18, gs));
		}
		if (gs > 0.05 && gs * 0.22 < 0.7) {
			far_g = glints(v_base * sparkle_scale * 0.22 + 31.0, t * 0.8, sparkle_size * 1.2);
			far_g *= smoothstep(0.05, 0.15, gs) * (1.0 - smoothstep(0.25, 0.7, gs * 0.22));
		}
		v_glint = (near_g + far_g) * (1.0 - foam) * (1.0 - hz);
		v_spec = (1.0 - foam) * (1.0 - hz) * smoothstep(spec_near_fade * 0.4, spec_near_fade, frag_dist);
		v_glint_normal = normalize((VIEW_MATRIX * vec4(n_glint, 0.0)).xyz);

		NORMAL = normalize((VIEW_MATRIX * vec4(N, 0.0)).xyz);
		ALBEDO = albedo;
		EMISSION = emission;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
		ALPHA = 1.0;
	}
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(light_band_offset - light_band_softness, light_band_offset + light_band_softness, ndl);
	float sh = 1.0;
	if (LIGHT_IS_DIRECTIONAL) {
		sh = mix(1.0 - shadow_strength, 1.0, smoothstep(0.5 - shadow_softness, 0.5 + shadow_softness, ATTENUATION));
	} else {
		sh = ATTENUATION;
	}
	DIFFUSE_LIGHT += LIGHT_COLOR * band * sh / PI;

	// Sun highlight and glints use the ripple-dominated normal so the sun
	// path breaks into small crisp shapes instead of big blobs.
	vec3 h = normalize(LIGHT + VIEW);
	float ndh = dot(v_glint_normal, h);
	float lit = band * smoothstep(0.35, 0.65, sh);
	float spec = smoothstep(spec_size - spec_softness, spec_size + spec_softness, ndh) * spec_strength * v_spec;
	float lobe = smoothstep(glint_lobe, mix(glint_lobe, 1.0, 0.7), ndh);
	float glint = v_glint * sparkle_intensity * lobe;
	if (!LIGHT_IS_DIRECTIONAL) {
		glint = 0.0;
	}
	SPECULAR_LIGHT += LIGHT_COLOR * (spec + glint) * lit / PI;
}
