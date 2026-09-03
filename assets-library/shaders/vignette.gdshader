// Vignette
// Author: Lu
// Source: https://godotshaders.com/shader/vignette-3/
// License: CC0 (verified 2026-09-03 on the source page: "The shader code and all code snippets in this post are under CC0 license and can be used freely without the author's permission.")
// Downloaded: 2026-09-03

shader_type canvas_item;

uniform float outerRadius : hint_range(0.0, 5.0) = 1.0;
uniform float MainAlpha : hint_range(0.0, 1.0) = 1.0;
uniform vec4 vignette_color: source_color;

void fragment() {
	float x = abs(UV.x-.5)*2.0;
	float y = abs(UV.y-.5)*2.0;
	float v = (sqrt((x*x)+(y*y))/outerRadius);
	COLOR = vec4(vignette_color.rgb,v*MainAlpha);
}
