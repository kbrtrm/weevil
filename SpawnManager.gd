# SpawnManager.gd - New singleton focused solely on handling scene transitions
extends Node

# Store the target spawn point between scenes
var target_spawn_point: String = ""
var is_transitioning: bool = false

# Register this as a singleton that will persist between scene changes
func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS  # Ensure we keep running during scene transitions
	print("SpawnManager: Initialized")

# Called before a scene transition
func prepare_transition(spawn_point_name: String):
	target_spawn_point = spawn_point_name
	is_transitioning = true
	print("SpawnManager: Preparing transition to spawn point: " + target_spawn_point)

# This runs on every frame, allowing us to catch the player after scene loads
func _process(_delta):
	# Only run this when we're actively transitioning
	if is_transitioning and target_spawn_point != "":
		# Try to find the player and spawn point
		var player = get_tree().get_first_node_in_group("player")
		
		# Wait until we have a player to position
		if player:
			# Find the target spawn point
			var spawn_points = get_tree().get_nodes_in_group("spawn_points")
			var found_spawn = false
			
			for spawn in spawn_points:
				print("SpawnManager: Checking spawn point: " + spawn.spawn_point_name)
				
				if spawn.spawn_point_name == target_spawn_point:
					# Position the player at the spawn point
					print("SpawnManager: Found target spawn point at " + str(spawn.global_position))
					print("SpawnManager: Moving player from " + str(player.global_position))
					
					player.global_position = spawn.global_position
					
					# Apply any adjustments from the spawn point
					if "adjust_position" in spawn and spawn.adjust_position != Vector2.ZERO:
						player.global_position += spawn.adjust_position
					
					print("SpawnManager: Player positioned at " + str(player.global_position))
					found_spawn = true
					break
			
			# If we found the spawn point, we're done with this transition
			if found_spawn:
				is_transitioning = false
				target_spawn_point = ""
				print("SpawnManager: Transition complete")
