# BaseEnemy.gd - Clean version without duplicates - UPDATED
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
@export var battle_scene: PackedScene = preload("res://Cards/battle.tscn")

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

# Last known position system
var last_known_player_position: Vector2 = Vector2.ZERO  # Last position where we saw the player
var time_since_last_seen: float = 0.0  # How long since we last saw the player
var investigating_last_position: bool = false  # Are we currently investigating last known position
var investigation_radius: float = 50.0  # How close to get to last known position before giving up

# Exclamation/Spotted cooldowns
@export var SPOTTED_COOLDOWN: float = 3.0  # Minimum time between exclamation animations
var last_spotted_time: float = 0.0  # Time when last spotted animation played

# Wall avoidance stability
var current_avoidance_direction: Vector2 = Vector2.ZERO
var avoidance_timer: float = 0.0
var avoidance_duration: float = 1.0  # How long to stick with an avoidance direction

# Flag to prevent multiple battle initiations
var battle_initiated: bool = false
# Unique ID for tracking this enemy
var unique_id: int = -1

# Group battle coordination
var is_in_group_coordination: bool = false
var is_paused_for_group_battle: bool = false

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
var spotted_facing_direction: Vector2  # Direction enemy was facing when player was spotted

func _ready():
	# Initialize unique ID for tracking
	init_unique_id()
	
	# Check if already defeated
	check_if_defeated()
	
	# Init state
	add_to_group("enemies")
	# Start in IDLE state to avoid random wandering before properly checking for player
	state = EnemyState.IDLE
	
	# Connect combat initiation signal
	var combat_zone = get_node_or_null("CombatInitiationZone")
	if combat_zone:
		if not combat_zone.body_entered.is_connected(_on_combat_initiation_zone_body_entered):
			combat_zone.body_entered.connect(_on_combat_initiation_zone_body_entered)
	
	# Connect line of sight signals if available
	var line_of_sight = get_node_or_null("LineOfSightDetection")
	if line_of_sight:
		if line_of_sight.has_signal("player_spotted") and not line_of_sight.player_spotted.is_connected(_on_player_spotted):
			line_of_sight.player_spotted.connect(_on_player_spotted)
		if line_of_sight.has_signal("player_lost") and not line_of_sight.player_lost.is_connected(_on_player_lost):
			line_of_sight.player_lost.connect(_on_player_lost)
	
	# Start checking for player immediately - don't wait for wander timer
	# This ensures enemies start tracking player position from the beginning
	call_deferred("start_player_detection")

# Start player detection immediately (called after _ready)
func start_player_detection():
	# Check for player immediately
	seek_player()
	
	# If no player detected yet, start with a short idle period before wandering
	# This gives the player detection systems time to initialize properly
	if state == EnemyState.IDLE:
		wanderController.start_wander_timer(randf_range(0.5, 1.5))  # Shorter initial timer

func check_if_defeated():
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		var scene_path = get_tree().current_scene.scene_file_path
		
		# Check if this enemy is in the defeated list
		if global.has_method("is_enemy_defeated") and global.is_enemy_defeated(scene_path, unique_id):
			remove_defeated_enemy()
			return true
	
	return false

func remove_defeated_enemy():
	# Make invisible immediately and queue_free
	modulate.a = 0
	visible = false
	queue_free()

func _physics_process(delta):
	# Check if paused for group battle
	if is_paused_for_group_battle:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# ALWAYS check for player first, regardless of state
	# This ensures enemies start tracking the player immediately
	seek_player()
	
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

func handle_idle_state(delta):
	# Player detection is now handled in _physics_process before states
	
	# Check if wander timer is done
	if wanderController.get_time_left() == 0:
		# Only change to wandering if we're not already chasing or spotted
		if state == EnemyState.IDLE:
			# Pick a new random state
			state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
			wanderController.start_wander_timer(randi_range(1, 3))

