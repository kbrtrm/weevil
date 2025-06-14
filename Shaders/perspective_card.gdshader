shader_type canvas_item;

uniform float x_rot : hint_range(-1.5, 1.5) = 0.0;
uniform float y_rot : hint_range(-1.5, 1.5) = 0.0;
uniform float z_rot : hint_range(-1.5, 1.5) = 0.0;
uniform float z_distance : hint_range(-2.0, 2.0) = 0.0;
uniform float lift_amount : hint_range(0.0, 100.0) = 0.0;
uniform float hover_scale : hint_range(0.5, 2.0) = 1.0;

mat3 rotationMatrix(vec3 axis, float angle) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return mat3(
        vec3(oc * axis.x * axis.x + c, oc * axis.x * axis.y - axis.z * s, oc * axis.z * axis.x + axis.y * s),
        vec3(oc * axis.x * axis.y + axis.z * s, oc * axis.y * axis.y + c, oc * axis.y * axis.z - axis.x * s),
        vec3(oc * axis.z * axis.x - axis.y * s, oc * axis.y * axis.z + axis.x * s, oc * axis.z * axis.z + c)
    );
}

vec2 transform_perspective(vec2 uv) {
    // Center UV coordinates around 0
    vec2 centered_uv = (uv - 0.5) * 2.0;
    
    // Apply scaling
    centered_uv /= hover_scale;
    
    // Create 3D position
    vec3 pos = vec3(centered_uv.x, centered_uv.y, z_distance);
    
    // Apply rotations
    mat3 rot_x = rotationMatrix(vec3(1.0, 0.0, 0.0), x_rot);
    mat3 rot_y = rotationMatrix(vec3(0.0, 1.0, 0.0), y_rot);
    mat3 rot_z = rotationMatrix(vec3(0.0, 0.0, 1.0), z_rot);
    
    pos = rot_z * rot_y * rot_x * pos;
    
    // Apply perspective projection
    float perspective_factor = 1.0 / (1.0 + pos.z * 0.5);
    pos.xy *= perspective_factor;
    
    // Convert back to UV coordinates
    vec2 result_uv = (pos.xy / 2.0) + 0.5;
    
    return result_uv;
}

void vertex() {
    // Apply lift effect by modifying the vertex position
    VERTEX.y -= lift_amount;
}

void fragment() {
    vec2 transformed_uv = transform_perspective(UV);
    
    // Check if we're outside the texture bounds
    if (transformed_uv.x < 0.0 || transformed_uv.x > 1.0 || transformed_uv.y < 0.0 || transformed_uv.y > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent
    } else {
        COLOR = texture(TEXTURE, transformed_uv);
    }
}