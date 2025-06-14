shader_type canvas_item;

uniform float x_rot : hint_range(-1.5, 1.5) = 0.0;
uniform float y_rot : hint_range(-1.5, 1.5) = 0.0;
uniform float z_rot : hint_range(-1.5, 1.5) = 0.0;
uniform float z_distance : hint_range(-2.0, 2.0, 0.01) = 0.0;
uniform vec2 vanish_point : hint_range(0.0, 1.0) = vec2(0.5, 0.5);
uniform float lift_amount : hint_range(0.0, 100.0) = 0.0;
uniform float hover_scale : hint_range(0.5, 2.0) = 1.0;

mat4 rotationMatrix(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat4(vec4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0),
                vec4(oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0),
                vec4(oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0),
                vec4(0.0,                                0.0,                                0.0,                                1.0));
}

vec4 transform_perspective(vec2 uv) {
    // Center UV coordinates around 0
    vec2 centered_uv = (uv - 0.5) * 2.0;
    
    // Apply scaling
    centered_uv *= hover_scale;
    
    // Create 3D position
    vec4 pos = vec4(centered_uv.x, centered_uv.y, z_distance, 1.0);
    
    // Apply rotations
    mat4 rot_x = rotationMatrix(vec3(1.0, 0.0, 0.0), x_rot);
    mat4 rot_y = rotationMatrix(vec3(0.0, 1.0, 0.0), y_rot);
    mat4 rot_z = rotationMatrix(vec3(0.0, 0.0, 1.0), z_rot);
    
    pos = rot_z * rot_y * rot_x * pos;
    
    // Apply perspective projection
    float perspective_factor = 1.0 / (1.0 - pos.z * 0.5);
    pos.xy *= perspective_factor;
    
    // Convert back to UV coordinates
    pos.xy = (pos.xy / 2.0) + 0.5;
    
    return pos;
}

void vertex() {
    // Apply lift effect by modifying the vertex position
    VERTEX.y -= lift_amount;
}

void fragment() {
    vec4 transformed = transform_perspective(UV);
    
    // Check if we're outside the texture bounds
    if (transformed.x < 0.0 || transformed.x > 1.0 || transformed.y < 0.0 || transformed.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent
    } else {
        COLOR = texture(TEXTURE, transformed.xy);
    }
}