# EnemyAI.gd - Clean enemy AI system built from scratch
extends CharacterBody2D

# === CONFIGURATION ===
@export_group("Detection")
@export var vision_range: float = 120.0
@export var vision_angle: float = 90.0  # Total cone angle in degrees
@export var proximity_range: float = 60.0  # Close detection range (half circle in front)
@export var proximity_angle: float = 180.0  # Half circle in front

@export_group("Movement")
@export var move_speed: float = 80.0
@export var acceleration: float = 400.0
@export var friction: float = 300.0

@export_group("Pursuit")
@export var pursuit_range: float = 200.0  # How far to chase before giving up
@export var pursuit_timeout: float = 5.0  # How long to search after losing target

@export_group("Patrol")
@export var patrol_range: float = 100.0  # How far from spawn point to patrol
@export var patrol_wait_time: float = 2.0  # Time to wait at patrol points

# === STATES ===
enum AIState {
	PATROL,     # Normal patrolling behavior
	ALERTED,    # Saw player, playing alert animation
	CHASE,      # Actively chasing player
	SEARCH,     # Lost player, searching last known position
	RETURN      # Returning to patrol area
}

var current_state: AIState = AIState.PATROL
var state_timer: float = 0.0

# === DETECTION SYSTEM ===
var player_reference: CharacterBody2D = null
var can_see_player: bool = false
var last_known_position: Vector2 = Vector2.ZERO
var time_since_last_seen: float = 0.0

# === PATROL SYSTEM ===
var spawn_position: Vector2
var current_patrol_target: Vector2
var patrol_points: Array[Vector2] = []
var current_patrol_index: int = 0

# === PATHFINDING ===
var pathfinding_enabled: bool = true
var current_path: Array[Vector2] = []
var path_index: int = 0
var stuck_timer: float = 0.0
var last_position: Vector2
var navigation_agent: NavigationAgent2D

# === REFERENCES ===
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var vision_area: Area2D = $VisionDetection
@onready var proximity_area: Area2D = $ProximityDetection
@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var combat_zone: Area2D = $CombatInitiationZone

# Group battle coordination
var is_in_group_coordination: bool = false
var is_paused_for_group_battle: bool = false

# Combat
var battle_initiated: bool = false
@export var battle_scene: PackedScene = preload("res://Cards/battle.tscn")
@export var enemy_data: Dictionary = {
	"name": "Clean Enemy",
	"max_health": 10,
	"base_damage": 4
}

func _ready():
	add_to_group("enemies")
	spawn_position = global_position
	
	# Initialize facing direction
	current_facing_direction = Vector2.RIGHT
	
	setup_detection_areas()
	setup_navigation()
	generate_patrol_points()
	set_state(AIState.PATROL)
	
	# Connect combat initiation
	if combat_zone:
		combat_zone.body_entered.connect(_on_combat_initiation_zone_body_entered)

# === MAIN UPDATE LOOP ===
func _physics_process(delta):
	# Check if paused for group battle
	if is_paused_for_group_battle:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	update_detection(delta)
	update_state_machine(delta)
	update_movement(delta)
	update_sprite()

# === DETECTION SYSTEM ===
func setup_detection_areas():
	# Set up vision cone
	if vision_area:
		var vision_shape = vision_area.get_node("CollisionShape2D")
		if vision_shape and not vision_shape.shape:
			var circle_shape = CircleShape2D.new()
			circle_shape.radius = vision_range
			vision_shape.shape = circle_shape
		
		vision_area.body_entered.connect(_on_vision_body_entered)
		vision_area.body_exited.connect(_on_vision_body_exited)
	
	# Set up proximity detection
	if proximity_area:
		var prox_shape = proximity_area.get_node("CollisionShape2D")
		if prox_shape and not prox_shape.shape:
			var circle_shape = CircleShape2D.new()
			circle_shape.radius = proximity_range
			prox_shape.shape = circle_shape
		
		proximity_area.body_entered.connect(_on_proximity_body_entered)
		proximity_area.body_exited.connect(_on_proximity_body_exited)

