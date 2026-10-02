shader_type canvas_item;
render_mode blend_disabled, unshaded;
// GPU side of the ocean wave check (ocean_wave_check.gd): evaluates the
// exact ocean_offset() used by ocean.gdshader's vertex() for a grid of
// points and writes the raw float bits to RGBA8 so the CPU can compare
// bit-for-bit. Five pixels per point: dx, dy, dz, point.x, point.z.

#include "res://world/ocean/ocean_waves.gdshaderinc"

uniform vec2 origin = vec2(0.0);
uniform vec2 spacing = vec2(1.0);

vec4 encode(float v) {
	uint u = floatBitsToUint(v);
	return vec4(float(u & 255u), float((u >> 8u) & 255u), float((u >> 16u) & 255u), float(u >> 24u)) / 255.0;
}

void fragment() {
	ivec2 pix = ivec2(floor(FRAGCOORD.xy));
	int comp = pix.x % 5;
	vec2 p = origin + vec2(float(pix.x / 5), float(pix.y)) * spacing;
	vec3 o = ocean_offset(p, ocean_lod_weights(p));
	float v = p.y;
	if (comp == 0) {
		v = o.x;
	} else if (comp == 1) {
		v = o.y;
	} else if (comp == 2) {
		v = o.z;
	} else if (comp == 3) {
		v = p.x;
	}
	COLOR = encode(v);
}
