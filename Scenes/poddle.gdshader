shader_type canvas_item;

uniform sampler2D mask_texture;
uniform sampler2D reflection_texture;

void fragment() {
    // Sample the mask texture and reflection texture
    vec4 mask_color = texture(mask_texture, UV);
    vec4 reflection_color = texture(reflection_texture, UV);

    // If the mask color is black, discard the fragment (make it transparent)
    if (mask_color == vec4(1.0, 1.0, 1.0, 1.0)) {
        discard;
    }

    // Otherwise, set the color to the reflection color
    COLOR = reflection_color;
}
