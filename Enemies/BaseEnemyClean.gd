# BaseEnemy.gd - Clean version
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
	"max_health": 12,
	"base_damage": 5
}

# Movement parameters - can be adjusted per enemy type
@export var MAX_SPEED: float = 80.0
@export var ACCEL: float = 10.0
@export var FRICTION: float = 10.0
@export var WANDER_TARGET_RANGE: float = 4.0

# Pursuit parameters
@export var PURSUIT_RANGE: float = 150.0  # Range to continue chasing after spotting player
@export var PURSUIT_TIMEOUT: float = 3.0  # How long to pursue before giving up

# Flag to prevent multiple battle initiations
var battle_initiated: bool = false
# Unique ID for tracking this enemy
var unique_id: int = -1

# States
enum EnemyState {
	IDLE,
	WANDER, 
	CHASE,
	SPOTTED  # New state for when player is first spotted
}

var state = EnemyState.WANDER
var spotted_timer: float = 0.0  # Timer for spotted state
var spotted_duration: float = 0.8  # How long the spotted state lasts
var has_exclamation: bool = false  # Track if exclamation is active
var pursuit_timer: float = 0.0  # Timer for how long we've been pursuing
var last_known_player_position: Vector2  # Last position where we saw the player
var spotted_facing_direction: Vector2  # Direction enemy was facing when player was spotted

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
	
	# Connect line of sight signals if available
	var line_of_sight = get_node_or_null("LineOfSightDetection")
	if line_of_sight:
		if line_of_sight.has_signal("player_spotted") and not line_of_sight.player_spotted.is_connected(_on_player_spotted):
			line_of_sight.player_spotted.connect(_on_player_spotted)
		if line_of_sight.has_signal("player_lost") and not line_of_sight.player_lost.is_connected(_on_player_lost):
			line_of_sight.player_lost.connect(_on_player_lost)

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
		EnemyState.SPOTTED:
			handle_spotted_state(delta)
	
	# Apply soft collision avoidance
	if softCollision.is_colliding():
		velocity = velocity.move_toward(softCollision.get_push_vector() * MAX_SPEED, ACCEL * delta)
	
	# Apply friction AFTER state behavior
	if state == EnemyState.IDLE or state == EnemyState.SPOTTED:
		# More friction when idle or spotted
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * 2 * delta)
	else:
		# Normal friction otherwise
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION * delta)
	
	# Apply movement
	move_and_slide()

func handle_idle_state(_delta):
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
	direction = direction.normalized()
	velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL * delta * 60.0)
	
	# Check if we've reached the target
	if global_position.distance_to(wanderController.target_position) <= WANDER_TARGET_RANGE:
		# Pick a new state
		state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
		wanderController.start_wander_timer(randi_range(1, 3))
	
	# Update sprite direction
	update_sprite_direction()

func handle_chase_state(delta):
	var player = get_player_reference()
	if player != null:
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Check if player is still within pursuit range
		if distance_to_player <= PURSUIT_RANGE:
			# Reset pursuit timer - we can still see or are close to the player
			pursuit_timer = 0.0
			last_known_player_position = player.global_position
			
			# Move toward player with wall avoidance
			move_with_wall_avoidance(player.global_position, MAX_SPEED)
			
		else:
			# Player is outside pursuit range, start counting down
			pursuit_timer += delta
			
			if pursuit_timer >= PURSUIT_TIMEOUT:
				# Give up the chase
				print(enemy_data.name + ": Lost player, giving up chase")
				state = EnemyState.WANDER
				wanderController.start_wander_timer(randi_range(1, 3))
				pursuit_timer = 0.0
			else:
				# Move toward last known position
				if last_known_player_position != Vector2.ZERO:
					move_with_wall_avoidance(last_known_player_position, MAX_SPEED * 0.7)
					
					# If we've reached the last known position, stop and look around
					if global_position.distance_to(last_known_player_position) < 10.0:
						last_known_player_position = Vector2.ZERO  # Clear the position
	else:
		# No player reference, go back to wandering
		state = EnemyState.WANDER
		wanderController.start_wander_timer(randi_range(1, 3))
		pursuit_timer = 0.0
	
	# Update sprite direction
	update_sprite_direction()

