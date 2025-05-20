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

# TransitionManager.gd - Updated change_scene method
func change_scene(target_scene: String, screen_point = null, spawn_point_name: String = "") -> void:
	print("TransitionManager: Starting scene change to " + target_scene + " with spawn point '" + spawn_point_name + "'")
	
	# Store spawn point info globally for the new scene to access
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		if spawn_point_name != "":
			global.next_spawn_point = spawn_point_name
			# Also store in TransitionManager as backup
			print("TransitionManager: Setting spawn point to: " + spawn_point_name)
	
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
	
	print("TransitionManager: Changing to scene: " + target_scene)
	print("TransitionManager: Target spawn point: " + spawn_point_name)
	
	# Change the scene
	get_tree().change_scene_to_file(target_scene)
	
	# Need to wait for the scene to fully load
	# We'll use multiple frames and a timer
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	
	# Try to move the player to the spawn point
	if Engine.has_singleton("Global") and spawn_point_name != "":
		var global = Engine.get_singleton("Global")
		
		# Call handle_player_spawn and wait for it to complete
		print("TransitionManager: After scene change, calling handle_player_spawn for '" + spawn_point_name + "'")
		var success = await global.handle_player_spawn()
		print("TransitionManager: handle_player_spawn result: " + str(success))
		
		# Fallback - try direct positioning
		if not success:
			print("TransitionManager: Trying direct player positioning fallback")
			var spawn_points = get_tree().get_nodes_in_group("spawn_points")
			var player = get_tree().get_first_node_in_group("player")
			
			if player and spawn_points.size() > 0:
				for spawn in spawn_points:
					if spawn.spawn_point_name == spawn_point_name:
						print("TransitionManager: Found spawn point, moving player directly")
						player.global_position = spawn.global_position
						print("TransitionManager: Player moved to " + str(player.global_position))
						break
	
	# Continue with the transition animation
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Unpause after transition
	get_tree().paused = false
	
	# Allow input again after transition
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("transition_completed")

# Modified start_combat to handle pausing
func start_combat(enemy_position: Vector2, combat_scene: String) -> void:
	next_scene = combat_scene
	
	# Block input during transition
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Center the transition on the enemy
	var center = enemy_position / get_viewport().get_visible_rect().size
	overlay.material.set_shader_parameter("center", center)
	
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

# Modified end_combat to handle pausing and notify EnemiesManager
func end_combat(enemy_position: Vector2, world_scene: String, was_battle_won: bool = false) -> void:
	# Fix the debug print to use the parameter instead of the class member
	print("TransitionManager: End combat called, was_battle_won = " + str(was_battle_won))
	
	next_scene = world_scene
	battle_won = was_battle_won
	
	# Block input during transition
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	 
	# Get player position from Global instead of using enemy_position
	var transition_center = enemy_position
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		if global.player_position != Vector2.ZERO:
			transition_center = global.player_position
			print("TransitionManager: Using saved player position for transition: " + str(transition_center))
	
	# Center the transition on the player/enemy position
	var center = transition_center / get_viewport().get_visible_rect().size
	overlay.material.set_shader_parameter("center", center)
	
	# Pause the game DURING transitions
	get_tree().paused = true
	
	$AnimationPlayer.play("rpg_transition_out")
	await $AnimationPlayer.animation_finished
	get_tree().change_scene_to_file(next_scene)
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Call the Global function to set up the returned world
	var global = get_node("/root/Global")
	if global and global.has_method("setup_returned_world"):
		global.setup_returned_world(was_battle_won)
	
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Tell EnemiesManager to scan for defeated enemies if battle was won
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
