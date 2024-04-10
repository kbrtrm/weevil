shader_type canvas_item;

void fragment() {
    // Sample the player's sprite texture
    vec4 player_color = texture(TEXTURE, UV);

    // Output the color of the player's sprite
    COLOR = player_color;
}