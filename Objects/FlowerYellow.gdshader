shader_type canvas_item;

void fragment() {
	if (COLOR.a < 0.5) discard;
	COLOR = vec4(0,0,0,0.5);
}