func handle_wander_state(delta):
	# Player detection is now handled in _physics_process before states
	
	# Check if wander timer is done
	if wanderController.get_time_left() == 0:
		# Only change state if we're not already chasing or spotted
		if state == EnemyState.WANDER:
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
		# Only pick new state if we're still wandering
		if state == EnemyState.WANDER:
			# Pick a new state
			state = pick_random_state([EnemyState.IDLE, EnemyState.WANDER])
			wanderController.start_wander_timer(randi_range(1, 3))
	
	# Update sprite direction
	update_sprite_direction()

func handle_chase_state(delta):
	var player = get_player_reference()
	
	# Always update time since last seen
	time_since_last_seen += delta
	
	# Check if we can currently see the player
	var can_see_player_now = false
	var line_of_sight = get_node_or_null("LineOfSightDetection")
	if line_of_sight and line_of_sight.has_method("can_see_player"):
		can_see_player_now = line_of_sight.can_see_player()
	elif playerDetectionZone and playerDetectionZone.can_see_player():
		can_see_player_now = true
	
	if player != null and can_see_player_now:
		# We can see the player right now
		var distance_to_player = global_position.distance_to(player.global_position)
		
		# Update last known position and reset timers
		last_known_player_position = player.global_position
		time_since_last_seen = 0.0
		investigating_last_position = false
		pursuit_timer = 0.0
		
		print(enemy_data.name + ": Can see player at ", player.global_position)
		
		# Move directly toward the player
		move_toward_target_with_avoidance(player.global_position, MAX_SPEED)
		
	elif last_known_player_position != Vector2.ZERO:
		# We can't see the player, but we have a last known position
		var distance_to_last_known = global_position.distance_to(last_known_player_position)
		
		if not investigating_last_position:
			print(enemy_data.name + ": Lost sight of player, investigating last known position: ", last_known_player_position)
			investigating_last_position = true
		
		if distance_to_last_known > investigation_radius:
			# Move toward last known position
			print(enemy_data.name + ": Moving to investigate last known position, distance: ", distance_to_last_known)
			move_toward_target_with_avoidance(last_known_player_position, MAX_SPEED * 0.8)
		else:
			# We've reached the last known position, look around briefly
			print(enemy_data.name + ": Reached last known position, looking around...")
			velocity = velocity.move_toward(Vector2.ZERO, FRICTION * 2 * delta)
			
			# After investigating for a bit, give up
			if time_since_last_seen > PURSUIT_TIMEOUT:
				print(enemy_data.name + ": Investigation complete, giving up chase")
				state = EnemyState.WANDER
				wanderController.start_wander_timer(randi_range(1, 3))
				last_known_player_position = Vector2.ZERO
				investigating_last_position = false
				time_since_last_seen = 0.0
				# Reset avoidance system
				current_avoidance_direction = Vector2.ZERO
				avoidance_timer = 0.0
		
		# Timeout if we've been looking for too long
		if time_since_last_seen > PURSUIT_TIMEOUT * 2:  # Give extra time for investigation
			print(enemy_data.name + ": Investigation timeout, giving up chase")
			state = EnemyState.WANDER
			wanderController.start_wander_timer(randi_range(1, 3))
			last_known_player_position = Vector2.ZERO
			investigating_last_position = false
			time_since_last_seen = 0.0
			# Reset avoidance system
			current_avoidance_direction = Vector2.ZERO
			avoidance_timer = 0.0
	else:
		# No player reference and no last known position, go back to wandering
		print(enemy_data.name + ": No player or last known position, returning to wander")
		state = EnemyState.WANDER
		wanderController.start_wander_timer(randi_range(1, 3))
		investigating_last_position = false
		time_since_last_seen = 0.0
		# Reset avoidance system
		current_avoidance_direction = Vector2.ZERO
		avoidance_timer = 0.0
	
	# Update avoidance timer
	if avoidance_timer > 0.0:
		avoidance_timer -= delta
	
	# Update sprite direction
	update_sprite_direction()

