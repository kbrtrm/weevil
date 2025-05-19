# SceneTransitionZone.gd
extends Area2D

@export var target_scene: String = ""  # Path to scene to transition to
@export var spawn_point_name: String = ""  # Name of spawn point in target scene
@export var transition_direction: Vector2 = Vector2.ZERO  # Direction of transition for effects
@export var transition_delay: float = 0.1  # Slight delay to prevent accidental triggers

var player_inside: bool = false
var can_transition: bool = true

func _ready():
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Add to group for easy management
	add_to_group("scene_transition_zones")
	
	# Validate configuration
	if target_scene.is_empty():
		push_warning("SceneTransitionZone has no target scene set!")

func _process(_delta):
	# Only check for transition key if player is inside the zone
	if player_inside and can_transition:
		# Detect any interaction input if configured, otherwise auto-transition
		if (Input.is_action_just_pressed("interact") or spawn_point_name.begins_with("auto_")):
			print("CALLIING TRANSITION")
			trigger_transition()

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_inside = true
		# Show interaction hint if needed
		if not spawn_point_name.begins_with("auto_"):
			show_interaction_hint()

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_inside = false
		# Hide interaction hint
		hide_interaction_hint()

# In SceneTransitionZone.gd's trigger_transition method
# In SceneTransitionZone.gd
func trigger_transition():
	# Prevent multiple transitions
	if not can_transition:
		return
		
	can_transition = false
	
	# Store player's current velocity and state to restore after transition
	store_player_state()
	
	# Initiate transition
	print("SceneTransitionZone: Transitioning to " + target_scene + " at spawn point " + spawn_point_name)
	
	# Set the spawn point in Global FIRST, before calling TransitionManager
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		global.next_spawn_point = spawn_point_name
		print("SceneTransitionZone: Set Global.next_spawn_point to " + spawn_point_name)
	
	# Call transition manager to handle the scene change
	var player_pos = get_player_position()
	if Engine.has_singleton("TransitionManager"):
		var transition_manager = Engine.get_singleton("TransitionManager")
		print("From ZONE:" + transition_manager)
		# Pass both the player position and spawn point name
		transition_manager.change_scene(target_scene, player_pos, spawn_point_name)
	else:
		# Fallback if TransitionManager not available
		push_error("TransitionManager singleton not found!")
		get_tree().change_scene_to_file(target_scene)

func store_player_state():
	var player = get_player()
	if player and Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		# Store relevant player state
		if player.has_method("store_properties_to_global"):
			player.store_properties_to_global()

func get_player():
	return get_tree().get_first_node_in_group("player")

func get_player_position():
	var player = get_player()
	if player:
		return player.global_position
	return global_position

func show_interaction_hint():
	# Show a visual indicator that player can interact
	# This could be an icon, text prompt, or animation
	var interaction_hint = get_node_or_null("InteractionHint")
	if interaction_hint:
		interaction_hint.visible = true

func hide_interaction_hint():
	var interaction_hint = get_node_or_null("InteractionHint")
	if interaction_hint:
		interaction_hint.visible = false
