shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// A far-off curtain of rain (HorizonStormpeak): thin translucent streaks
// falling down a ribbon or ring. UV.x runs around, UV.y top (0) to bottom
// (1); the curtain fades in below the cloud.

uniform vec4 tint : source_color = vec4(0.6, 0.66, 0.76, 1.0);
uniform float opacity = 0.4;
uniform float columns = 90.0;
uniform float speed = 1.4;

void fragment() {
	float id = floor(UV.x * columns);
	float c = fract(UV.x * columns);
	float streak = smoothstep(0.0, 0.1, c) * (1.0 - smoothstep(0.18, 0.3, c));
	float s = fract(UV.y * 5.0 - TIME * speed + id * 0.37);
	float fall = smoothstep(0.1, 0.45, s) * (1.0 - smoothstep(0.65, 1.0, s));
	ALBEDO = tint.rgb;
	ALPHA = opacity * (0.3 + 0.7 * streak * fall) * smoothstep(0.0, 0.2, UV.y);
}
