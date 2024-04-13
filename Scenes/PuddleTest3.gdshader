shader_type canvas_item;

uniform sampler2D player_texture;

void fragment() {
    // Flip UV vertically
    vec2 uv = FRAGCOORD.xy / SCREEN_PIXEL_SIZE.xy;
    uv.y = 1.0 - uv.y;

    // Sample from the player texture and assign to color
    COLOR = texture(player_texture, uv);
}
