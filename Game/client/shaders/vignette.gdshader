// 暗角(电影感)：屏幕四周渐暗，中心透明。挂在全屏 ColorRect 上。
// 参数可在编辑器 ShaderMaterial 里调：strength 强度、radius 起始半径、color 暗角颜色。
shader_type canvas_item;

uniform float strength : hint_range(0.0, 2.0) = 1.1;
uniform float radius : hint_range(0.0, 1.0) = 0.72;
uniform float softness : hint_range(0.01, 1.0) = 0.55;
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	vec2 d = UV - vec2(0.5);
	float dist = length(d) * 1.41421356; // 0(中心) → 1(角落)
	float v = smoothstep(radius, radius + softness, dist) * strength;
	COLOR = vec4(tint.rgb, clamp(v, 0.0, 1.0));
}
