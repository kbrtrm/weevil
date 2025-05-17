extends CharacterBody2D

@onready var stats = $Stats
@onready var playerDetectionZone = $PlayerDetectionZone
@onready var combatInitiationZone = $CombatInitiationZone
@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
const EnemyDeathEffect = preload("res://Enemies/EnemyDeathEffect.tscn")
@onready var softCollision = $SoftCollision
@onready var wanderController = $WanderController
@onready var animationPlayer = $AnimationPlayer

# Battle scene reference
@export var battle_scene: PackedScene = preload("res://Cards/test.tscn")

# Enemy data for battle
@export var enemy_data: Dictionary = {
	"name": "Ciggy", 
	"max_health": 12,
	"base_damage": 5
}

# Flag to prevent multiple battle initiations
var battle_initiated = false
# Unique ID
var unique_id = -1

@export var MAX_SPEED = 120
@export var ACCEL = 12
@export var FRICTION = 12
@export var WANDER_TARGET_RANGE = 4

enum {
	IDLE,
	WANDER,
	CHASE
}

var state = WANDER

# Enhance the _ready function with better debugging
func _ready():
	# Initialize unique ID system
	init_unique_id()
	
	# THIS IS THE CRITICAL PART - CHECK IF ALREADY DEFEATED
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		var scene_path = get_tree().current_scene.scene_file_path
		
		print("Checking if enemy " + str(unique_id) + " is already defeated...")
		if global.is_enemy_defeated(scene_path, unique_id):
			print("Enemy " + str(unique_id) + " was previously defeated - REMOVING from scene")
			queue_free()
			return  # Very important - stop initialization
		else:
			print("Enemy " + str(unique_id) + " not found in defeated list, allowed to spawn")
	
	# Debug output
	print("\n=== ENEMY INITIALIZATION DEBUG ===")
	print("Enemy ID: " + str(unique_id))
	print("Current scene path: " + get_tree().current_scene.scene_file_path)
	
	# Continue with normal initialization for active enemies
	state = pick_random_state([IDLE, WANDER])
	
	# Add to enemies group for tracking
	add_to_group("enemies")
	
	# Debug children nodes
	print("Cig has " + str(get_child_count()) + " children")
	for child in get_children():
		var script_info = ""
		if child.get_script():
			script_info = " [Script: " + child.get_script().resource_path + "]"
		print(" - " + child.name + " (" + child.get_class() + ")" + script_info)
		
		# If this is the CombatInitiationZone, examine it further
		if child.name == "CombatInitiationZone":
			print("   CombatInitiationZone details:")
			print("   - Collision layer: " + str(child.collision_layer))
			print("   - Collision mask: " + str(child.collision_mask))
			print("   - Has signal connections: " + str(child.get_signal_connection_list("body_entered").size() > 0))
			
			# Try to manually connect the signal
			if not child.body_entered.is_connected(_on_combat_initiation_zone_body_entered):
				print("   - Manually connecting body_entered signal")
				child.body_entered.connect(_on_combat_initiation_zone_body_entered)
	print("=== END ENEMY INITIALIZATION DEBUG ===\n")

func _physics_process(_delta):
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION)
	move_and_slide()
	
	match state:
		IDLE:
			velocity.move_toward(Vector2.ZERO, 12)
			seek_player()
			
			if wanderController.get_time_left() == 0:
				state = pick_random_state([IDLE, WANDER])
				wanderController.start_wander_timer(randi_range(1,3))
		
		WANDER:
			seek_player()
			
			if wanderController.get_time_left() == 0:
				state = pick_random_state([IDLE, WANDER])
				wanderController.start_wander_timer(randi_range(1,3))

			var direction = global_position.direction_to(wanderController.target_position)
			velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL)
			
			if global_position.distance_to(wanderController.target_position) <= WANDER_TARGET_RANGE:
				state = pick_random_state([IDLE, WANDER])
				wanderController.start_wander_timer(randi_range(1,3))
			
			sprite.flip_h = velocity.x > 0
		
		CHASE:
			var player = playerDetectionZone.player
			if player != null:
				var direction = global_position.direction_to(player.global_position)
				velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL)
			sprite.flip_h = velocity.x > 0        
				
	if softCollision.is_colliding():
		velocity = velocity.move_toward(softCollision.get_push_vector() * MAX_SPEED, ACCEL)
	move_and_slide()
			
