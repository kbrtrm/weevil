shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 10.0) = 0.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec4 original_color = texture(TEXTURE, UV);
	
	if (outline_width > 0.0) {
		// Sample surrounding pixels to detect edges
		float alpha_sum = 0.0;
		int samples = 0;
		
		for (float x = -outline_width; x <= outline_width; x += 1.0) {
			for (float y = -outline_width; y <= outline_width; y += 1.0) {
				if (x == 0.0 && y == 0.0) continue;
				
				vec2 offset = vec2(x, y) / texture_size;
				alpha_sum += texture(TEXTURE, UV + offset).a;
				samples++;
			}
		}
		
		// If we're on a transparent pixel but have nearby opaque pixels, draw outline
		if (original_color.a == 0.0 && alpha_sum > 0.0) {
			COLOR = outline_color;
		} else {
			COLOR = original_color;
		}
	} else {
		COLOR = original_color;
	}
}
