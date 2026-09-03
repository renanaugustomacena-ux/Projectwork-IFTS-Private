// Simple Grayscale Shader for CanvasItem
// Author: SimranZenov
// Source: https://godotshaders.com/shader/simple-grayscale-shader-for-canvasitem/
// License: CC0 (verified 2026-09-03 on the source page: "The shader code and all code snippets in this post are under CC0 license and can be used freely without the author's permission.")
// Downloaded: 2026-09-03

shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable;
uniform float saturation : hint_range(0.0, 1.0) = 1.0; // 0 = grayscale, 1 = full color

void fragment() {
	vec4 tex = texture(screen_texture, SCREEN_UV);
	float gray = dot(tex.rgb, vec3(0.299, 0.587, 0.114)); // luminance weights
	vec3 result = mix(vec3(gray), tex.rgb, saturation);
	COLOR = vec4(result, tex.a);
}
