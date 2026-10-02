shader_type sky;
// Storybook sky: painted horizon gradient, a soft sun with a warm halo and
// chunky drifting clouds with simple light/shade bands. Clouds are skipped in
// the radiance (cubemap) pass so ambient lighting stays stable and cheap.

uniform vec3 zenith_color : source_color = vec3(0.24, 0.55, 0.9);
uniform vec3 mid_color : source_color = vec3(0.47, 0.75, 0.97);
uniform vec3 horizon_color : source_color = vec3(0.8, 0.93, 1.0);
uniform vec3 below_color : source_color = vec3(0.33, 0.62, 0.78);
uniform vec3 sun_color : source_color = vec3(1.0, 0.96, 0.82);
uniform float sun_size : hint_range(0.0, 0.2) = 0.035;
uniform float sun_halo : hint_range(0.0, 2.0) = 0.35;
uniform vec3 cloud_light : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.74, 0.83, 0.95);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.56;
uniform float cloud_scale = 1.4;
uniform float cloud_speed = 0.006;
uniform float cloud_edge : hint_range(0.001, 0.3) = 0.05;

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

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.55;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(13.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		float t1 = smoothstep(0.0, 0.18, h);
		float t2 = smoothstep(0.12, 0.85, h);
		col = mix(horizon_color, mid_color, t1);
		col = mix(col, zenith_color, t2);
	} else {
		col = mix(horizon_color, below_color, smoothstep(0.0, 0.12, -h));
	}

	float sd = dot(d, LIGHT0_DIRECTION);
	if (LIGHT0_ENABLED) {
		float disc = smoothstep(1.0 - sun_size, 1.0 - sun_size * 0.6, sd);
		float halo = pow(max(sd, 0.0), 24.0) * sun_halo + pow(max(sd, 0.0), 4.0) * sun_halo * 0.15;
		col += sun_color * halo;
		col = mix(col, sun_color * 1.6, disc);
	}

	if (!AT_CUBEMAP_PASS && h > 0.0) {
		vec2 uv = d.xz / (h + 0.22) * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(uv);
		float c = smoothstep(cloud_coverage, cloud_coverage + cloud_edge, n);
		float lit = smoothstep(cloud_coverage + 0.02, cloud_coverage + 0.22, fbm(uv + vec2(0.06, 0.04)));
		vec3 cc = mix(cloud_shade, cloud_light, lit);
		cc += sun_color * pow(max(sd, 0.0), 6.0) * 0.25;
		float fade = smoothstep(0.02, 0.2, h);
		col = mix(col, cc, c * fade);
	}
	COLOR = col;
}