func handle_spotted_state(delta):
	# Stay in place during spotted state
	velocity = Vector2.ZERO
	
	print(enemy_data.name + ": In spotted state, timer: ", spotted_timer)
	
	# Don't change facing direction during spotted state - let the enemy maintain its current facing
	# The enemy should face the direction it was moving when it spotted the player
	
	# Count down the spotted timer
	spotted_timer -= delta
	
	if spotted_timer <= 0:
		# Spotted duration is over, start chasing
		print(enemy_data.name + ": Spotted timer finished, transitioning to CHASE state")
		state = EnemyState.CHASE
		hide_exclamation_point()

func update_sprite_direction():
	# Flip sprite based on movement direction
	# CORRECTED LOGIC FOR YOUR SPRITES: flip_h = false means facing left
	if sprite:
		sprite.flip_h = velocity.x > 0  # Moving right = flip_h true, moving left = flip_h false

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
	# Check cooldown to prevent spam
	var current_time = Time.get_time_dict_from_system()
	var current_timestamp = current_time.hour * 3600 + current_time.minute * 60 + current_time.second
	
	# Use engine time for more precise cooldown tracking
	var engine_time = Time.get_ticks_msec() / 1000.0
	
	# Always update last known position when we spot the player
	var player = get_player_reference()
	if player:
		last_known_player_position = player.global_position
		time_since_last_seen = 0.0
		investigating_last_position = false
		print(enemy_data.name + ": Updated last known position to ", last_known_player_position)
	
	if engine_time - last_spotted_time < SPOTTED_COOLDOWN:
		print(enemy_data.name + ": Player spotted but still in cooldown")
		# Still go to chase if not already there, but skip the animation
		if state != EnemyState.SPOTTED and state != EnemyState.CHASE:
			state = EnemyState.CHASE
		return
	
	if state != EnemyState.SPOTTED and state != EnemyState.CHASE:
		print(enemy_data.name + ": Player spotted! Entering spotted state")
		
		# Update last spotted time
		last_spotted_time = engine_time
		
		# Store current facing direction
		spotted_facing_direction = get_facing_direction()
		
		state = EnemyState.SPOTTED
		spotted_timer = spotted_duration
		pursuit_timer = 0.0  # Reset pursuit timer
		
		show_exclamation_point()
		perform_hop_animation()
		play_spotted_sound()

# Called when player is lost from line of sight
func _on_player_lost():
	print(enemy_data.name + ": Player lost from line of sight")
	
	# If we're in chase mode, don't immediately give up - let the chase system handle investigation
	if state == EnemyState.CHASE:
		print(enemy_data.name + ": In chase mode, will investigate last known position")
		# Don't clear last_known_player_position here - let chase state handle it
		return
	
	# If we're not chasing yet, return to wander
	if state != EnemyState.CHASE:
		print(enemy_data.name + ": Not in chase mode, returning to wander")
		state = EnemyState.WANDER
		wanderController.start_wander_timer(randi_range(1, 3))

