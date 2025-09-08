# OutlineComponent.gd - Reusable outline component
extends Node
class_name OutlineComponent

signal outline_shown(target)
signal outline_hidden(target)

@export var outline_width: float = 3.0
@export var outline_color: Color = Color.WHITE
@export var pulse_enabled: bool = false  # Disabled for cleaner look

var target_node: Node2D
var outline_material: ShaderMaterial
var original_material: Material
var pulse_tween: Tween

# Static shader code - improved to handle sprite boundaries better
const OUTLINE_SHADER_CODE = """
shader_type canvas_item;

uniform float outline_width : hint_range(0.0, 10.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec2 texture_size = 1.0 / TEXTURE_PIXEL_SIZE;
	vec4 color = texture(TEXTURE, UV);
	
	if (color.a > 0.0) {
		COLOR = color;
	} else if (outline_width > 0.0) {
		float outline = 0.0;
		
		// 4-direction sampling with boundary checks
		vec2 offsets[4];
		offsets[0] = vec2(0, -1);  // Up
		offsets[1] = vec2(1, 0);   // Right  
		offsets[2] = vec2(0, 1);   // Down
		offsets[3] = vec2(-1, 0);  // Left
		
		for (int i = 0; i < 4; i++) {
			vec2 offset = offsets[i] * outline_width / texture_size;
			vec2 sample_uv = UV + offset;
			
			// Only sample if within valid UV bounds
			if (sample_uv.x >= 0.0 && sample_uv.x <= 1.0 && 
				sample_uv.y >= 0.0 && sample_uv.y <= 1.0) {
				if (texture(TEXTURE, sample_uv).a > 0.0) {
					outline = 1.0;
					break;
				}
			}
		}
		
		if (outline > 0.0) {
			COLOR = outline_color;
		}
	}
}
"""

func _ready():
	# Find the target node (parent with Sprite2D)
	target_node = get_parent()
	if not target_node is Node2D:
		push_error("OutlineComponent must be child of Node2D")
		return
	
	# Create the shader
	create_outline_shader()

func create_outline_shader():
	var shader = Shader.new()
	shader.code = OUTLINE_SHADER_CODE
	
	outline_material = ShaderMaterial.new()
	outline_material.shader = shader
	outline_material.set_shader_parameter("outline_width", 0.0)  # Start hidden
	outline_material.set_shader_parameter("outline_color", outline_color)

func attach_to_sprite(sprite: Node):
	print("OutlineComponent: attach_to_sprite called with: ", sprite.name if sprite else "null")
	
	if not sprite:
		print("OutlineComponent: sprite is null")
		return false
	
	# Check if sprite is a valid type (Sprite2D or AnimatedSprite2D)
	if not (sprite is Sprite2D or sprite is AnimatedSprite2D):
		print("OutlineComponent: Invalid sprite type: ", sprite.get_class())
		return false
	
	print("OutlineComponent: Sprite type is valid: ", sprite.get_class())
	print("OutlineComponent: Current sprite material: ", sprite.material)
	
	# CRITICAL: Store the sprite directly as target_node for cleanup
	target_node = sprite
	
	# Store original material for both Sprite2D and AnimatedSprite2D
	original_material = sprite.material
	print("OutlineComponent: Stored original material: ", original_material)
	
	# Apply outline material
	sprite.material = outline_material
	print("OutlineComponent: Applied outline material. New material: ", sprite.material)
	print("OutlineComponent: Applied material to ", sprite.get_class(), " named: ", sprite.name)
	return true

func show_outline(color: Color = Color.WHITE, width: float = 3.0):
	if not outline_material:
		return
	
	outline_color = color
	outline_width = width
	
	# Update shader parameters
	outline_material.set_shader_parameter("outline_color", outline_color)
	outline_material.set_shader_parameter("outline_width", outline_width)
	
	if pulse_enabled:
		start_pulse()
	
	outline_shown.emit(target_node)

func hide_outline():
	if outline_material:
		outline_material.set_shader_parameter("outline_width", 0.0)
	
	stop_pulse()
	outline_hidden.emit(target_node)

func start_pulse():
	stop_pulse()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	var min_width = outline_width * 0.7
	var max_width = outline_width * 1.3
	
	pulse_tween.tween_method(update_outline_width, outline_width, max_width, 0.8)
	pulse_tween.tween_method(update_outline_width, max_width, min_width, 0.8)

func update_outline_width(width: float):
	if outline_material:
		outline_material.set_shader_parameter("outline_width", width)

func stop_pulse():
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func cleanup():
	print("OutlineComponent: cleanup() called")
	hide_outline()
	
	# Use target_node directly (which should be the sprite)
	if target_node and is_instance_valid(target_node):
		print("OutlineComponent: Restoring material for: ", target_node.name)
		print("OutlineComponent: Original material was: ", original_material)
		target_node.material = original_material
		print("OutlineComponent: Material restored. Current material: ", target_node.material)
	else:
		print("OutlineComponent: target_node is null/invalid, cannot restore material")
	
	# Clear references but KEEP outline_material for reuse
	target_node = null
	original_material = null
	# DON'T clear outline_material - keep it for pooling!

func find_sprite_in_target() -> Node:
	if not target_node or not is_instance_valid(target_node):
		print("OutlineComponent: target_node is null or invalid")
		return null
		
	if target_node is Sprite2D or target_node is AnimatedSprite2D:
		return target_node
	
	for child in target_node.get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return child
	
	return null