func seek_player():
	if playerDetectionZone.can_see_player():
		state = CHASE
		
func pick_random_state(state_list):
	state_list.shuffle()
	return state_list.pop_front()
	
# Modify the combat initiation function to store the enemy ID
func _on_combat_initiation_zone_body_entered(body):
	# Check if it's the player and battle isn't already triggered
	if body.is_in_group("player") and !battle_initiated and !Global.returning_from_battle:
		print("Combat initiated with player!")
		
		# Ensure we have a valid ID - it should already be set, but double check
		if unique_id == -1:
			print("WARNING: Enemy has no ID during combat initiation! Generating now...")
			init_unique_id()
		
		# Store THIS enemy's unique ID and position in Global BEFORE starting battle
		Global.enemy_position = global_position
		Global.current_enemy_id = unique_id  # Store the enemy's unique ID
		
		print("Cig: Starting combat with enemy ID " + str(unique_id) + " at position " + str(global_position))
		print("Cig: Verify Global.current_enemy_id = " + str(Global.current_enemy_id))
		
		# Now start the battle
		start_battle()
		
func start_battle():
	battle_initiated = true
	print("Cig: Starting battle...")
	
	# Pause all game movement
	Global.set_game_paused(true)
	
	# Stop movement
	state = IDLE
	velocity = Vector2.ZERO
	
	# Save game state - don't overwrite enemy info that was already stored
	Global.save_overworld_state()
	
	# Store enemy data - but DON'T overwrite position and ID that were already set
	Global.current_battle_enemies = [enemy_data]
	
	# Get this enemy's position for centering the transition
	var enemy_position = global_position
	
	# SIMPLIFIED: Just directly change to the battle scene...
	print("Cig: Changing to battle scene...")
	
	# Validate battle scene is loaded
	if battle_scene == null:
		push_error("Battle scene is not set!")
		Global.set_game_paused(false)
		battle_initiated = false
		return
	
	# Use TransitionManager for the circle wipe centered on this enemy
	print("Cig: Starting battle transition...")
	
	# Using our TransitionManager to handle the scene change with the circle effect
	# The scene change is triggered from within the TransitionManager
	TransitionManager.start_combat(enemy_position, battle_scene.resource_path)

func _on_hurtbox_area_entered(area):
	stats.health -= area.damage
	var knockback_vector = area.knockback_vector
	velocity = area.knockback_vector * 100
	hurtbox.create_hit_effect()
	hurtbox.start_invincibility(0.4)

func _on_stats_no_health():
	queue_free()
	var enemyDeathEffect = EnemyDeathEffect.instantiate()
	get_parent().add_child(enemyDeathEffect)
	enemyDeathEffect.global_position = global_position

func _on_hurtbox_invincibility_started():
	animationPlayer.play("Start")

func _on_hurtbox_invincibility_ended():
	animationPlayer.play("Stop")

# Generate a deterministic ID based on position in the scene
func generate_deterministic_id():
	# Create a position-based component using grid coordinates (rounded position)
	var grid_pos = Vector2(round(global_position.x / 10) * 10, round(global_position.y / 10) * 10)
	var pos_component = int(grid_pos.x * 1000 + grid_pos.y)
	
	# Get scene path for additional uniqueness
	var scene_path = get_tree().current_scene.scene_file_path
	
	# Combine both to create a unique but deterministic ID
	var combined_hash = scene_path.hash() + pos_component
	
	# Ensure it's a positive number within reasonable range
	var final_id = abs(combined_hash) % 100000
	
	print("Generated deterministic ID for enemy at " + str(global_position) + ": " + str(final_id))
	return final_id

# Modified init_unique_id function for better ID persistence
func init_unique_id():
	# First check if we already have an ID in metadata
	if has_meta("unique_id") and get_meta("unique_id") != -1:
		unique_id = get_meta("unique_id")
		print("Cig: Loaded existing ID from metadata: " + str(unique_id))
		return
		
	# Generate and use a deterministic ID
	unique_id = generate_deterministic_id()
	
	# Store ID in metadata
	set_meta("unique_id", unique_id)
	print("Cig: Set deterministic ID: " + str(unique_id))

# Check if this enemy was previously defeated
func is_defeated():
	if unique_id == -1:
		return false
	
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		var scene_path = get_tree().current_scene.scene_file_path
		return global.is_enemy_defeated(scene_path, unique_id)
	
	return false