func move_toward_target_with_avoidance(target_position: Vector2, speed: float):
	var direction_to_target = global_position.direction_to(target_position)
	var distance_to_target = global_position.distance_to(target_position)
	
	# If we're very close to the target (likely the player), just move directly toward them
	# This prevents circling behavior when trying to reach the combat initiation zone
	if distance_to_target < 60.0:
		var direction = direction_to_target.normalized()
		velocity = velocity.move_toward(direction * speed, ACCEL * get_physics_process_delta_time() * 60.0)
		# Clear avoidance when close to target
		current_avoidance_direction = Vector2.ZERO
		avoidance_timer = 0.0
		return
	
	# If we're currently in an avoidance maneuver, stick with it for stability
	if avoidance_timer > 0.0 and current_avoidance_direction != Vector2.ZERO:
		print(enemy_data.name + ": Continuing avoidance maneuver, timer: ", avoidance_timer)
		velocity = velocity.move_toward(current_avoidance_direction * speed * 0.8, ACCEL * get_physics_process_delta_time() * 60.0)
		return
	
	# Check if there's a wall in the way for longer distances
	var space_state = get_world_2d().direct_space_state
	var raycast_distance = 40.0  # Check ahead
	var check_position = global_position + direction_to_target * raycast_distance
	
	var wall_detected = false
	var wall_point = Vector2.ZERO
	var wall_normal = Vector2.ZERO
	
	# Get player reference to exclude from collision detection
	var player = get_player_reference()
	
	# Try different collision masks to find walls (only check walls, not characters)
	for mask in [1]:  # Only check mask 1 (typically walls/environment)
		var query = PhysicsRayQueryParameters2D.create(global_position, check_position)
		var exclude_bodies = [self]
		
		# Also exclude the player from collision detection
		if player:
			exclude_bodies.append(player)
		
		query.exclude = exclude_bodies
		query.collision_mask = mask
		
		var result = space_state.intersect_ray(query)
		
		if result.size() > 0:
			# Don't treat other enemies or the player as walls to avoid
			if result.collider.is_in_group("enemies") or result.collider.is_in_group("player"):
				continue
				
			wall_detected = true
			wall_point = result.position
			wall_normal = result.normal
			break
	
	if wall_detected:
		# Start a new avoidance maneuver - find the best direction and stick with it
		current_avoidance_direction = find_best_avoidance_direction(target_position, wall_point, wall_normal)
		avoidance_timer = avoidance_duration
		
		print(enemy_data.name + ": Wall detected, starting new avoidance maneuver")
		
		# Move toward the avoidance direction
		velocity = velocity.move_toward(current_avoidance_direction * speed * 0.8, ACCEL * get_physics_process_delta_time() * 60.0)
	else:
		# No wall, move directly toward target
		var direction = direction_to_target.normalized()
		velocity = velocity.move_toward(direction * speed, ACCEL * get_physics_process_delta_time() * 60.0)
		
		# Clear any previous avoidance
		current_avoidance_direction = Vector2.ZERO
		avoidance_timer = 0.0

# Smart wall avoidance - finds the best direction to go around obstacles
func find_best_avoidance_direction(target_position: Vector2, wall_point: Vector2, wall_normal: Vector2) -> Vector2:
	var direction_to_target = global_position.direction_to(target_position)
	
	# First, try to find corners by casting rays at different angles
	var space_state = get_world_2d().direct_space_state
	var player = get_player_reference()
	
	# Try smaller angles first to find the most direct route around
	var test_angles = [30, -30, 45, -45, 60, -60, 90, -90]  # Degrees to test
	var test_distance = 80.0  # How far to test for clear path (increased for better corner detection)
	
	for angle_deg in test_angles:
		var test_angle = deg_to_rad(angle_deg)
		var test_direction = direction_to_target.rotated(test_angle)
		var test_end_point = global_position + test_direction * test_distance
		
		# Test if this direction is clear
		var query = PhysicsRayQueryParameters2D.create(global_position, test_end_point)
		query.exclude = [self]
		if player:
			query.exclude.append(player)
		query.collision_mask = 1  # Only check walls
		
		var result = space_state.intersect_ray(query)
		
		if result.size() == 0:
			# This direction is clear! 
			print(enemy_data.name + ": Found clear path at ", angle_deg, " degrees")
			return test_direction.normalized()
		elif result.size() > 0:
			# Check if we hit an enemy or player (which we should ignore)
			if result.collider.is_in_group("enemies") or result.collider.is_in_group("player"):
				print(enemy_data.name + ": Found clear path at ", angle_deg, " degrees (ignoring character)")
				return test_direction.normalized()
	
	# If no clear direction found through angle testing, use more advanced corner-finding
	# Cast rays perpendicular to the wall to find edges/corners
	var perpendicular_left = wall_normal.rotated(deg_to_rad(90))
	var perpendicular_right = wall_normal.rotated(deg_to_rad(-90))
	
	# Test both sides to find which way leads to a corner
	var left_corner_distance = find_corner_distance(perpendicular_left, 100.0)
	var right_corner_distance = find_corner_distance(perpendicular_right, 100.0)
	
	print(enemy_data.name + ": Corner distances - Left: ", left_corner_distance, " Right: ", right_corner_distance)
	
	# Choose the direction with the closer corner
	var chosen_direction: Vector2
	if left_corner_distance < right_corner_distance:
		chosen_direction = perpendicular_left
		print(enemy_data.name + ": Choosing left corner direction")
	else:
		chosen_direction = perpendicular_right
		print(enemy_data.name + ": Choosing right corner direction")
	
	return chosen_direction.normalized()