func handle_spotted_state(delta):
	# Stay in place during spotted state
	velocity = Vector2.ZERO
	
	# Count down the spotted timer
	spotted_timer -= delta
	
	if spotted_timer <= 0:
		# Spotted duration is over, start chasing
		print(enemy_data.name + ": Spotted timer finished, transitioning to CHASE state")
		state = EnemyState.CHASE
		hide_exclamation_point()

func move_with_wall_avoidance(target_position: Vector2, speed: float):
	var direction_to_target = global_position.direction_to(target_position)
	
	# Check if there's a wall in the way
	var space_state = get_world_2d().direct_space_state
	var raycast_distance = 40.0  # Check ahead
	var check_position = global_position + direction_to_target * raycast_distance
	
	var wall_detected = false
	
	# Try different collision masks to find walls
	for mask in [1, 2, 4, 8, 16]:
		var query = PhysicsRayQueryParameters2D.create(global_position, check_position)
		query.exclude = [self]
		query.collision_mask = mask
		
		var result = space_state.intersect_ray(query)
		
		if result.size() > 0:
			# Don't treat other enemies as walls to avoid
			if result.collider.is_in_group("enemies"):
				continue
				
			print(enemy_data.name + ": Wall detected - trying to go around")
			wall_detected = true
			break
	
	if wall_detected:
		# There's a wall, try to go around it
		# Simple approach: try turning 90 degrees left
		var left_direction = direction_to_target.rotated(deg_to_rad(-90))
		var avoidance_target = global_position + left_direction * 50
		
		print(enemy_data.name + ": Moving around wall to: ", avoidance_target)
		
		# Move toward avoidance target
		var avoidance_direction = global_position.direction_to(avoidance_target).normalized()
		velocity = velocity.move_toward(avoidance_direction * speed * 0.8, ACCEL * get_physics_process_delta_time() * 60.0)
	else:
		# No wall, move directly toward target
		var direction = direction_to_target.normalized()
		velocity = velocity.move_toward(direction * speed, ACCEL * get_physics_process_delta_time() * 60.0)

func update_sprite_direction():
	# Flip sprite based on movement direction
	if sprite:
		sprite.flip_h = velocity.x > 0

func seek_player():
	# Only use line of sight detection now
	var line_of_sight = get_node_or_null("LineOfSightDetection")
	if line_of_sight and line_of_sight.has_method("can_see_player"):
		# Line of sight detection handles the logic and emits signals
		line_of_sight.can_see_player()
		return
	
	# Fallback to old detection method only if line of sight doesn't exist
	if playerDetectionZone.can_see_player():
		state = EnemyState.CHASE

# Helper function to get player reference
func get_player_reference():
	# Try line of sight detection first
	var line_of_sight = get_node_or_null("LineOfSightDetection")
	if line_of_sight and line_of_sight.player:
		return line_of_sight.player
	
	# Fallback to player detection zone
	if playerDetectionZone and playerDetectionZone.player:
		return playerDetectionZone.player
	
	# Last resort - find player in the scene
	return get_tree().get_first_node_in_group("player")

# Called when player is spotted by line of sight
func _on_player_spotted():
	if state != EnemyState.SPOTTED and state != EnemyState.CHASE:
		print(enemy_data.name + ": Player spotted! Entering spotted state")
		
		# Store current facing direction
		spotted_facing_direction = get_facing_direction()
		
		state = EnemyState.SPOTTED
		spotted_timer = spotted_duration
		pursuit_timer = 0.0  # Reset pursuit timer
		
		# Store the player's position when first spotted
		var player = get_player_reference()
		if player:
			last_known_player_position = player.global_position
		
		show_exclamation_point()
		perform_hop_animation()
		play_spotted_sound()

