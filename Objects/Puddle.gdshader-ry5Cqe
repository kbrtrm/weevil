shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
    vec2 uv = SCREEN_UV; // Get screen space coordinates

    // Flip the y-coordinate to reflect vertically
    uv.y = 1.0 - uv.y;

    // Sample the scene texture using the reflected UV
    vec4 reflected_color = texture(SCREEN_TEXTURE, uv);

    // Output the reflected color
    COLOR = reflected_color;
}