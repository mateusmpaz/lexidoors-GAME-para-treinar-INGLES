shader_type spatial;
render_mode diffuse_burley;

uniform vec4 wood_tint : source_color = vec4(0.48, 0.25, 0.105, 1.0);
uniform float highlight = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * vec2(12.0, 2.0);
	float warp = noise(p * 0.7) * 1.7;
	float grain = sin((p.x + warp) * 21.0 + noise(p * vec2(2, 0.4)) * 5.0);
	float fine = noise(UV * vec2(260.0, 5.0));
	float boards = noise(UV * vec2(8.0, 1.0));
	float value = 0.78 + grain * 0.065 + fine * 0.16 + boards * 0.15;
	ALBEDO = wood_tint.rgb * value * (1.0 + highlight * 0.18);
	ROUGHNESS = 0.73 + fine * 0.12;
	SPECULAR = 0.25;
}
