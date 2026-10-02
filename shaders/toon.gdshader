shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// General stylized material. Multiplies vertex colors so procedural meshes
// can share one material per finish (matte, glossy, metal).

#include "res://shaders/includes/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform bool use_vertex_color = true;
uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float roughness : hint_range(0.0, 1.0) = 0.85;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 16.0) = 0.0;
// Brief white flash (hits, invulnerability blink).
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 c = albedo * texture(albedo_texture, UV);
	if (use_vertex_color) {
		c *= COLOR;
	}
	ALBEDO = mix(c.rgb, vec3(1.0), flash);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	EMISSION = emission_color.rgb * emission_energy + vec3(flash * 0.6);
}
