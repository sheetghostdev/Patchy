// Shared ocean wave math: four Gerstner (trochoidal) waves evaluated in
// world space. Included by ocean.gdshader (vertex displacement + per-pixel
// normals), underwater.gdshader / underwater_fog.gdshader (wobbly waterline)
// and the GPU-vs-CPU check in world/ocean/tests/.
//
// Every uniform here is written by Ocean (world/ocean/ocean.gd), which also
// mirrors ocean_offset() on the CPU (Ocean.get_wave_offset) for buoyancy and
// swimming. Keep the two in sync: same constants, same operation order.
//
// Time: the waves never read TIME. Ocean advances its own clock and uploads
// wave_phase = mod(omega * time, TAU) per wave every frame (computed in double
// precision on the CPU), so the GPU and CPU agree exactly and the waves stay
// precise however long the game runs.

// Wave vectors (direction * wavenumber, rad/m) of the four waves.
uniform vec4 wave_kx = vec4(0.0);
uniform vec4 wave_kz = vec4(0.0);
// Vertical amplitudes (m).
uniform vec4 wave_amp = vec4(0.0);
// Horizontal (Gerstner) displacement amplitude * direction, per wave (m).
uniform vec4 wave_hx = vec4(0.0);
uniform vec4 wave_hz = vec4(0.0);
// Per-wave phase (rad), advanced by Ocean every frame.
uniform vec4 wave_phase = vec4(0.0);
// Geometry LOD: each wave flattens between these distances (m) from
// lod_center (the camera's xz), so coarse far rings never alias.
uniform vec4 wave_fade_near = vec4(1.0e6);
uniform vec4 wave_fade_far = vec4(2.0e6);
uniform vec2 lod_center = vec2(0.0);

// Per-wave weights used by the vertex displacement at undisplaced point p.
vec4 ocean_lod_weights(vec2 p) {
	float d = distance(p, lod_center);
	return vec4(1.0) - smoothstep(wave_fade_near, wave_fade_far, vec4(d));
}

vec4 ocean_theta(vec2 p) {
	return wave_kx * p.x + wave_kz * p.y - wave_phase;
}

// Displacement (dx, dy, dz) of the undisplaced surface point p (world xz),
// with per-wave weights w (ocean_lod_weights, or vec4(1.0) for full detail).
vec3 ocean_offset(vec2 p, vec4 w) {
	vec4 th = ocean_theta(p);
	vec4 s = sin(th);
	vec4 c = cos(th);
	return vec3(dot(wave_hx * w, c), dot(wave_amp * w, s), dot(wave_hz * w, c));
}

// Approximate surface height offset at a *displaced* world xz (one
// fixed-point step undoing the horizontal motion). Good to ~1 cm; the CPU
// uses Newton iterations for exact gameplay queries.
float ocean_height_at(vec2 world_xz) {
	vec3 o = ocean_offset(world_xz, vec4(1.0));
	vec2 p = world_xz - o.xz;
	o = ocean_offset(p, vec4(1.0));
	p = world_xz - o.xz;
	return ocean_offset(p, vec4(1.0)).y;
}
