shader_type canvas_item;

uniform vec2 screen_size;
uniform vec2 offset;

void fragment() {
    // Calculate the reciprocal of the screen size
    vec2 inv_screen_size = vec2(1.0 / screen_size.x, 1.0 / screen_size.y);

    // Calculate the new UV coordinates with the offset
    vec2 uv = SCREEN_UV.xy + offset * inv_screen_size;

    // Sample the texture at the new UV coordinates
    vec4 color = texture(TEXTURE, uv);

    // Output the color
    COLOR = color;
}
