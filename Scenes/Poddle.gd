extends Sprite2D

var mask_texture : Texture # Reference to the mask texture

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Duplicate the player's sprite
	var reflection_sprite = $"../YSort/Player/Reflection2".duplicate()

	# Flip the reflection sprite vertically
	reflection_sprite.scale.y *= -1

	# Position the reflection sprite below the original sprite
	reflection_sprite.position.y += reflection_sprite.texture.get_height() * reflection_sprite.scale.y

	# Add the reflection sprite as a child of the player's parent node
	get_parent().add_child(reflection_sprite)

	# Load the mask texture (replace "res://path/to/mask.png" with your actual mask texture path)
	mask_texture = preload("res://Images/poddle.png")

	# Set the shader material for the reflection sprite
	var material = ShaderMaterial.new()
	material.shader = load("res://Scenes/poddle.gdshader")
	reflection_sprite.material = material

	# Pass the mask texture to the shader
	material.set_shader_parameter("mask_texture", mask_texture)
	material.set_shader_parameter("reflection_texture", reflection_sprite.texture)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
