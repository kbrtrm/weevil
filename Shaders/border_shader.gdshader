// border_shader.gdshader
shader_type canvas_item;

uniform vec4 border_color : source_color = vec4(1.0, 0.7, 0.0, 1.0);
uniform float border_width : hint_range(0, 20) = 4.0;

void fragment() {
    vec4 original_color = texture(TEXTURE, UV);

    // Calculate distance to the nearest edge
    float distance_to_edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));

    // Convert border width from pixels to UV space (assuming a typical card size)
    float border_size = border_width / 100.0;

    // Mix the original color with the border color based on distance
    if (distance_to_edge < border_size) {
        // Apply border color only to non-transparent pixels of the original texture
        if (original_color.a > 0.0) {
            // Smoothstep for anti-aliased border
            float border_factor = smoothstep(0.0, border_size, distance_to_edge);
            COLOR = mix(border_color, original_color, border_factor);
        } else {
            // Keep transparent pixels transparent
            COLOR = original_color;
        }
    } else {
        // Use original color for non-border areas
        COLOR = original_color;
    }
}