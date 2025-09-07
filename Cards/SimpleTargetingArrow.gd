# SimpleTargetingArrow.gd
extends Node2D
class_name SimpleTargetingArrow

# Arrow visual properties
const ARROW_SEGMENTS = 15
const ARROW_CURVE_HEIGHT = 60
const DOT_SIZE = 4
const DOT_SPACING = 8
const ARROW_HEAD_SIZE = 12  # Reduced from 14 to 12

# Components
var dot_particles: Array[ColorRect] = []
var arrow_head: Polygon2D
var start_position: Vector2
var is_active: bool = false

func _ready():
	# Set lower z-index to appear behind cards
	z_index = 100
	
	# Create arrow head
	arrow_head = Polygon2D.new()
	arrow_head.color = Color(1.0, 1.0, 1.0, 1.0)  # Fully opaque white
	arrow_head.z_index = 102
	
	# Arrow head triangle points - wider triangle
	var points = PackedVector2Array()
	points.append(Vector2(ARROW_HEAD_SIZE, 0))           # Tip point
	points.append(Vector2(-ARROW_HEAD_SIZE/2, -ARROW_HEAD_SIZE * 0.8))  # Top back corner (wider)
	points.append(Vector2(-ARROW_HEAD_SIZE/2, ARROW_HEAD_SIZE * 0.8))   # Bottom back corner (wider)
	arrow_head.polygon = points
	add_child(arrow_head)
	
	# Start hidden
	visible = false

func show_arrow(from_position: Vector2):
	"""Show the targeting arrow starting from the given position"""
	start_position = from_position
	is_active = true
	visible = true

func hide_arrow():
	"""Hide the targeting arrow"""
	is_active = false
	visible = false
	clear_dots()

func update_arrow(to_position: Vector2):
	"""Update the arrow to point to the given position"""
	if not is_active:
		return
	
	var distance = start_position.distance_to(to_position)
	if distance < 20:
		clear_dots()
		arrow_head.visible = false
		return
	
	# Calculate curve points
	var curve_points = calculate_curved_points(start_position, to_position)
	
	# Create dots along the curve
	create_dots_along_curve(curve_points)
	
	# Update arrow head
	if curve_points.size() >= 2:
		var last_point = curve_points[-1]
		var second_last = curve_points[-2]
		var direction = (last_point - second_last).normalized()
		
		arrow_head.position = last_point
		arrow_head.rotation = direction.angle()
		arrow_head.visible = true
	else:
		arrow_head.visible = false

func create_dots_along_curve(curve_points: PackedVector2Array):
	"""Create white dots along the curve path"""
	clear_dots()
	
	if curve_points.size() < 2:
		return
	
	# Calculate total curve length
	var total_length = 0.0
	for i in range(curve_points.size() - 1):
		total_length += curve_points[i].distance_to(curve_points[i + 1])
	
	# Create dots at regular intervals
	var current_distance = 0.0
	var dot_interval = DOT_SPACING
	var last_dot_distance = 0.0
	
	for i in range(curve_points.size() - 1):
		var segment_start = curve_points[i]
		var segment_end = curve_points[i + 1]
		var segment_length = segment_start.distance_to(segment_end)
		
		# Check if we need to place dots in this segment
		while last_dot_distance + dot_interval <= current_distance + segment_length:
			var target_distance = last_dot_distance + dot_interval
			var segment_progress = (target_distance - current_distance) / segment_length
			var dot_position = segment_start.lerp(segment_end, segment_progress)
			
			create_dot(dot_position)
			last_dot_distance = target_distance
		
		current_distance += segment_length

func create_dot(position: Vector2):
	"""Create a single white dot at the given position"""
	var dot = ColorRect.new()
	dot.size = Vector2(DOT_SIZE, DOT_SIZE)
	dot.color = Color(1.0, 1.0, 1.0, 1.0)  # Fully opaque white
	dot.position = position - Vector2(DOT_SIZE/2, DOT_SIZE/2)  # Center the dot
	dot.z_index = 101  # Behind cards
	
	add_child(dot)
	dot_particles.append(dot)

func clear_dots():
	"""Remove all dots"""
	for dot in dot_particles:
		if is_instance_valid(dot):
			dot.queue_free()
	dot_particles.clear()

func calculate_curved_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	"""Calculate points for a curved line with dynamic curve direction based on card center"""
	var points = PackedVector2Array()
	
	var distance = from.distance_to(to)
	if distance < 20:
		return points
	
	# Calculate the direction vector and perpendicular
	var direction = (to - from).normalized()
	var perpendicular = Vector2(-direction.y, direction.x)  # Perpendicular vector
	
	# Determine curve direction based on mouse position relative to card center
	var mid_point = (from + to) / 2
	var curve_height = min(ARROW_CURVE_HEIGHT, distance * 0.3)
	
	# Get card center position (arrow starts from top of card, so card center is 62 pixels down)
	var card_center = from + Vector2(0, 62)
	
	# Calculate horizontal distance from mouse to card center
	var horizontal_distance = abs(to.x - card_center.x)
	
	# Determine curve direction: if mouse is left of card center, curve left
	var curve_direction_multiplier = 1.0
	if to.x < card_center.x:
		curve_direction_multiplier = 1.0   # Curve left when mouse is left of card
	else:
		curve_direction_multiplier = -1.0  # Curve right when mouse is right of card
	
	# Distance-based curve flattening: closer to center = flatter curve
	var max_curve_distance = 200.0  # Distance at which curve is at maximum
	var distance_factor = min(horizontal_distance / max_curve_distance, 1.0)
	
	# Minimum curve factor to ensure some curve is always visible
	var min_curve_factor = 0.1
	distance_factor = max(distance_factor, min_curve_factor)
	
	# Consider the angle for curve intensity
	var angle = abs(direction.angle())
	var angle_factor = 1.0
	if angle < PI/6 or angle > 5*PI/6:  # Very horizontal
		angle_factor = 0.7
	elif angle > PI/3 and angle < 2*PI/3:  # Very vertical  
		angle_factor = 1.3
	
	# Calculate control point with card-center-based direction and distance-based flattening
	var final_curve_height = curve_height * curve_direction_multiplier * angle_factor * distance_factor
	var control_point = mid_point + (perpendicular * final_curve_height)
	
	# Generate curve points using quadratic Bezier
	for i in range(ARROW_SEGMENTS + 1):
		var t = float(i) / float(ARROW_SEGMENTS)
		var point = quadratic_bezier(from, control_point, to, t)
		points.append(point)
	
	return points

func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	"""Calculate point on quadratic Bezier curve"""
	var u = 1.0 - t
	return u * u * p0 + 2 * u * t * p1 + t * t * p2