# Helper function to find distance to nearest corner in a direction
func find_corner_distance(direction: Vector2, max_distance: float) -> float:
	var space_state = get_world_2d().direct_space_state
	var player = get_player_reference()
	
	var test_end = global_position + direction * max_distance
	var query = PhysicsRayQueryParameters2D.create(global_position, test_end)
	query.exclude = [self]
	if player:
		query.exclude.append(player)
	query.collision_mask = 1
	
	var result = space_state.intersect_ray(query)
	
	if result.size() > 0:
		# Hit a wall, return distance to that wall (this might be a corner)
		return global_position.distance_to(result.position)
	else:
		# No wall hit, return max distance (indicating open space/corner)
		return max_distance

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
		
	# Use sprite flip as fallback - CORRECTED FOR YOUR SPRITES
	if sprite:
		if sprite.flip_h:
			return Vector2.RIGHT  # flip_h = true means facing right for your sprites
		else:
			return Vector2.LEFT   # flip_h = false means facing left for your sprites
	
	# Default fallback
	return Vector2.RIGHT

func pick_random_state(state_list):
	state_list.shuffle()
	return state_list.pop_front()

# Combat initiation
func _on_combat_initiation_zone_body_entered(body):
	# Check if it's the player and battle isn't already triggered
	if body.is_in_group("player") and !battle_initiated and !Global.returning_from_battle:
		print(enemy_data.name + ": Combat initiated with player!")
		
		# Check if we should coordinate with other enemies
		if should_coordinate_group_battle():
			print(enemy_data.name + ": Coordinating with other enemies...")
			coordinate_group_battle()
		else:
			print(enemy_data.name + ": Starting individual battle...")
			start_individual_battle()

func should_coordinate_group_battle() -> bool:
	# Check if there are other enemies nearby that can also see the player
	var nearby_enemies = get_tree().get_nodes_in_group("enemies")
	var coordination_radius = 150.0
	
	print(enemy_data.name + ": Checking ", nearby_enemies.size(), " total enemies for coordination")
	
	for enemy in nearby_enemies:
		if enemy == self:
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		print(enemy_data.name + ": Enemy ", enemy.name, " at distance ", distance)
		
		if distance <= coordination_radius:
			# Check if this enemy can also see/detect the player
			var enemy_can_see_player = false
			
			# Check for BaseEnemy with line of sight
			if enemy.has_node("LineOfSightDetection"):
				var los = enemy.get_node("LineOfSightDetection")
				if los.has_method("can_see_player"):
					enemy_can_see_player = los.can_see_player()
			
			# Check for CleanEnemy
			if "can_see_player" in enemy:
				enemy_can_see_player = enemy.can_see_player
			
			# Check enemy state for BaseEnemy
			if "state" in enemy:
				var enemy_state = enemy.state
				if enemy.has_method("get") and enemy.get("EnemyState"):
					if enemy_state == enemy.EnemyState.CHASE or enemy_state == enemy.EnemyState.SPOTTED:
						enemy_can_see_player = true
			
			if enemy_can_see_player:
				print(enemy_data.name + ": Found nearby enemy that can also see player: ", enemy.name)
				return true
			else:
				print(enemy_data.name + ": Enemy ", enemy.name, " is nearby but not detecting player")
	
	print(enemy_data.name + ": No coordinating enemies found - starting individual battle")
	return false

