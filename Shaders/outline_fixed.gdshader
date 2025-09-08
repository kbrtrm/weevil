shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 16.0);
uniform vec4 outline_color : source_color;
uniform bool add_margins = true;

void fragment() {
	vec2 texture_size = vec2(textureSize(TEXTURE, 0));
	vec4 color = texture(TEXTURE, UV);
	
	// If the pixel is already opaque or no outline, just use original color
	if (color.a > 0.0 || outline_width == 0.0) {
		COLOR = color;
	} else {
		// For transparent pixels, check for nearby opaque pixels
		float outline = 0.0;
		for (float i = -ceil(outline_width); i <= ceil(outline_width); i++) {
			float x = i / texture_size.x;
			for (float j = -ceil(outline_width); j <= ceil(outline_width); j++) {
				float y = j / texture_size.y;
				if (distance(vec2(i, j), vec2(0.0)) <= outline_width) {
					vec4 sample_color = texture(TEXTURE, UV + vec2(x, y));
					outline += sample_color.a;
				}
			}
		}
		
		if (outline > 0.0) {
			COLOR = outline_color;
		} else {
			COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent
		}
	}
}
