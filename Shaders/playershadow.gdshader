shader_type canvas_item;

void fragment() {
    // Get the color of the current pixel
    vec4 color = texture(TEXTURE, UV);

    // Check if the pixel is not transparent (alpha > 0)
    if (color.a > 0.0) {
        // Replace the color with black, but keep the original alpha
        color.rgb = vec3(0.0);
		color.a = .35;
    }

    // Output the modified color
    COLOR = color;
}