func coordinate_group_battle():
	# Collect enemy data from all nearby enemies that can see the player
	var enemy_data_list = [enemy_data]  # Start with this enemy
	var enemy_ids_list = [unique_id]  # Start with this enemy's ID
	var nearby_enemies = get_tree().get_nodes_in_group("enemies")
	var coordination_radius = 150.0
	
	for enemy in nearby_enemies:
		if enemy == self:
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		if distance <= coordination_radius:
			# Check if this enemy can see the player and has enemy_data
			var enemy_can_see_player = false
			
			# Check different enemy types
			if enemy.has_node("LineOfSightDetection"):
				var los = enemy.get_node("LineOfSightDetection")
				if los.has_method("can_see_player"):
					enemy_can_see_player = los.can_see_player()
			
			if "can_see_player" in enemy:
				enemy_can_see_player = enemy.can_see_player
			
			if "state" in enemy and "EnemyState" in enemy:
				var enemy_state = enemy.state
				if enemy_state == enemy.EnemyState.CHASE or enemy_state == enemy.EnemyState.SPOTTED:
					enemy_can_see_player = true
			
			if enemy_can_see_player and "enemy_data" in enemy and "unique_id" in enemy:
				enemy_data_list.append(enemy.enemy_data)
				enemy_ids_list.append(enemy.unique_id)
				print(enemy_data.name + ": Added enemy to group battle: ", enemy.enemy_data.name, " with ID: ", enemy.unique_id)
				
				# Mark that enemy as having initiated battle too
				if "battle_initiated" in enemy:
					enemy.battle_initiated = true
	
	print(enemy_data.name + ": Group battle with ", enemy_data_list.size(), " enemies and IDs: ", enemy_ids_list)
	
	# Set up the group battle with both data and IDs
	start_group_battle_with_enemies(enemy_data_list, enemy_ids_list)

func start_individual_battle():
	# Validate unique ID
	if unique_id == -1:
		print("WARNING: Enemy has no ID during combat initiation! Generating now...")
		init_unique_id()
	
	# Store enemy info in Global
	Global.enemy_position = global_position
	Global.current_enemy_id = unique_id
	Global.current_battle_enemies = [enemy_data]
	Global.current_battle_enemy_ids = [unique_id]  # Also store ID for individual battles
	
	print(enemy_data.name + ": Starting individual battle with ID " + str(unique_id))
	
	# Start battle
	start_battle(get_screen_position())

func start_group_battle_with_enemies(enemies_data: Array, enemy_ids: Array = []):
	# Validate unique ID
	if unique_id == -1:
		print("WARNING: Enemy has no ID during combat initiation! Generating now...")
		init_unique_id()
	
	# Store enemy info in Global
	Global.enemy_position = global_position
	Global.current_enemy_id = unique_id
	Global.current_battle_enemies = enemies_data
	
	# If we have enemy IDs, store them for group battle defeat tracking
	if enemy_ids.size() > 0:
		Global.current_battle_enemy_ids = enemy_ids
		print(enemy_data.name + ": Starting group battle with enemy IDs: ", enemy_ids)
	else:
		# Fallback - just use the initiating enemy's ID
		Global.current_battle_enemy_ids = [unique_id]
		print(enemy_data.name + ": Starting group battle with fallback ID: ", [unique_id])
	
	print(enemy_data.name + ": Starting group battle with ", enemies_data.size(), " enemies")
	print(enemy_data.name + ": Enemy data: ", enemies_data)
	
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
	
	# DON'T override Global.current_battle_enemies if already set
	if Global.current_battle_enemies.size() == 0:
		Global.current_battle_enemies = [enemy_data]
		print(enemy_data.name + ": Set battle enemies to single enemy")
	else:
		print(enemy_data.name + ": Battle enemies already set to: ", Global.current_battle_enemies)
	
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

# Pathfinding functions (simplified - navigation agent not currently used)
func setup_navigation():
	# Reserved for future pathfinding implementation
	pass

