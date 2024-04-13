shader_type canvas_item;

// Declare a uniform variable to hold the texture of the specific node's sprite
uniform sampler2D sprite_texture;

void fragment() {
    // Sample from the sprite texture using the UV coordinates
    COLOR = texture(sprite_texture, FRAGCOORD.xy / SCREEN_PIXEL_SIZE.xy);
}
