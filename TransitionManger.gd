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

# Modified change_scene to handle pausing
func change_scene(target_scene: String, screen_point = null) -> void:
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
	
	get_tree().change_scene_to_file(next_scene)
	
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

# Modified end_combat to handle pausing
func end_combat(enemy_position: Vector2, world_scene: String, was_battle_won: bool = false) -> void:
	# Fix the debug print to use the parameter instead of the class member
	print("TransitionManager: End combat called, was_battle_won = " + str(was_battle_won))
	
	next_scene = world_scene
	battle_won = was_battle_won
	
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
	
	# Wait for scene to be ready
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Call the Global function to set up the returned world
	var global = get_node("/root/Global")
	if global and global.has_method("setup_returned_world"):
		global.setup_returned_world(was_battle_won)
	
	$AnimationPlayer.play("rpg_transition_in")
	await $AnimationPlayer.animation_finished
	
	# Unpause after transition
	get_tree().paused = false
	
	# Allow input again after transition
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	emit_signal("combat_ended")