# Duplicate function removed - original implementation is used above

# Simple pathfinding helper functions
func should_use_pathfinding_to_player_position(target_position: Vector2) -> bool:
	# Check if direct line to target is blocked by walls
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_position)
	query.exclude = [self]  # Don't hit ourselves
	query.collision_mask = 1  # Assuming walls are on layer 1
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0  # Path is blocked if we hit something

func use_smart_movement_fallback(target_position: Vector2, speed: float = MAX_SPEED):
	# When pathfinding isn't available, try intelligent movement
	var direct_direction = global_position.direction_to(target_position)
	
	print(enemy_data.name + ": Smart movement to ", target_position, " from ", global_position)
	
	# Check if direct path is blocked
	var space_state = get_world_2d().direct_space_state
	var check_distance = min(32.0, global_position.distance_to(target_position))
	var check_position = global_position + direct_direction * check_distance
	
	var query = PhysicsRayQueryParameters2D.create(global_position, check_position)
	query.exclude = [self]
	query.collision_mask = 1  # Check walls
	
	var result = space_state.intersect_ray(query)
	
	if result.size() > 0:
		print(enemy_data.name + ": Direct path blocked by ", result.collider, " - trying alternatives")
		# Path is blocked, try alternative directions
		var alternative_directions = [
			direct_direction.rotated(deg_to_rad(45)),   # Try 45Â° clockwise
			direct_direction.rotated(deg_to_rad(-45)),  # Try 45Â° counter-clockwise
			direct_direction.rotated(deg_to_rad(90)),   # Try 90Â° clockwise
			direct_direction.rotated(deg_to_rad(-90)),  # Try 90Â° counter-clockwise
		]
		
		# Find the first unblocked direction
		for i in range(alternative_directions.size()):
			var alt_direction = alternative_directions[i]
			var alt_check_pos = global_position + alt_direction * check_distance
			var alt_query = PhysicsRayQueryParameters2D.create(global_position, alt_check_pos)
			alt_query.exclude = [self]
			alt_query.collision_mask = 1
			
			var alt_result = space_state.intersect_ray(alt_query)
			if alt_result.size() == 0:
				# This direction is clear, use it
				var new_target = global_position + alt_direction * 100
				print(enemy_data.name + ": Using alternative direction ", i, " towards ", new_target)
				move_directly_toward_target(new_target, speed * 0.8)
				return
			else:
				print(enemy_data.name + ": Alternative direction ", i, " also blocked by ", alt_result.collider)
		
		# If all directions are blocked, try backing up slightly and then moving
		var backup_direction = -direct_direction
		var backup_target = global_position + backup_direction * 20
		print(enemy_data.name + ": All directions blocked, backing up to ", backup_target)
		move_directly_toward_target(backup_target, speed * 0.5)
	else:
		print(enemy_data.name + ": Direct path clear, moving directly")
		# Direct path is clear, move normally
		move_directly_toward_target(target_position, speed)

func move_directly_toward_target(target_position: Vector2, speed: float):
	var direction = global_position.direction_to(target_position)
	direction = direction.normalized()
	print(enemy_data.name + ": Moving toward ", target_position, " with direction ", direction, " and speed ", speed)
	velocity = velocity.move_toward(direction * speed, ACCEL * get_physics_process_delta_time() * 60.0)
	print(enemy_data.name + ": Resulting velocity: ", velocity)

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

# Group battle coordination methods
func enter_group_coordination():
	is_in_group_coordination = true
	print(enemy_data.name + ": Entering group coordination mode")

func exit_group_coordination():
	is_in_group_coordination = false
	print(enemy_data.name + ": Exiting group coordination mode")

func pause_for_group_battle():
	is_paused_for_group_battle = true
	velocity = Vector2.ZERO
	print(enemy_data.name + ": Paused for group battle")

func resume_from_group_battle():
	is_paused_for_group_battle = false
	print(enemy_data.name + ": Resumed from group battle pause")