# Called when player is lost from line of sight
func _on_player_lost():
	# Don't immediately give up if we're in chase mode - let the pursuit system handle it
	if state == EnemyState.CHASE:
		print(enemy_data.name + ": Player lost from sight but continuing pursuit")
		# The chase state will handle pursuit timeout
		return
	
	# If we're not chasing yet, return to wander
	if state != EnemyState.CHASE:
		print(enemy_data.name + ": Player lost, returning to wander")
		state = EnemyState.WANDER
		wanderController.start_wander_timer(randi_range(1, 3))

func show_exclamation_point():
	# Create a simple label-based exclamation point
	if not has_exclamation:
		var exclamation = Label.new()
		exclamation.text = "!"
		exclamation.position = Vector2(-8, -40)  # Position above the enemy
		exclamation.add_theme_font_size_override("font_size", 24)
		exclamation.add_theme_color_override("font_color", Color.RED)
		exclamation.name = "ExclamationPointInstance"
		add_child(exclamation)
		has_exclamation = true
		
		# Create pop-in animation
		exclamation.scale = Vector2.ZERO
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Scale up with bounce
		tween.tween_property(exclamation, "scale", Vector2(1.2, 1.2), 0.1)
		tween.tween_property(exclamation, "scale", Vector2.ONE, 0.1).set_delay(0.1)
		
		# Wiggle rotation
		tween.tween_property(exclamation, "rotation", deg_to_rad(10), 0.1)
		tween.tween_property(exclamation, "rotation", deg_to_rad(-10), 0.1).set_delay(0.1)
		tween.tween_property(exclamation, "rotation", 0, 0.1).set_delay(0.2)
		
		# Auto-hide after spotted duration
		var timer = get_tree().create_timer(spotted_duration - 0.2)  # Hide slightly before chase starts
		timer.timeout.connect(hide_exclamation_point)

func hide_exclamation_point():
	var exclamation = get_node_or_null("ExclamationPointInstance")
	if exclamation:
		exclamation.queue_free()
		has_exclamation = false

func perform_hop_animation():
	# Create a small hop using a tween on the sprite instead of the enemy position
	if sprite:
		var tween = create_tween()
		tween.set_parallel(true)
		
		# Store original sprite position
		var original_sprite_pos = sprite.position
		
		# Hop up and down - more pronounced hop
		tween.tween_property(sprite, "position:y", original_sprite_pos.y - 12, 0.2)
		tween.tween_property(sprite, "position:y", original_sprite_pos.y, 0.2).set_delay(0.2)
		
		# Add a little bounce
		tween.tween_property(sprite, "position:y", original_sprite_pos.y - 3, 0.1).set_delay(0.4)
		tween.tween_property(sprite, "position:y", original_sprite_pos.y, 0.1).set_delay(0.5)

func play_spotted_sound():
	# Create a temporary audio player for the spotted sound
	var audio_player = AudioStreamPlayer2D.new()
	add_child(audio_player)
	
	# Use the pause sound as a temporary alert sound - you can replace this with a custom sound
	var alert_sound = preload("res://Music and Sounds/Pause.wav")
	audio_player.stream = alert_sound
	audio_player.pitch_scale = 1.5  # Make it higher pitched for alert
	audio_player.volume_db = -5  # Make it a bit quieter
	audio_player.play()
	
	# Remove the audio player after the sound finishes
	audio_player.finished.connect(func(): audio_player.queue_free())

# Get facing direction for line of sight
func get_facing_direction() -> Vector2:
	# During spotted state, use stored facing direction
	if state == EnemyState.SPOTTED and spotted_facing_direction != Vector2.ZERO:
		return spotted_facing_direction
	
	# Use velocity if moving
	if velocity.length() > 0.1:
		return velocity.normalized()
		
	# Use sprite flip as fallback
	if sprite:
		if sprite.flip_h:
			return Vector2.RIGHT
		else:
			return Vector2.LEFT
	
	# Default fallback
	return Vector2.LEFT

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
