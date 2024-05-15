shader_type canvas_item;

uniform float blue = 1.0;

void fragment(){
	COLOR = texture(TEXTURE, UV);
	COLOR.b = 0.5;
	COLOR.r = 0.5;
	COLOR.g = 0.5;
}