func update_detection(delta):
	if player_reference:
		var can_see_vision = check_vision_cone()
		var can_see_proximity = check_proximity_detection()
		
		var was_seeing_player = can_see_player
		can_see_player = can_see_vision or can_see_proximity
		
		if can_see_player:
			last_known_position = player_reference.global_position
			time_since_last_seen = 0.0
			
			# Trigger alert if we just started seeing the player
			if not was_seeing_player and current_state == AIState.PATROL:
				set_state(AIState.ALERTED)
		else:
			time_since_last_seen += delta

func check_vision_cone() -> bool:
	if not player_reference:
		return false
	
	var to_player = player_reference.global_position - global_position
	var distance = to_player.length()
	
	if distance > vision_range:
		return false
	
	# Check angle
	var facing_direction = get_facing_direction()
	var angle_to_player = facing_direction.angle_to(to_player.normalized())
	var half_vision_angle = deg_to_rad(vision_angle / 2.0)
	
	if abs(angle_to_player) > half_vision_angle:
		return false
	
	# Check line of sight
	return check_line_of_sight(player_reference.global_position)

func check_proximity_detection() -> bool:
	if not player_reference:
		return false
	
	var to_player = player_reference.global_position - global_position
	var distance = to_player.length()
	
	if distance > proximity_range:
		return false
	
	# Check if player is in front half-circle
	var facing_direction = get_facing_direction()
	var angle_to_player = facing_direction.angle_to(to_player.normalized())
	var half_proximity_angle = deg_to_rad(proximity_angle / 2.0)
	
	if abs(angle_to_player) > half_proximity_angle:
		return false
	
	return check_line_of_sight(player_reference.global_position)

func check_line_of_sight(target_position: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, target_position)
	query.exclude = [self]
	query.collision_mask = 1  # Walls
	
	var result = space_state.intersect_ray(query)
	return result.size() == 0

func _on_vision_body_entered(body):
	if body.is_in_group("player"):
		player_reference = body

func _on_vision_body_exited(body):
	if body == player_reference:
		# Don't immediately clear - let detection update handle it
		pass

func _on_proximity_body_entered(body):
	if body.is_in_group("player"):
		player_reference = body

func _on_proximity_body_exited(body):
	if body == player_reference:
		# Don't immediately clear - let detection update handle it
		pass

# === STATE MACHINE ===
func set_state(new_state: AIState):
	if current_state == new_state:
		return
	
	print("Enemy AI: ", AIState.keys()[current_state], " -> ", AIState.keys()[new_state])
	current_state = new_state
	state_timer = 0.0
	
	match new_state:
		AIState.ALERTED:
			play_alert_animation()
		AIState.CHASE:
			pass
		AIState.SEARCH:
			print("Enemy AI: Starting search at: ", last_known_position)
		AIState.RETURN:
			print("Enemy AI: Returning to patrol area")
		AIState.PATROL:
			generate_patrol_points()

func update_state_machine(delta):
	state_timer += delta
	
	match current_state:
		AIState.PATROL:
			handle_patrol_state(delta)
		AIState.ALERTED:
			handle_alerted_state(delta)
		AIState.CHASE:
			handle_chase_state(delta)
		AIState.SEARCH:
			handle_search_state(delta)
		AIState.RETURN:
			handle_return_state(delta)

func handle_patrol_state(delta):
	if can_see_player:
		set_state(AIState.ALERTED)
		return
	
	# Move to current patrol point
	if current_patrol_target != Vector2.ZERO:
		navigate_to_position(current_patrol_target)
		
		if global_position.distance_to(current_patrol_target) < 20.0:
			# Reached patrol point, wait then move to next
			if state_timer >= patrol_wait_time:
				next_patrol_point()
				state_timer = 0.0

func handle_alerted_state(delta):
	# Stop moving during alert
	velocity = Vector2.ZERO
	
	if state_timer >= 0.8:  # Alert animation duration
		if can_see_player:
			set_state(AIState.CHASE)
		else:
			set_state(AIState.PATROL)

func handle_chase_state(delta):
	if can_see_player:
		# Check distance to player for collision avoidance
		var distance_to_player = global_position.distance_to(player_reference.global_position)
		
		# If we're close to the player, slow down to avoid running through them
		if distance_to_player < 40.0:
			# Stop moving when very close
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		else:
			# Direct chase when farther away
			navigate_to_position(player_reference.global_position)
		
		# Check if player is too far away
		if distance_to_player > pursuit_range:
			set_state(AIState.SEARCH)
	else:
		# Lost sight, start searching
		if time_since_last_seen > 0.5:  # Small delay before searching
			set_state(AIState.SEARCH)

