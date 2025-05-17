shader_type canvas_item;

uniform float circle_size : hint_range(0.0, 1.0) = 0.0;
uniform vec2 center = vec2(0.5, 0.5);

void fragment() {
    float ratio = SCREEN_PIXEL_SIZE.x / SCREEN_PIXEL_SIZE.y;
    vec2 scaled_UV = UV;
    scaled_UV.y *= ratio;
    vec2 center_scaled = center;
    center_scaled.y *= ratio;
    
    float dist = distance(scaled_UV, center_scaled);
    
    // For transition in: circle_size goes from 0.0 to 1.0
    // For transition out: circle_size goes from 1.0 to 0.0
    float alpha = step(circle_size, dist);
    
    COLOR = vec4(COLOR.rgb, alpha);
}