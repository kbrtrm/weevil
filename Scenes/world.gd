extends Node2D

@onready var player = null  # We'll find the player by group

# Called when the node enters the scene tree for the first time.
func _ready():
	# Wait until the next frame to ensure all nodes are loaded
	await get_tree().process_frame
	
		# Find the camera
	var camera = $PlayerFollowCamera  # Adjust the path as needed
	
	# Set limits based on your scene's needs
	if camera:
		camera.set_limits(0, 0, 400, 600)  # Example values
	
	# Find player by group instead of direct node path
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("world._ready: Found player at " + str(player.global_position))
	else:
		push_error("world._ready: Player not found in groups!")
	
		
	# Handle player spawn if needed
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		if global.next_spawn_point != "":
			print("world._ready: Calling handle_player_spawn for: " + global.next_spawn_point)
			global.handle_player_spawn()

# Called every frame to keep track of player
func _process(_delta):
	# Constantly update the player reference in case it changes
	if player == null or !is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player:
			print("world._process: Updated player reference, now at " + str(player.global_position))
