# DebugManager.gd - Global debug settings
extends Node

# Master debug flag - set to true to show ALL debug visuals in the game
const DEBUG_ENABLED = true

# Specific debug categories
const SHOW_COLLISION_SHAPES = true
const SHOW_DETECTION_ZONES = true
const SHOW_ENEMY_PURSUIT_CIRCLES = true
const SHOW_LINE_OF_SIGHT = true
const SHOW_SCENE_TRANSITION_ZONES = false

# Called when the node enters the scene tree
func _ready():
	print("DebugManager: Debug mode is ", "ENABLED" if DEBUG_ENABLED else "DISABLED")
	
	# Apply debug settings when the scene is ready
	call_deferred("apply_debug_settings")

# Apply debug settings to all relevant nodes
func apply_debug_settings():
	# Hide collision shapes if debug is disabled
	if not DEBUG_ENABLED or not SHOW_COLLISION_SHAPES:
		hide_collision_shapes()
	
	# Hide detection zones if debug is disabled  
	if not DEBUG_ENABLED or not SHOW_DETECTION_ZONES:
		hide_detection_zones()
	
	# Hide scene transition zone visuals
	if not DEBUG_ENABLED or not SHOW_SCENE_TRANSITION_ZONES:
		hide_scene_transition_zones()

# Hide all collision shape debug visuals
func hide_collision_shapes():
	var collision_shapes = get_tree().get_nodes_in_group("debug_collision_shapes")
	for shape in collision_shapes:
		if shape.has_method("set_visible"):
			shape.set_visible(false)
		else:
			shape.visible = false

# Hide detection zone visuals
func hide_detection_zones():
	# Find all enemy detection zones
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		# Hide player detection zone
		var detection_zone = enemy.get_node_or_null("PlayerDetectionZone/CollisionShape2D")
		if detection_zone:
			detection_zone.visible = false
		
		# Hide combat initiation zone
		var combat_zone = enemy.get_node_or_null("CombatInitiationZone/CollisionShape2D")
		if combat_zone:
			combat_zone.visible = false
		
		# Hide soft collision zone
		var soft_collision = enemy.get_node_or_null("SoftCollision/CollisionShape2D")
		if soft_collision:
			soft_collision.visible = false
		
		# Hide line of sight detection
		var los_detection = enemy.get_node_or_null("LineOfSightDetection/CollisionShape2D")
		if los_detection:
			los_detection.visible = false
		
		# Hide debug visuals node
		var debug_visuals = enemy.get_node_or_null("DebugVisuals")
		if debug_visuals:
			debug_visuals.visible = false

# Hide scene transition zone visuals
func hide_scene_transition_zones():
	var transition_zones = get_tree().get_nodes_in_group("scene_transition_zones")
	for zone in transition_zones:
		var collision_shape = zone.get_node_or_null("CollisionShape2D")
		if collision_shape:
			collision_shape.visible = false

# Helper function to check if debug mode is enabled
func is_debug_enabled() -> bool:
	return DEBUG_ENABLED

# Helper function to check specific debug categories
func is_collision_shapes_visible() -> bool:
	return DEBUG_ENABLED and SHOW_COLLISION_SHAPES

func is_detection_zones_visible() -> bool:
	return DEBUG_ENABLED and SHOW_DETECTION_ZONES

func is_pursuit_circles_visible() -> bool:
	return DEBUG_ENABLED and SHOW_ENEMY_PURSUIT_CIRCLES

func is_line_of_sight_visible() -> bool:
	return DEBUG_ENABLED and SHOW_LINE_OF_SIGHT

func is_scene_transition_zones_visible() -> bool:
	return DEBUG_ENABLED and SHOW_SCENE_TRANSITION_ZONES
