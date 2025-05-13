shader_type canvas_item;

// CRT effect parameters - all kept subtle by default
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.1;
uniform float scanline_speed : hint_range(0.0, 10.0) = 0.0; // 0 = static scanlines
uniform float scanline_width : hint_range(0.0, 0.02) = 0.0025; // thickness of scanlines
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.2; // darkened corners
uniform float vignette_size : hint_range(0.0, 1.0) = 0.7; // size of vignette effect
uniform float distortion : hint_range(0.0, 0.2) = 0.02; // subtle screen curvature
uniform float rgb_shift : hint_range(0.0, 5.0) = 0.5; // subtle color separation
uniform float brightness : hint_range(0.5, 1.5) = 1.05; // slight brightness boost
uniform float flickering : hint_range(0.0, 0.2) = 0.03; // subtle screen flicker
uniform float flickering_speed : hint_range(0.1, 10.0) = 5.0; // speed of flicker
uniform float grain_amount : hint_range(0.0, 0.1) = 0.01; // subtle noise grain
uniform bool enable_ghosting = true; // subtle afterimage effect
uniform float ghosting_strength : hint_range(0.0, 0.5) = 0.05; // intensity of ghosting

// Store previous frame for ghosting effect
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D PREV_FRAME : hint_screen_texture, filter_linear_mipmap;

// Random function for grain effect
float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Screen resolution (for correct aspect ratio)
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    float aspect_ratio = resolution.x / resolution.y;

    // Apply subtle curvature/distortion
    vec2 uv = SCREEN_UV;
    if (distortion > 0.0) {
        vec2 uv_centered = uv * 2.0 - 1.0; // Center UV coords (-1 to 1)
        float dist = length(uv_centered * vec2(1.0, aspect_ratio));
        uv_centered *= 1.0 + dist * dist * distortion;
        uv = (uv_centered * 0.5 + 0.5); // Convert back to 0-1 range
    }

    // Sample the screen texture - check if we're outside the bounds after distortion
    vec4 color = vec4(0.0);
    if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
        // Apply subtle RGB shift (chromatic aberration)
        if (rgb_shift > 0.0) {
            float shift_amount = rgb_shift / resolution.x;
            color.r = texture(SCREEN_TEXTURE, vec2(uv.x + shift_amount, uv.y)).r;
            color.g = texture(SCREEN_TEXTURE, uv).g;
            color.b = texture(SCREEN_TEXTURE, vec2(uv.x - shift_amount, uv.y)).b;
            color.a = 1.0;
        } else {
            color = texture(SCREEN_TEXTURE, uv);
        }

        // Add subtle ghosting/persistence effect
        if (enable_ghosting) {
            vec4 prev_frame = texture(PREV_FRAME, uv);
            color = mix(color, prev_frame, ghosting_strength);
        }

        // Apply scanlines
        if (scanline_opacity > 0.0) {
            float scanline_pos = uv.y * resolution.y + TIME * scanline_speed;
            float scanline = sin(scanline_pos * 3.14159 / scanline_width);
            scanline = (scanline * 0.5 + 0.5) * scanline_opacity;
            color.rgb *= 1.0 - scanline;
        }

        // Apply vignette (darkened corners)
        if (vignette_strength > 0.0) {
            float vignette = distance(uv, vec2(0.5, 0.5));
            vignette = smoothstep(vignette_size, 1.0, vignette);
            color.rgb *= 1.0 - vignette * vignette_strength;
        }

        // Apply subtle flickering
        if (flickering > 0.0) {
            float flicker = sin(TIME * flickering_speed) * flickering;
            color.rgb *= 1.0 + flicker;
        }

        // Apply subtle grain/noise
        if (grain_amount > 0.0) {
            float grain = random(uv + vec2(TIME * 0.001, TIME * 0.001)) * grain_amount;
            color.rgb += grain - grain_amount * 0.5;
        }

        // Adjust brightness
        color.rgb *= brightness;
    }

    COLOR = color;
}