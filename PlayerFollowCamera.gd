extends Camera2D

@export var default_zoom := Vector2(1.5, 1.5)
@export var follow_speed := 5.0  # Used if we need smooth following as a fallback

# Signal to emit when camera is ready and has found the player
signal camera_ready(player_found: bool)

func _ready():
	# Set the initial zoom
	zoom = default_zoom
	
	# Wait until the tree is ready
	await get_tree().process_frame
	
	# Find the player (assumes the player is in the "player" group)
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Camera: Found player at " + str(player.global_position))
		
		# Check if the player already has a RemoteTransform2D
		var remote_transform = null
		for child in player.get_children():
			if child is RemoteTransform2D:
				remote_transform = child
				break
		
		# If no RemoteTransform2D is found, create one
		if remote_transform == null:
			remote_transform = RemoteTransform2D.new()
			player.add_child(remote_transform)
			print("Camera: Added RemoteTransform2D to player")
		
		# Configure the RemoteTransform2D to target this camera
		remote_transform.remote_path = remote_transform.get_path_to(self)
		remote_transform.update_position = true
		remote_transform.update_rotation = false
		remote_transform.update_scale = false
		remote_transform.use_global_coordinates = true
		
		print("Camera: Set up remote transform to follow player")
		
		# Set the camera position immediately to the player position
		global_position = player.global_position
		
		# Emit signal indicating success
		camera_ready.emit(true)
	else:
		print("Camera: Player not found!")
		camera_ready.emit(false)

# Fallback following in case the RemoteTransform2D isn't working
func _process(delta):
	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		# Check if we have a remote transform connection
		var has_remote = false
		for child in player.get_children():
			if child is RemoteTransform2D and child.remote_path.is_empty() == false:
				has_remote = true
				break
				
		# If no remote transform is actively controlling us, use lerp following
		if not has_remote:
			global_position = global_position.lerp(player.global_position, follow_speed * delta)

# Method to set camera limits manually from outside
func set_limits(left: float, top: float, right: float, bottom: float) -> void:
	limit_left = left
	limit_top = top
	limit_right = right
	limit_bottom = bottom
	print("Camera: Limits set manually")

# Method to set zoom (can be called from outside)
func set_camera_zoom(new_zoom: Vector2) -> void:
	zoom = new_zoom

# Method to change zoom level by a multiplier
func change_zoom_level(multiplier: float) -> void:
	zoom *= multiplier
