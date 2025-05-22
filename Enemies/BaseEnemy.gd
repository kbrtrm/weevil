# BaseEnemy.gd
extends CharacterBody2D

# Child node references
@onready var stats = $Stats
@onready var playerDetectionZone = $PlayerDetectionZone
@onready var combatInitiationZone = $CombatInitiationZone
@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
@onready var softCollision = $SoftCollision
@onready var wanderController = $WanderController
@onready var animationPlayer = $AnimationPlayer if has_node("AnimationPlayer") else null

# Effects
const EnemyDeathEffect = preload("res://Enemies/EnemyDeathEffect.tscn")

# Battle reference - can be overridden by child classes
@export var battle_scene: PackedScene = preload("res://Cards/test.tscn")

# Base enemy data - should be customized by inherited enemies
@export var enemy_data: Dictionary = {
	"name": "Enemy", 
	"max_health": 10,
	"base_damage": 4
}

# Movement parameters - can be adjusted per enemy type
@export var MAX_SPEED: float = 80.0
@export var ACCEL: float = 10.0
@export var FRICTION: float = 10.0
@export var WANDER_TARGET_RANGE: float = 4.0

# Flag to prevent multiple battle initiations
var battle_initiated: bool = false
# Unique ID for tracking this enemy
var unique_id: int = -1

# States
enum EnemyState {
	IDLE,
	WANDER, 
	CHASE
}

var state = EnemyState.WANDER

func _ready():
	# Initialize unique ID for tracking
	init_unique_id()
	
	# Check if already defeated
	check_if_defeated()
	
	# Init state
	add_to_group("enemies")
	state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
	
	# Connect combat initiation signal
	var combat_zone = get_node_or_null("CombatInitiationZone")
	if combat_zone and !combat_zone.body_entered.is_connected(_on_combat_initiation_zone_body_entered):
		combat_zone.body_entered.connect(_on_combat_initiation_zone_body_entered)

func check_if_defeated():
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		var scene_path = get_tree().current_scene.scene_file_path
		
		# Check if this enemy is in the defeated list
		if global.has_method("is_enemy_defeated") and global.is_enemy_defeated(scene_path, unique_id):
			print(enemy_data.name + " " + str(unique_id) + ": Already defeated, removing")
			remove_defeated_enemy()
			return true
	
	return false

func remove_defeated_enemy():
	# Make invisible immediately and queue_free
	modulate.a = 0
	visible = false
	queue_free()

func _physics_process(delta):
	# Apply state behavior first, before applying friction
	match state:
		EnemyState.IDLE:
			handle_idle_state(delta)
		EnemyState.WANDER:
			handle_wander_state(delta)
		EnemyState.CHASE:
			handle_chase_state(delta)
	
	# Apply soft collision avoidance
	if softCollision.is_colliding():
		velocity = velocity.move_toward(softCollision.get_push_vector() * MAX_SPEED, ACCEL * delta)
	
	# Apply friction AFTER state behavior
	if state == EnemyState.IDLE:
		# More friction when idle
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * 2 * delta)
	else:
		# Normal friction otherwise
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	# Apply movement
	move_and_slide()

func handle_idle_state(delta):
	# In idle state, just check for player
	seek_player()
	
	# Check if wander timer is done
	if wanderController.get_time_left() == 0:
		# Pick a new random state
		state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
		wanderController.start_wander_timer(randi_range(1, 3))

func handle_wander_state(delta):
	# Check for player first
	seek_player()
	
	# Check if wander timer is done
	if wanderController.get_time_left() == 0:
		# Pick a new random state
		state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
		wanderController.start_wander_timer(randi_range(1, 3))
		return
	
	# Move toward wander target
	var direction = global_position.direction_to(wanderController.target_position)
	
	# Make sure direction is normalized
	direction = direction.normalized()
	
	# Apply acceleration using delta time for consistency
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL * delta * 60.0)
	
	# Check if we've reached the target
	if global_position.distance_to(wanderController.target_position) <= WANDER_TARGET_RANGE:
		# Pick a new state
		state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
		wanderController.start_wander_timer(randi_range(1, 3))
	
	# Update sprite direction
	update_sprite_direction()

func handle_chase_state(delta):
	var player = playerDetectionZone.player
	if player != null:
		# Move toward player
		var direction = global_position.direction_to(player.global_position)
		
		# Make sure direction is normalized
		direction = direction.normalized()
		
		# Apply acceleration using delta time for consistent speed
		velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL * delta * 60.0)
		
		# Update sprite direction
		update_sprite_direction()
	else:
		# Lost the player, go back to idle
		state = EnemyState.IDLE

