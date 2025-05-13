shader_type canvas_item;

// Controls the sharpness of the pixel edges
uniform float pixel_sharpness : hint_range(0.0, 1.0) = 0.1;
// Controls the texture size (usually your sprite's original dimensions)
uniform vec2 texture_size = vec2(90.0, 124.0);

void fragment() {
    // Get the current UV coordinates
    vec2 uv = UV;

    // Calculate the pixel grid based on texture size
    vec2 pixel_size = 1.0 / texture_size;

    // Calculate the center of the current pixel
    vec2 pixel_center = floor(uv / pixel_size) * pixel_size + pixel_size * 0.5;

    // Calculate the distance from the current UV to the pixel center
    vec2 dist_to_center = abs(uv - pixel_center) / pixel_size;

    // Create a weight based on the distance to the center
    // This helps maintain sharper edges while still allowing some anti-aliasing
    float weight = 1.0 - smoothstep(0.0, pixel_sharpness, max(dist_to_center.x, dist_to_center.y));

    // Sample the texture at the pixel center and at the actual UV
    vec4 color_center = texture(TEXTURE, pixel_center);
    vec4 color_actual = texture(TEXTURE, uv);

    // Blend between the actual color and the center color based on the weight
    COLOR = mix(color_actual, color_center, weight);
}