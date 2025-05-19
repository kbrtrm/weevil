extends Node

signal transition_completed
signal combat_started
signal combat_ended

var next_scene = ""
@onready var overlay = $CanvasLayer/ColorRect

# Store whether the battle was won for later processing
var battle_won = false

func _ready():
	# Make sure overlay is transparent and not blocking input initially
	overlay.material.set_shader_parameter("circle_size", 1.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Set our pause mode so we can continue running during pause
	process_mode = Node.PROCESS_MODE_ALWAYS

# Modified change_scene to handle pausing and spawn points
func change_scene(target_scene: String, screen_point = null, spawn_point_name: String = "") -> void:
	# Store spawn point info in Global
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		if spawn_point_name != "":
			global.next_spawn_point = spawn_point_name
			print("TransitionManager: Setting next_spawn_point to " + spawn_point_name)
	
	next_scene = target_scene
	
	# Block input during transition
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Set the center point of the transition (default to center of screen)
	var center = Vector2(0.5, 0.5)
	if screen_point != null:
		# Convert screen coordinates to UV coordinates (0-1 range)
		center = screen_point / get_viewport().get_visible_rect().size
	
	overlay.material.set_shader_parameter("center", center)
	
	# Pause the game DURING transitions
	get_tree().paused = true
	
	$AnimationPlayer.play("rpg_transition_out")
	await $AnimationPlayer.animation_finished
	
	# Change the scene
	get_tree().change_scene_to_file(next_scene)
	
	# CRITICAL: Wait longer for the scene to be fully loaded and all nodes to register
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout  # Add a small delay
	
	# Try to position the player at the spawn point
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		print("TransitionManager: Calling handle_player_spawn()")
		print("TransitionManager: About to call handle_player_spawn()")
		print("TransitionManager: Current scene path = " + get_tree().current_scene.scene_file_path)	
		await get_tree().create_timer(0.5).timeout
		global.handle_player_spawn()
	
	# Continue with the transition animation
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Unpause after transition
	get_tree().paused = false
	
	# Allow input again after transition
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("transition_completed")

# Modified start_combat to handle pausing
func start_combat(screen_position: Vector2, combat_scene: String) -> void:
	next_scene = combat_scene
	
	# Block input during transition
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Get the viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Convert screen position to UV coordinates (0-1 range)
	var center = screen_position / viewport_size
	
	# Get current camera zoom
	var camera = get_viewport().get_camera_2d()
	var camera_zoom = Vector2(1, 1)
	if camera:
		camera_zoom = camera.zoom
	
	# Debug info
	print("TransitionManager: Combat transition at screen position: ", screen_position)
	print("TransitionManager: UV coordinates: ", center)
	print("TransitionManager: Camera zoom: ", camera_zoom)
	
	# Update shader parameters
	overlay.material.set_shader_parameter("center", center)
	overlay.material.set_shader_parameter("camera_zoom", camera_zoom)
	
	# Pause the game DURING transitions
	get_tree().paused = true
	
	$AnimationPlayer.play("rpg_transition_out")
	await $AnimationPlayer.animation_finished
	
	get_tree().change_scene_to_file(next_scene)
	
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Unpause after transition
	get_tree().paused = false
	
	# Allow input again after transition
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("combat_started")

# Modified end_combat function in TransitionManager.gd
func end_combat(screen_position: Vector2, world_scene: String, was_battle_won: bool = false) -> void:
	print("TransitionManager: End combat called, was_battle_won = " + str(was_battle_won))
	
	next_scene = world_scene
	battle_won = was_battle_won
	
	# Block input during transition
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# For transition OUT of battle, use center of screen as starting point
	var viewport_size = get_viewport().get_visible_rect().size
	var center = screen_position / viewport_size
	
	# Get camera zoom
	var camera = get_viewport().get_camera_2d()
	var camera_zoom = Vector2(1, 1)
	if camera:
		camera_zoom = camera.zoom
	
	# Debug info
	print("TransitionManager: End combat transition centered at: ", center)
	print("TransitionManager: Camera zoom: ", camera_zoom)
	
	# Update shader parameters
	overlay.material.set_shader_parameter("center", center)
	overlay.material.set_shader_parameter("camera_zoom", camera_zoom)
	
	# Pause the game DURING transitions
	get_tree().paused = true
	
	$AnimationPlayer.play("rpg_transition_out")
	await $AnimationPlayer.animation_finished
	
	# Store the enemy position for the overworld transition
	var enemy_position = Vector2.ZERO
	if Engine.has_singleton("Global"):
		enemy_position = Global.enemy_position
	
	# Change scene to overworld
	get_tree().change_scene_to_file(next_scene)
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# After we've loaded the overworld, calculate where the enemy was
	if enemy_position != Vector2.ZERO:
		# Now we're in the overworld with a camera
		var world_camera = get_viewport().get_camera_2d()
		if world_camera:
			# Convert the world position of the enemy to screen coordinates
			var viewport_transform = get_viewport().get_canvas_transform()
			var enemy_screen_pos = viewport_transform * enemy_position
			
			# Update the center for the transition in
			center = enemy_screen_pos / viewport_size
			overlay.material.set_shader_parameter("center", center)
			
			print("TransitionManager: Updated center for transition in: ", center)
	
	# Call the Global function to set up the returned world
	if Engine.has_singleton("Global") and Global.has_method("setup_returned_world"):
		Global.setup_returned_world(was_battle_won)
		
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Reset to MOVE state if not already
		if "state" in player and player.state != player.MOVE:
			player.state = player.MOVE
			print("TransitionManager: Force reset player state to MOVE")
		
		# Reset velocity
		if "velocity" in player:
			player.velocity = Vector2.ZERO
	
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Handle enemy cleanup after transition is complete
	if was_battle_won and Engine.has_singleton("EnemiesManager"):
		var enemies_manager = Engine.get_singleton("EnemiesManager")
		# Call this after a slight delay to ensure the scene is fully loaded
		get_tree().create_timer(0.1).timeout.connect(func(): 
			enemies_manager.remove_defeated_enemies()
		)
	
	# Unpause after transition
	get_tree().paused = false
	
	# Allow input again after transition
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("combat_ended")

# Room transition function
func change_room(source_position: Vector2, target_scene: String) -> void:
	print("TransitionManager: Changing room to " + target_scene)
	
	# Store player state before transition
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		global.store_player_state_for_transition()
	
	# Similar to your existing change_scene function
	next_scene = target_scene
	
	# Block input during transition
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Set the center point of the transition 
	var center = source_position / get_viewport().get_visible_rect().size
	overlay.material.set_shader_parameter("center", center)
	
	# Pause the game DURING transitions
	get_tree().paused = true
	
	$AnimationPlayer.play("rpg_transition_out")
	await $AnimationPlayer.animation_finished
	
	get_tree().change_scene_to_file(next_scene)
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Position player at spawn point
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		global.handle_player_spawn()
	
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Unpause after transition
	get_tree().paused = false
	
	# Allow input again after transition
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("transition_completed")
