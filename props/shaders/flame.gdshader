shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded, shadows_disabled;
// Cartoon flame for torches and braziers. A fresnel term paints a bright core
// where the surface faces the camera and an orange rim at the silhouette, so
// one teardrop mesh reads as a classic two-tone flame from every angle. The
// tip warms toward red and the vertices flicker. UV.y = height weight
// (0 at the base, 1 at the tip), as written by PropBuilder.lathe().

uniform vec4 core_color : source_color = vec4(1.0, 0.84, 0.32, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.42, 0.08, 1.0);
uniform vec4 tip_color : source_color = vec4(0.95, 0.22, 0.08, 1.0);
uniform float energy = 1.3;
uniform float core_size : hint_range(0.0, 1.0) = 0.68;
uniform float flicker_speed = 8.0;
uniform float wobble = 0.05;

void vertex() {
	float w = clamp(UV.y, 0.0, 1.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	float t = TIME * flicker_speed + o.x * 1.7 + o.z * 2.3;
	VERTEX.x += (sin(t + VERTEX.y * 9.0) * 0.6 + sin(t * 1.9 + 1.3) * 0.4) * wobble * w;
	VERTEX.z += (cos(t * 1.13 + VERTEX.y * 7.0) * 0.6 + cos(t * 2.3) * 0.4) * wobble * w;
	VERTEX.y *= 1.0 + (sin(t * 1.37) * 0.08 + sin(t * 3.1) * 0.04) * w;
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = smoothstep(core_size - 0.15, core_size + 0.15, facing) * (1.0 - smoothstep(0.5, 0.9, UV.y));
	vec3 col = mix(edge_color.rgb, tip_color.rgb, smoothstep(0.45, 1.0, UV.y));
	col = mix(col, core_color.rgb, core);
	ALBEDO = col * energy;
}