func handle_search_state(delta):
	if can_see_player:
		set_state(AIState.CHASE)
		return
	
	# Search last known position
	if last_known_position != Vector2.ZERO:
		navigate_to_position(last_known_position)
		
		# If we reached the search area, look around
		if global_position.distance_to(last_known_position) < 30.0:
			velocity = Vector2.ZERO
	
	# Timeout
	if state_timer >= pursuit_timeout:
		set_state(AIState.RETURN)

func handle_return_state(delta):
	if can_see_player:
		set_state(AIState.ALERTED)
		return
	
	# Return to spawn area
	navigate_to_position(spawn_position)
	
	if global_position.distance_to(spawn_position) < 50.0:
		set_state(AIState.PATROL)

# === NAVIGATION SYSTEM ===
func setup_navigation():
	if navigation_agent_2d:
		navigation_agent = navigation_agent_2d
		navigation_agent.path_desired_distance = 4.0
		navigation_agent.target_desired_distance = 4.0
		
		# Wait for navigation server
		call_deferred("_on_navigation_ready")

func _on_navigation_ready():
	await get_tree().physics_frame

func navigate_to_position(target: Vector2):
	if not navigation_agent:
		# Fallback to direct movement
		move_toward_position(target)
		return
	
	navigation_agent.target_position = target
	
	if not navigation_agent.is_navigation_finished():
		var next_position = navigation_agent.get_next_path_position()
		move_toward_position(next_position)
	else:
		move_toward_position(target)

func move_toward_position(target: Vector2):
	var direction = global_position.direction_to(target)
	var distance_to_target = global_position.distance_to(target)
	
	# Stop if we're very close to the target (collision avoidance)
	if distance_to_target < 32.0:  # Adjust this value based on your collision shapes
		velocity = velocity.move_toward(Vector2.ZERO, friction * get_physics_process_delta_time())
		return
	
	velocity = velocity.move_toward(direction * move_speed, acceleration * get_physics_process_delta_time())

# === MOVEMENT ===
func update_movement(delta):
	# Apply friction when not actively moving
	if velocity.length() < 10.0:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	
	move_and_slide()

# === FACING SYSTEM ===
# Enemy can face in 8 cardinal directions (0Â°, 45Â°, 90Â°, 135Â°, 180Â°, 225Â°, 270Â°, 315Â°)
var current_facing_direction: Vector2 = Vector2.RIGHT
var facing_change_threshold: float = 0.3  # How much movement needed to change facing

func get_facing_direction() -> Vector2:
	return current_facing_direction

func update_facing_direction():
	if velocity.length() > 10.0:
		var movement_direction = velocity.normalized()
		
		# Quantize to 8 directions (45-degree increments)
		var angle = movement_direction.angle()
		var quantized_angle = round(angle / (PI / 4)) * (PI / 4)
		var new_direction = Vector2.from_angle(quantized_angle)
		
		# Only change facing if the direction is significantly different
		if current_facing_direction.distance_to(new_direction) > facing_change_threshold:
			current_facing_direction = new_direction
			update_sprite_for_direction(new_direction)

func update_sprite_for_direction(direction: Vector2):
	if not sprite:
		return
	
	# Simple 2-directional sprite flipping
	# CORRECTED FOR YOUR SPRITES: flip_h = true means facing right
	sprite.flip_h = direction.x > 0  # Moving right = flip_h true, moving left = flip_h false

func update_sprite():
	update_facing_direction()

# === PATROL SYSTEM ===
func generate_patrol_points():
	patrol_points.clear()
	
	# Generate 3-5 random points around spawn
	var point_count = randi_range(3, 5)
	for i in range(point_count):
		var angle = (TAU / point_count) * i + randf() * 0.5  # Add some randomness
		var distance = randf_range(patrol_range * 0.3, patrol_range)
		var point = spawn_position + Vector2.from_angle(angle) * distance
		patrol_points.append(point)
	
	current_patrol_index = 0
	if patrol_points.size() > 0:
		current_patrol_target = patrol_points[0]

func next_patrol_point():
	if patrol_points.size() == 0:
		return
	
	current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
	current_patrol_target = patrol_points[current_patrol_index]

