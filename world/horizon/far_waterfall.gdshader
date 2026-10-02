shader_type spatial;
render_mode unshaded, cull_disabled;
// A far-off waterfall (HorizonIsland.waterfall): pale water with bright
// streaks pouring down, lighter toward the churned foot. UV.y runs top (0)
// to bottom (1). Fog still applies, so it hazes with the island.

uniform vec4 water_color : source_color = vec4(0.62, 0.85, 0.95, 1.0);
uniform vec4 foam_color : source_color = vec4(0.97, 0.99, 1.0, 1.0);
uniform float streaks = 9.0;
uniform float speed = 0.55;

void fragment() {
	float wobble = sin(UV.x * 21.0) * 0.12 + sin(UV.x * 7.0 + 1.3) * 0.08;
	float s = fract(UV.y * streaks - TIME * speed + wobble);
	float streak = smoothstep(0.45, 0.62, s) * (1.0 - smoothstep(0.82, 1.0, s));
	float edge = smoothstep(0.0, 0.18, UV.x) * smoothstep(1.0, 0.82, UV.x);
	vec3 c = mix(water_color.rgb, foam_color.rgb, clamp(streak * 0.75 + UV.y * 0.35, 0.0, 1.0));
	ALBEDO = mix(water_color.rgb * 0.85, c, edge);
}
