# TargetHighlight.gd - Shader-based outline version
extends Node2D
class_name TargetHighlightShader

var target_sprite: Sprite2D
var outline_shader: Shader
var original_material: Material

func _ready():
	# Load the outline shader
	outline_shader = preload("res://Shaders/outline2.gdshader")

func setup_target(sprite: Sprite2D):
	target_sprite = sprite
	if target_sprite:
		# Store original material
		original_material = target_sprite.material
		
		# Create shader material for outline
		var shader_material = ShaderMaterial.new()
		shader_material.shader = outline_shader
		
		# Set initial outline (invisible)
		shader_material.set_shader_parameter("outline_color", Color.WHITE)
		shader_material.set_shader_parameter("outline_width", 0.0)
		shader_material.set_shader_parameter("add_margins", true)
		
		target_sprite.material = shader_material

func show_outline(color: Color = Color.WHITE, width: float = 3.0):
	if target_sprite and target_sprite.material is ShaderMaterial:
		var material = target_sprite.material as ShaderMaterial
		material.set_shader_parameter("outline_color", color)
		material.set_shader_parameter("outline_width", width)

func hide_outline():
	if target_sprite and target_sprite.material is ShaderMaterial:
		var material = target_sprite.material as ShaderMaterial
		material.set_shader_parameter("outline_width", 0.0)

func cleanup():
	if target_sprite:
		target_sprite.material = original_material
	target_sprite = null
