# TargetHighlightDirect.gd - Direct shader application
extends Node2D
class_name TargetHighlightDirect

var target_sprite: Sprite2D
var original_material: Material

func setup_target(sprite: Sprite2D):
	print("TargetHighlightDirect: setup_target called")
	target_sprite = sprite
	if target_sprite:
		# Store original material
		original_material = target_sprite.material
		print("TargetHighlightDirect: Target sprite found: ", sprite.name)
		print("TargetHighlightDirect: Original material: ", original_material)

func show_outline(color: Color = Color.WHITE, width: float = 4.0):
	print("TargetHighlightDirect: show_outline called")
	if not target_sprite:
		print("TargetHighlightDirect: ERROR - No target sprite")
		return
	
	# Try to load and apply shader directly
	print("TargetHighlightDirect: Attempting to load shader...")
	var shader = load("res://Shaders/outline2.gdshader")
	
	if not shader:
		print("TargetHighlightDirect: ERROR - Could not load shader")
		return
	
	print("TargetHighlightDirect: Shader loaded successfully")
	
	# Create material
	var material = ShaderMaterial.new()
	print("TargetHighlightDirect: ShaderMaterial created")
	
	# Set shader
	material.shader = shader
	print("TargetHighlightDirect: Shader assigned to material")
	
	# Set parameters
	material.set_shader_parameter("outline_color", color)
	material.set_shader_parameter("outline_width", width)
	material.set_shader_parameter("add_margins", true)
	print("TargetHighlightDirect: Shader parameters set")
	
	# Apply to sprite
	target_sprite.material = material
	print("TargetHighlightDirect: Material applied to sprite")
	print("TargetHighlightDirect: Final material type: ", target_sprite.material.get_class() if target_sprite.material else "null")

func hide_outline():
	if target_sprite and target_sprite.material is ShaderMaterial:
		var material = target_sprite.material as ShaderMaterial
		material.set_shader_parameter("outline_width", 0.0)

func cleanup():
	if target_sprite:
		target_sprite.material = original_material
	target_sprite = null
