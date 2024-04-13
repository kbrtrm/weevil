shader_type canvas_item;

uniform sampler2D texture1;

void fragment() {
  COLOR = texture(TEXTURE, UV); // Read from texture
  COLOR.b = .5;
}
