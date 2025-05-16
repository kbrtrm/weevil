shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float hardness : hint_range(0.0, 1.0) = 0.5;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    // Calculate distance from center
    vec2 uv = UV - center;
    float dist = length(uv);

    // Create the wipe effect - values closer to center appear first
    float circle = smoothstep(progress, progress + hardness, dist);

    // Apply the effect to the alpha channel
    COLOR = vec4(1.0, 1.0, 1.0, circle);
}