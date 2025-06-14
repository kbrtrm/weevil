extends Area2D

@export var detection_range: float = 120.0
@export var cone_angle: float = 90.0  # Total cone angle in degrees  
@export var wall_collision_mask: int = 1  # Physics layer for walls

var player = null
var last_player_spotted: bool = false

# Signal for when player is first spotted
signal player_spotted()
signal player_lost()

func _ready():
	# Connect the area signals
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	
	# Set up collision shape for line of sight area
	setup_detection_area()

func can_see_player() -> bool:
	if player == null:
		if last_player_spotted:
			last_player_spotted = false
			player_lost.emit()
		return false
	
	# Check if player is within cone of vision
	var enemy_position = global_position
	var player_position = player.global_position
	var distance = enemy_position.distance_to(player_position)
	
	# Check distance
	if distance > detection_range:
		if last_player_spotted:
			last_player_spotted = false
			player_lost.emit()
		return false
	
	# Get the enemy's facing direction (from parent's velocity or sprite direction)
	var enemy_facing = get_enemy_facing_direction()
	
	# Calculate angle to player
	var direction_to_player = (player_position - enemy_position).normalized()
	var angle_to_player = enemy_facing.angle_to(direction_to_player)
	var half_cone_angle = deg_to_rad(cone_angle / 2.0)
	
	# Check if player is within cone angle
	if abs(angle_to_player) > half_cone_angle:
		if last_player_spotted:
			last_player_spotted = false
			player_lost.emit()
		return false
	
	# Check for walls blocking line of sight
	if is_line_of_sight_blocked(enemy_position, player_position):
		if last_player_spotted:
			last_player_spotted = false
			player_lost.emit()
		return false
	
	# Player is visible!
	if not last_player_spotted:
		last_player_spotted = true
		player_spotted.emit()
	
	return true

func get_enemy_facing_direction() -> Vector2:
	# Get the parent enemy's facing direction
	var parent = get_parent()
	if parent and parent.has_method("get_facing_direction"):
		return parent.get_facing_direction()
	
	# Check sprite direction - CORRECTED FOR YOUR SPRITES
	if parent and parent.has_node("AnimatedSprite2D"):
		var sprite = parent.get_node("AnimatedSprite2D")
		if sprite.flip_h:
			return Vector2.RIGHT  # flip_h = true means facing right for your sprites
		else:
			return Vector2.LEFT   # flip_h = false means facing left for your sprites
	
	# Use velocity direction if moving
	if parent and "velocity" in parent:
		if parent.velocity.length() > 0.1:
			return parent.velocity.normalized()
	
	# Default facing right
	return Vector2.RIGHT

func is_line_of_sight_blocked(from: Vector2, to: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(from, to, wall_collision_mask)
	query.exclude = [get_parent()]  # Don't collide with the enemy itself
	
	var result = space_state.intersect_ray(query)
	return result.size() > 0

func _on_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_body_exited(body):
	if body.is_in_group("player"):
		player = null
		if last_player_spotted:
			last_player_spotted = false
			player_lost.emit()

func _draw():
	if Engine.is_editor_hint():
		return
	
	# Disable debug drawing for line of sight cones
	var should_draw = false  # Changed from true to false
	
	if not should_draw:
		return
	
	# Draw the cone of vision for debugging
	var enemy_facing = get_enemy_facing_direction()
	var half_cone_angle = deg_to_rad(cone_angle / 2.0)
	
	# Draw the cone
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	
	for i in range(21):  # 20 segments for smooth curve
		var angle = -half_cone_angle + (half_cone_angle * 2.0 * i / 20.0)
		var direction = enemy_facing.rotated(angle)
		points.append(direction * detection_range)
	
	# Draw the cone
	draw_colored_polygon(points, Color(1, 1, 0, 0.1))  # Yellow with transparency
	draw_polyline(points, Color(1, 1, 0, 0.5), 2.0)  # Yellow outline

func setup_detection_area():
	# Set up a circular collision shape for the detection area
	# The actual cone logic is handled in can_see_player()
	var collision_shape = get_node_or_null("CollisionShape2D")
	if collision_shape and not collision_shape.shape:
		var circle_shape = CircleShape2D.new()
		circle_shape.radius = detection_range
		collision_shape.shape = circle_shape

func _process(delta):
	# Continuously check line of sight
	can_see_player()
	
	# Disable redraw since we're not drawing debug info anymore
	# queue_redraw()  # Commented out to improve performance
	pass  # Function needs a body even with just comments