func update_sprite_direction():
	# Flip sprite based on movement direction
	# Override this in child classes for more complex animations
	if sprite:
		sprite.flip_h = velocity.x > 0

func seek_player():
	if playerDetectionZone.can_see_player():
		state = EnemyState.CHASE

func pick_random_state(state_list):
	state_list.shuffle()
	return state_list.pop_front()

# Combat initiation
func _on_combat_initiation_zone_body_entered(body):
	# Check if it's the player and battle isn't already triggered
	if body.is_in_group("player") and !battle_initiated and !Global.returning_from_battle:
		print(enemy_data.name + ": Combat initiated with player!")
		
		# Validate unique ID
		if unique_id == -1:
			print("WARNING: Enemy has no ID during combat initiation! Generating now...")
			init_unique_id()
		
		# Store enemy info in Global
		Global.enemy_position = global_position
		Global.current_enemy_id = unique_id
		
		print(enemy_data.name + ": Starting combat with ID " + str(unique_id) + " at " + str(global_position))
		
		# Start battle
		start_battle(get_screen_position())

# Helper function to get screen position for transitions
func get_screen_position() -> Vector2:
	# Get the current camera
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return global_position
	
	# Convert global position to screen position
	var viewport_transform = get_viewport().get_canvas_transform()
	var screen_pos = viewport_transform * global_position
	
	return screen_pos

# Start the battle
func start_battle(screen_position: Vector2 = Vector2.ZERO):
	battle_initiated = true
	print(enemy_data.name + ": Starting battle...")
	
	# Pause movement
	Global.set_game_paused(true)
	state = EnemyState.IDLE
	velocity = Vector2.ZERO
	
	# Save game state
	Global.save_overworld_state()
	
	# Set enemy data
	Global.current_battle_enemies = [enemy_data]
	
	# Get screen position for transition
	var transition_position = screen_position
	if transition_position == Vector2.ZERO:
		transition_position = get_screen_position()
	
	# Validate battle scene
	if battle_scene == null:
		push_error("Battle scene is not set!")
		Global.set_game_paused(false)
		battle_initiated = false
		return
	
	# Start battle transition
	TransitionManager.start_combat(transition_position, battle_scene.resource_path)

# Handle being hit
func _on_hurtbox_area_entered(area):
	stats.health -= area.damage
	
	# Apply knockback
	var knockback_vector = area.knockback_vector
	velocity = knockback_vector * 100
	
	# Visual effects
	hurtbox.create_hit_effect()
	hurtbox.start_invincibility(0.4)
	
	# Override in child classes for custom hit behavior

# Handle death
func _on_stats_no_health():
	die()

func die():
	# Visual death effect
	var enemyDeathEffect = EnemyDeathEffect.instantiate()
	get_parent().add_child(enemyDeathEffect)
	enemyDeathEffect.global_position = global_position
	
	# Remove the enemy
	queue_free()
	
	# Override in child classes for custom death behavior

# Unique ID system
func generate_deterministic_id():
	# Create a position-based component
	var grid_pos = Vector2(round(global_position.x / 10) * 10, round(global_position.y / 10) * 10)
	var pos_component = int(grid_pos.x * 1000 + grid_pos.y)
	
	# Get scene path
	var scene_path = get_tree().current_scene.scene_file_path
	
	# Combine for a unique but deterministic ID
	var combined_hash = scene_path.hash() + pos_component
	
	# Ensure it's a positive number in a reasonable range
	var final_id = abs(combined_hash) % 100000
	
	print("Generated ID for " + enemy_data.name + " at " + str(global_position) + ": " + str(final_id))
	return final_id

func init_unique_id():
	# Check if we already have an ID
	if has_meta("unique_id") and get_meta("unique_id") != -1:
		unique_id = get_meta("unique_id")
		print(enemy_data.name + ": Loaded existing ID: " + str(unique_id))
		return
	
	# Generate a new ID
	unique_id = generate_deterministic_id()
	
	# Store ID in metadata
	set_meta("unique_id", unique_id)
	print(enemy_data.name + ": Set deterministic ID: " + str(unique_id))

# Check if this enemy was previously defeated
func is_defeated():
	if unique_id == -1:
		return false
	
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		var scene_path = get_tree().current_scene.scene_file_path
		return global.is_enemy_defeated(scene_path, unique_id)
	
	return false

# Invincibility flashing effects - override if needed
func _on_hurtbox_invincibility_started():
	if animationPlayer:
		animationPlayer.play("Start")

func _on_hurtbox_invincibility_ended():
	if animationPlayer:
		animationPlayer.play("Stop")
