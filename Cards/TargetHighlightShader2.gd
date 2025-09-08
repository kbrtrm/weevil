# TargetHighlightShader2.gd - Working shader-based outline
extends Node2D
class_name TargetHighlightShader2

var target_sprite: Sprite2D
var outline_shader: Shader
var original_material: Material

func _ready():
	# Load the outline shader
	print("TargetHighlightShader2: _ready called, loading shader...")
	if ResourceLoader.exists("res://Shaders/outline2.gdshader"):
		outline_shader = load("res://Shaders/outline2.gdshader")
		print("TargetHighlightShader2: Shader loaded successfully: ", outline_shader != null)
		if outline_shader:
			print("TargetHighlightShader2: Shader resource path: ", outline_shader.resource_path)
	else:
		print("TargetHighlightShader2: ERROR - Shader file not found!")

func setup_target(sprite: Sprite2D):
	print("TargetHighlightShader2: setup_target called for sprite: ", sprite.name)
	target_sprite = sprite
	if target_sprite:
		# Store original material
		original_material = target_sprite.material
		print("TargetHighlightShader2: Original material: ", original_material)
		
		if not outline_shader:
			print("TargetHighlightShader2: ERROR - No shader loaded, cannot apply")
			return
		
		# Create shader material for outline
		var shader_material = ShaderMaterial.new()
		shader_material.shader = outline_shader
		
		if not shader_material.shader:
			print("TargetHighlightShader2: ERROR - Failed to assign shader to material")
			return
		
		# Set initial outline (invisible)
		shader_material.set_shader_parameter("outline_color", Color.WHITE)
		shader_material.set_shader_parameter("outline_width", 0.0)
		shader_material.set_shader_parameter("add_margins", true)
		
		target_sprite.material = shader_material
		print("TargetHighlightShader2: Shader material applied successfully")
		print("TargetHighlightShader2: Material type: ", target_sprite.material.get_class())

func show_outline(color: Color = Color.WHITE, width: float = 4.0):
	print("TargetHighlightShader2: show_outline called - color: ", color, " width: ", width)
	if target_sprite and target_sprite.material is ShaderMaterial:
		var material = target_sprite.material as ShaderMaterial
		material.set_shader_parameter("outline_color", color)
		material.set_shader_parameter("outline_width", width)
		print("TargetHighlightShader2: Shader parameters set successfully")
		print("TargetHighlightShader2: Current outline_width: ", material.get_shader_parameter("outline_width"))
	else:
		print("TargetHighlightShader2: ERROR - No target sprite or wrong material type")
		if target_sprite:
			print("TargetHighlightShader2: Material type: ", target_sprite.material.get_class() if target_sprite.material else "null")

func hide_outline():
	if target_sprite and target_sprite.material is ShaderMaterial:
		var material = target_sprite.material as ShaderMaterial
		material.set_shader_parameter("outline_width", 0.0)

func cleanup():
	if target_sprite:
		target_sprite.material = original_material
	target_sprite = null
