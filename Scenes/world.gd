extends Node2D

@onready var player = $YSort/Player
@onready var reflection_texture = $YSort/Player/Reflection2
	
# Called when the node enters the scene tree for the first time.
func _ready():
	$YSort/Player/Reflection2.connect("texture_loaded", , "_on_texture_loaded")
	
func _on_texture_loaded():
	# Get the player sprite texture (assuming it's set somewhere)
	var player_sprite_texture = reflection_texture.texture.get_data()

	# Create a viewport for rendering the reflection
	var viewport = SubViewport.new()
	viewport.render_target_v_flip = true # Flip vertically
	add_child(viewport)

	# Create a texture rect inside the viewport to display the reflection
	var reflection_texture = TextureRect.new()
	viewport.add_child(reflection_texture)

	# Set the shader material for the reflection texture
	var material = ShaderMaterial.new()
	material.shader = load("res://Scenes/PuddleTest3.gdshader")
	reflection_texture.material = material

	# Pass the player sprite texture to the shader
	material.set_shader_param("player_texture", player_sprite_texture)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_door_body_entered(body):
#	load_scene()
	if body == player: 
		SceneManager.change_scene("res://Scenes/InsidePot.tscn", { "pattern": "fade", "speed": 4})
