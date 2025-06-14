extends Node2D

var enemy_parent: CharacterBody2D

func _ready():
	enemy_parent = get_parent()
	# Hide debug visuals for release version
	visible = false

func _draw():
	if not enemy_parent:
		return
	
	# Disable debug drawing for release version
	var should_draw = false  # Changed from true to false
	
	if not should_draw:
		return
	
	# Only draw when enemy is in chase mode
	if enemy_parent.state == enemy_parent.EnemyState.CHASE:
		# Draw pursuit circle
		var pursuit_range = enemy_parent.PURSUIT_RANGE
		draw_arc(Vector2.ZERO, pursuit_range, 0, TAU, 32, Color(0, 1, 0, 0.6), 4.0)  # Green circle
		
		# Draw a dot at last known player position if we have one
		if enemy_parent.last_known_player_position != Vector2.ZERO:
			var local_pos = to_local(enemy_parent.last_known_player_position)
			
			# Different colors based on whether we're investigating
			var color = Color(1, 1, 0, 0.9)  # Yellow for last known position
			if enemy_parent.investigating_last_position:
				color = Color(1, 0.5, 0, 0.9)  # Orange when investigating
			
			draw_circle(local_pos, 15, color)
			
			# Draw investigation radius around last known position
			if enemy_parent.investigating_last_position:
				draw_arc(local_pos, enemy_parent.investigation_radius, 0, TAU, 32, Color(1, 0.5, 0, 0.3), 2.0)
			
			# Draw line from enemy to last known position
			draw_line(Vector2.ZERO, local_pos, Color(1, 1, 0, 0.5), 2.0)

func _process(_delta):
	# Disable redraw since we're not drawing debug info anymore
	# queue_redraw()  # Commented out to improve performance
	pass  # Function needs a body
