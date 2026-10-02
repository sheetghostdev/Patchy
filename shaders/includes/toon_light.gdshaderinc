// Soft cel lighting shared by Patchy's stylized materials (spec §8).
// Two broad bands with soft edges, shadows folded into the band, a gentle
// rim, and a small controlled highlight. Ambient light (sky/environment)
// fills the shadow side, so shadows read as tinted rather than black.

uniform float band_softness : hint_range(0.0, 0.5) = 0.07;
uniform float band_offset : hint_range(-1.0, 1.0) = -0.08;
uniform float shadow_softness : hint_range(0.0, 0.5) = 0.22;
// Keeps a hint of form inside the lit band (0 = flat cel, 1 = lambert).
uniform float form_shading : hint_range(0.0, 1.0) = 0.22;
uniform float rim_strength : hint_range(0.0, 2.0) = 0.22;
uniform float rim_width : hint_range(0.0, 1.0) = 0.38;
uniform float spec_strength : hint_range(0.0, 2.0) = 0.1;
uniform float spec_size : hint_range(0.5, 1.0) = 0.94;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(band_offset - band_softness, band_offset + band_softness, ndl);
	float lit;
	if (LIGHT_IS_DIRECTIONAL) {
		float sh = smoothstep(0.5 - shadow_softness, 0.5 + shadow_softness, ATTENUATION);
		lit = band * sh;
	} else {
		lit = band * ATTENUATION;
	}
	float form = mix(1.0, clamp(ndl * 0.5 + 0.5, 0.0, 1.0), form_shading);
	DIFFUSE_LIGHT += LIGHT_COLOR * lit * form / PI;

	float fres = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(1.0 - rim_width, 1.0, fres) * (0.35 + 0.65 * lit);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * rim_strength / PI;

	vec3 h = normalize(LIGHT + VIEW);
	float spec = smoothstep(spec_size - 0.012, spec_size + 0.012, dot(NORMAL, h));
	SPECULAR_LIGHT += LIGHT_COLOR * spec * spec_strength * lit / PI;
}
