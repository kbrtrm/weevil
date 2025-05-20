# SceneTransitionZone.gd - updated to use SpawnManager
extends Area2D

@export var target_scene: String = ""  # Path to scene to transition to
@export var spawn_point_name: String = ""  # Name of spawn point in target scene
@export var transition_direction: Vector2 = Vector2.ZERO  # Direction of transition for effects
@export var transition_delay: float = 0.1  # Slight delay to prevent accidental triggers

var player_inside: bool = false
var can_transition: bool = true
var transition_cooldown_timer: float = 0.0

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Add to group for easy management
	add_to_group("scene_transition_zones")
	
	# Validate configuration
	if target_scene.is_empty():
		push_warning("SceneTransitionZone has no target scene set!")

func _process(delta):
	# Handle cooldown
	if transition_cooldown_timer > 0:
		transition_cooldown_timer -= delta
		
	# Only check for transition key if player is inside the zone
	if player_inside and can_transition and transition_cooldown_timer <= 0:
		# Detect any interaction input if configured, otherwise auto-transition
		if Input.is_action_just_pressed("interact") or spawn_point_name.begins_with("auto_"):
			print("SceneTransitionZone: Triggering transition to " + target_scene)
			trigger_transition()

func _on_body_entered(body):
	if body.is_in_group("player"):
		print("SceneTransitionZone: Player entered transition zone for " + target_scene)
		player_inside = true
		# Show interaction hint if needed
		if not spawn_point_name.begins_with("auto_"):
			show_interaction_hint()

func _on_body_exited(body):
	if body.is_in_group("player"):
		print("SceneTransitionZone: Player exited transition zone")
		player_inside = false
		# Hide interaction hint
		hide_interaction_hint()

func trigger_transition():
	# Prevent multiple transitions
	if not can_transition:
		return
		
	print("SceneTransitionZone: Starting transition to " + target_scene + " at spawn point " + spawn_point_name)
	
	# Set cooldown and prevent multiple transitions
	can_transition = false
	transition_cooldown_timer = transition_delay
	
	# CRITICAL: Tell the SpawnManager what spawn point to use
	if Engine.has_singleton("SpawnManager"):
		var spawn_manager = Engine.get_singleton("SpawnManager")
		spawn_manager.prepare_transition(spawn_point_name)
		print("SceneTransitionZone: Told SpawnManager to use spawn point: " + spawn_point_name)
	
	# Get player position for transition effect center
	var player_pos = get_player_position()
	
	# Call TransitionManager to handle the scene change
	if Engine.has_singleton("TransitionManager"):
		var transition_manager = Engine.get_singleton("TransitionManager")
		print("SceneTransitionZone: Calling TransitionManager.change_scene()")
		transition_manager.change_scene(target_scene, player_pos, spawn_point_name)
	else:
		# Fallback if TransitionManager not available
		push_error("TransitionManager singleton not found!")
		get_tree().change_scene_to_file(target_scene)

func get_player():
	return get_tree().get_first_node_in_group("player")

func get_player_position():
	var player = get_player()
	if player:
		return player.global_position
	return global_position

func show_interaction_hint():
	# Show a visual indicator that player can interact
	var interaction_hint = get_node_or_null("InteractionHint")
	if interaction_hint:
		interaction_hint.visible = true

func hide_interaction_hint():
	var interaction_hint = get_node_or_null("InteractionHint")
	if interaction_hint:
		interaction_hint.visible = false
