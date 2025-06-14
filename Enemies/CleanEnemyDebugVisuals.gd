# CleanEnemyDebugVisuals.gd - Debug visuals for the new clean enemy AI
extends Node2D

var enemy_parent: CharacterBody2D

func _ready():
	enemy_parent = get_parent()
	
	# Disable debug visuals for release version
	visible = false

func _draw():
	if not enemy_parent:
		return
	
	# Disable debug visuals for release version
	var should_draw = false  # Changed from true to false
	
	if not should_draw:
		return
	
	# Get facing direction and draw vision cone
	var facing_dir = enemy_parent.get_facing_direction()
	draw_vision_cone(facing_dir)
	draw_proximity_detection(facing_dir)
	draw_state_info()
	draw_patrol_info()

func draw_vision_cone(facing_dir: Vector2):
	var vision_range = enemy_parent.vision_range
	var vision_angle = deg_to_rad(enemy_parent.vision_angle)
	var half_angle = vision_angle / 2.0
	
	# Create vision cone polygon
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)  # Start at enemy position
	
	# Add arc points
	var segments = 20
	for i in range(segments + 1):
		var angle = -half_angle + (vision_angle * i / segments)
		var direction = facing_dir.rotated(angle)
		points.append(direction * vision_range)
	
	# Draw filled cone
	var color = Color.YELLOW
	if enemy_parent.can_see_player:
		color = Color.RED
	
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.1))
	draw_polyline(points, Color(color.r, color.g, color.b, 0.5), 2.0)

func draw_proximity_detection(facing_dir: Vector2):
	var proximity_range = enemy_parent.proximity_range
	var proximity_angle = deg_to_rad(enemy_parent.proximity_angle)
	var half_angle = proximity_angle / 2.0
	
	# Create proximity half-circle
	var points = PackedVector2Array()
	points.append(Vector2.ZERO)
	
	# Add arc points
	var segments = 15
	for i in range(segments + 1):
		var angle = -half_angle + (proximity_angle * i / segments)
		var direction = facing_dir.rotated(angle)
		points.append(direction * proximity_range)
	
	# Draw proximity area
	var color = Color.CYAN
	draw_colored_polygon(points, Color(color.r, color.g, color.b, 0.15))
	draw_polyline(points, Color(color.r, color.g, color.b, 0.6), 1.5)

func draw_state_info():
	# Draw current state above enemy
	var state_text = str(enemy_parent.AIState.keys()[enemy_parent.current_state])
	draw_text_at_position(Vector2(0, -50), state_text, Color.WHITE)
	
	# Draw last known position if we have one
	if enemy_parent.last_known_position != Vector2.ZERO:
		var local_pos = to_local(enemy_parent.last_known_position)
		var color = Color.ORANGE
		
		# Different colors based on state
		match enemy_parent.current_state:
			enemy_parent.AIState.CHASE:
				color = Color.GREEN
			enemy_parent.AIState.SEARCH:
				color = Color.ORANGE
			_:
				color = Color.YELLOW
		
		draw_circle(local_pos, 8, color)
		draw_line(Vector2.ZERO, local_pos, Color(color.r, color.g, color.b, 0.5), 1.0)
		
		# Draw search radius if searching
		if enemy_parent.current_state == enemy_parent.AIState.SEARCH:
			draw_arc(local_pos, 30, 0, TAU, 16, Color(color.r, color.g, color.b, 0.3), 1.0)

func draw_patrol_info():
	# Draw spawn position
	var spawn_local = to_local(enemy_parent.spawn_position)
	draw_circle(spawn_local, 5, Color.BLUE)
	
	# Draw patrol range
	draw_arc(spawn_local, enemy_parent.patrol_range, 0, TAU, 32, Color(0, 0, 1, 0.2), 1.0)
	
	# Draw patrol points
	for point in enemy_parent.patrol_points:
		var point_local = to_local(point)
		var color = Color.LIGHT_BLUE
		if point == enemy_parent.current_patrol_target:
			color = Color.MAGENTA  # Highlight current target
		
		draw_circle(point_local, 3, color)
	
	# Draw line to current patrol target
	if enemy_parent.current_patrol_target != Vector2.ZERO:
		var target_local = to_local(enemy_parent.current_patrol_target)
		draw_line(Vector2.ZERO, target_local, Color(1, 0, 1, 0.4), 1.0)

func draw_text_at_position(pos: Vector2, text: String, color: Color):
	# Simple text drawing - in a real project you'd want to use a Label
	# For now, just draw a colored circle to represent the state
	var state_color = Color.WHITE
	match text:
		"PATROL":
			state_color = Color.BLUE
		"ALERTED":
			state_color = Color.YELLOW
		"CHASE":
			state_color = Color.RED
		"SEARCH":
			state_color = Color.ORANGE
		"RETURN":
			state_color = Color.PURPLE
	
	draw_circle(pos, 8, state_color)

func _process(_delta):
	# Disable redraw since we're not drawing debug info anymore
	# queue_redraw()  # Commented out to improve performance
	pass  # Function needs a body