# === ANIMATIONS ===
func play_alert_animation():
	# Play exclamation point and hop
	show_exclamation_point()
	hop_animation()

func show_exclamation_point():
	var exclamation = Label.new()
	exclamation.text = "!"
	exclamation.position = Vector2(-8, -40)
	exclamation.add_theme_font_size_override("font_size", 24)
	exclamation.add_theme_color_override("font_color", Color.RED)
	add_child(exclamation)
	
	# Animate
	exclamation.scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(exclamation, "scale", Vector2.ONE, 0.2)
	tween.tween_delay(0.6)
	tween.tween_callback(func(): exclamation.queue_free())

func hop_animation():
	if sprite:
		var original_pos = sprite.position
		var tween = create_tween()
		tween.tween_property(sprite, "position:y", original_pos.y - 10, 0.15)
		tween.tween_property(sprite, "position:y", original_pos.y, 0.15)

# Group battle coordination methods
func enter_group_coordination():
	is_in_group_coordination = true
	print("CleanEnemy: Entering group coordination mode")

func exit_group_coordination():
	is_in_group_coordination = false
	print("CleanEnemy: Exiting group coordination mode")

func pause_for_group_battle():
	is_paused_for_group_battle = true
	velocity = Vector2.ZERO
	print("CleanEnemy: Paused for group battle")

func resume_from_group_battle():
	is_paused_for_group_battle = false
	print("CleanEnemy: Resumed from group battle pause")

# Combat initiation
func _on_combat_initiation_zone_body_entered(body):
	if body.is_in_group("player") and !battle_initiated and !Global.returning_from_battle:
		print("CleanEnemy: Combat initiated with player!")
		
		# Check if we should coordinate with other enemies
		if should_coordinate_group_battle():
			print("CleanEnemy: Coordinating with other enemies...")
			coordinate_group_battle()
		else:
			print("CleanEnemy: Starting individual battle...")
			start_individual_battle()

func should_coordinate_group_battle() -> bool:
	# Check if there are other enemies nearby that can also see the player
	var nearby_enemies = get_tree().get_nodes_in_group("enemies")
	var coordination_radius = 150.0
	
	print("CleanEnemy: Checking ", nearby_enemies.size(), " total enemies for coordination")
	
	for enemy in nearby_enemies:
		if enemy == self:
			continue
			
		var distance = global_position.distance_to(enemy.global_position)
		print("CleanEnemy: Enemy ", enemy.name, " at distance ", distance)
		
		if distance <= coordination_radius:
			# Check if this enemy can also see the player
			if "can_see_player" in enemy and enemy.can_see_player:
				print("CleanEnemy: Found nearby enemy that can also see player: ", enemy.name)
				return true
			elif "player_reference" in enemy and enemy.player_reference != null:
				print("CleanEnemy: Found nearby enemy with player reference: ", enemy.name)
				return true
			else:
				print("CleanEnemy: Enemy ", enemy.name, " is nearby but not chasing player")
	
	print("CleanEnemy: No coordinating enemies found - starting individual battle")
	return false

func coordinate_group_battle():
	# Find the player's combat zone and let it handle the coordination
	var player = get_player_reference()
	if player:
		var combat_zone = player.get_node_or_null("CombatInitiationZone")
		if combat_zone and combat_zone.has_method("_on_enemy_entered"):
			print("CleanEnemy: Triggering player combat zone coordination")
			combat_zone._on_enemy_entered(self)
			return
	
	# Fallback to individual battle if coordination fails
	print("CleanEnemy: Coordination failed, starting individual battle")
	start_individual_battle()

func start_individual_battle():
	battle_initiated = true
	
	print("CleanEnemy: Starting individual battle with enemy data: ", enemy_data)
	
	# Store enemy info in Global
	Global.enemy_position = global_position
	Global.current_battle_enemies = [enemy_data]
	
	print("CleanEnemy: Set Global.current_battle_enemies to: ", Global.current_battle_enemies)
	
	# Pause game and start transition
	Global.set_game_paused(true)
	Global.save_overworld_state()
	
	# Start battle transition
	var screen_pos = global_position
	TransitionManager.start_combat(screen_pos, battle_scene.resource_path)

# Helper function needed by BattleCoordinator
func get_player_reference():
	return player_reference
