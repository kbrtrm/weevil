# CardTargetingSystem.gd
extends Node2D
class_name CardTargetingSystem

signal target_selected(target_node, target_type)
signal targeting_cancelled()

# Arrow visual properties
const ARROW_SEGMENTS = 20
const ARROW_CURVE_HEIGHT = 80
const ARROW_WIDTH = 4
const ARROW_HEAD_SIZE = 12

# Targeting state
var is_targeting_active: bool = false
var current_card: Node2D = null
var target_arrow: Line2D = null
var arrow_head: Polygon2D = null
var valid_targets: Array = []
var highlighted_target: Node2D = null

# Drop zones
var enemy_drop_zones: Array = []
var skill_drop_zone: Area2D = null

@onready var targeting_ui: CanvasLayer = null

func _ready():
	# Create targeting UI layer
	targeting_ui = CanvasLayer.new()
	targeting_ui.name = "TargetingUI"
	targeting_ui.layer = 100  # Above most UI
	add_child(targeting_ui)
	
	# Set up input handling
	set_process_input(false)  # Only enable when targeting

func _input(event: InputEvent):
	if not is_targeting_active:
		return
		
	if event is InputEventMouseMotion:
		update_targeting_arrow(event.global_position)
		update_target_highlighting(event.global_position)
	
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			# Left mouse released - try to select target
			var target = get_target_at_position(event.global_position)
			if target:
				emit_signal("target_selected", target.target_node, target.target_type)
			else:
				emit_signal("targeting_cancelled")
			stop_targeting()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Right click cancels targeting
			emit_signal("targeting_cancelled")
			stop_targeting()

func start_targeting(card: Node2D):
	"""Start targeting mode for the given card"""
	if is_targeting_active:
		stop_targeting()
	
	current_card = card
	is_targeting_active = true
	set_process_input(true)
	
	# Determine valid targets based on card type
	setup_valid_targets(card)
	
	# Create targeting arrow
	create_targeting_arrow()
	
	# Show drop zones
	show_drop_zones()
	
	print("CardTargeting: Started targeting for card: ", card.card_name)

func stop_targeting():
	"""Stop targeting mode and clean up"""
	is_targeting_active = false
	set_process_input(false)
	current_card = null
	highlighted_target = null
	
	# Clean up visual elements
	clear_targeting_arrow()
	hide_drop_zones()
	clear_target_highlighting()
	
	print("CardTargeting: Stopped targeting")

func setup_valid_targets(card: Node2D):
	"""Determine what targets are valid for this card"""
	valid_targets.clear()
	
	# Get card data to determine targeting
	var card_data = CardDatabase.get_card_by_name(card.card_name)
	
	if not card_data or not "effects" in card_data:
		# Default behavior for cards without database entries
		if card.card_type == "attack":
			setup_enemy_targeting()
		else:
			setup_skill_targeting()
		return
	
	# Check effects to determine targeting requirements
	var needs_enemy_target = false
	var needs_skill_area = false
	
	for effect in card_data.effects:
		var target_type = effect.get("target", "")
		var effect_type = effect.get("type", "")
		
		# Effects that target enemies
		if target_type == "enemy" or effect_type in ["damage", "weak", "vulnerable", "bleed"]:
			needs_enemy_target = true
		
		# Effects that can be played in skill area
		if target_type == "player" or effect_type in ["block", "heal", "draw"]:
			needs_skill_area = true
	
	# Set up targeting based on what the card needs
	if needs_enemy_target:
		setup_enemy_targeting()
	elif needs_skill_area:
		setup_skill_targeting()
	else:
		# Default to skill area for unknown cards
		setup_skill_targeting()

func setup_enemy_targeting():
	"""Set up targeting for enemy-targeting cards (attacks, debuffs)"""
	# Find all enemies in the battle scene
	var battle_manager = find_battle_manager()
	if not battle_manager:
		return
	
	var enemy = battle_manager.get_node_or_null("Enemy")
	if enemy:
		create_enemy_drop_zone(enemy)

func setup_skill_targeting():
	"""Set up targeting for skill cards (non-targeted abilities)"""
	# Create a large drop zone in the upper half of the screen
	create_skill_drop_zone()

func create_enemy_drop_zone(enemy: Node2D):
	"""Create a drop zone around an enemy"""
	var drop_zone = Area2D.new()
	drop_zone.name = "EnemyDropZone"
	drop_zone.add_to_group("drop_targets")
	
	# Add collision shape
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(120, 120)  # Generous targeting area
	collision.shape = shape
	drop_zone.add_child(collision)
	
	# Add visual indicator (initially hidden)
	var indicator = ColorRect.new()
	indicator.name = "VisualIndicator"
	indicator.size = Vector2(120, 120)
	indicator.color = Color(1.0, 0.3, 0.3, 0.3)  # Red with transparency
	indicator.position = -indicator.size / 2
	indicator.visible = false
	drop_zone.add_child(indicator)
	
	# Set metadata
	drop_zone.set_meta("target_node", enemy)
	drop_zone.set_meta("target_type", "enemy")
	
	# Position at enemy location
	drop_zone.global_position = enemy.global_position
	
	# Add to targeting UI
	targeting_ui.add_child(drop_zone)
	enemy_drop_zones.append(drop_zone)

func create_skill_drop_zone():
	"""Create a drop zone for skill cards (upper half of screen)"""
	if skill_drop_zone:
		return  # Already created
	
	var drop_zone = Area2D.new()
	drop_zone.name = "SkillDropZone"
	drop_zone.add_to_group("drop_targets")
	
	# Add collision shape covering upper half of screen
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var screen_size = get_viewport().get_visible_rect().size
	shape.size = Vector2(screen_size.x, screen_size.y * 0.6)  # Upper 60% of screen
	collision.shape = shape
	drop_zone.add_child(collision)
	
	# Add visual indicator (initially hidden)
	var indicator = ColorRect.new()
	indicator.name = "VisualIndicator"
	indicator.size = shape.size
	indicator.color = Color(0.3, 0.8, 0.3, 0.2)  # Green with transparency
	indicator.position = -indicator.size / 2
	indicator.visible = false
	drop_zone.add_child(indicator)
	
	# Set metadata
	var battle_manager = find_battle_manager()
	var player = battle_manager.get_node_or_null("Player") if battle_manager else null
	drop_zone.set_meta("target_node", player)
	drop_zone.set_meta("target_type", "skill_area")
	
	# Position in center of upper area
	drop_zone.global_position = Vector2(screen_size.x / 2, screen_size.y * 0.3)
	
	# Add to targeting UI
	targeting_ui.add_child(drop_zone)
	skill_drop_zone = drop_zone

func create_targeting_arrow():
	"""Create the curved arrow visual"""
	if target_arrow:
		return
	
	# Create arrow line
	target_arrow = Line2D.new()
	target_arrow.name = "TargetingArrow"
	target_arrow.width = ARROW_WIDTH
	target_arrow.default_color = Color(1.0, 1.0, 0.0, 0.8)  # Yellow with transparency
	target_arrow.z_index = 999
	target_arrow.antialiased = true
	targeting_ui.add_child(target_arrow)
	
	# Create arrow head
	arrow_head = Polygon2D.new()
	arrow_head.name = "ArrowHead"
	arrow_head.color = Color(1.0, 1.0, 0.0, 0.8)
	arrow_head.z_index = 1000
	# Arrow head points (triangle pointing right)
	var arrow_points = PackedVector2Array()
	arrow_points.append(Vector2(ARROW_HEAD_SIZE, 0))
	arrow_points.append(Vector2(-ARROW_HEAD_SIZE/2, -ARROW_HEAD_SIZE/2))
	arrow_points.append(Vector2(-ARROW_HEAD_SIZE/2, ARROW_HEAD_SIZE/2))
	arrow_head.polygon = arrow_points
	targeting_ui.add_child(arrow_head)

func update_targeting_arrow(mouse_pos: Vector2):
	"""Update the curved arrow to point at mouse position"""
	if not target_arrow or not current_card:
		return
	
	var start_pos = current_card.global_position
	var end_pos = mouse_pos
	
	# Calculate curve points
	var curve_points = calculate_curved_arrow_points(start_pos, end_pos)
	target_arrow.clear_points()
	
	for point in curve_points:
		target_arrow.add_point(point)
	
	# Update arrow head position and rotation
	if curve_points.size() >= 2:
		var last_point = curve_points[-1]
		var second_last_point = curve_points[-2]
		var direction = (last_point - second_last_point).normalized()
		
		arrow_head.global_position = last_point
		arrow_head.rotation = direction.angle()

func calculate_curved_arrow_points(start_pos: Vector2, end_pos: Vector2) -> PackedVector2Array:
	"""Calculate points for a curved arrow from start to end"""
	var points = PackedVector2Array()
	
	var distance = start_pos.distance_to(end_pos)
	if distance < 10:
		return points
	
	# Calculate control point for the curve
	var mid_point = (start_pos + end_pos) / 2
	var perpendicular = Vector2(-(end_pos.y - start_pos.y), end_pos.x - start_pos.x).normalized()
	var curve_height = min(ARROW_CURVE_HEIGHT, distance * 0.3)
	var control_point = mid_point + perpendicular * curve_height
	
	# Generate curved line points using quadratic Bezier curve
	for i in range(ARROW_SEGMENTS + 1):
		var t = float(i) / float(ARROW_SEGMENTS)
		var point = quadratic_bezier(start_pos, control_point, end_pos, t)
		points.append(point)
	
	return points

func quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	"""Calculate point on quadratic Bezier curve"""
	var u = 1.0 - t
	return u * u * p0 + 2 * u * t * p1 + t * t * p2

func update_target_highlighting(mouse_pos: Vector2):
	"""Update which target is highlighted based on mouse position"""
	var target = get_target_at_position(mouse_pos)
	
	# Clear previous highlighting
	clear_target_highlighting()
	
	if target:
		# Highlight the target
		highlighted_target = target.drop_zone
		var indicator = highlighted_target.get_node_or_null("VisualIndicator")
		if indicator:
			indicator.visible = true
			# Pulse effect
			var tween = create_tween()
			tween.set_loops()
			tween.tween_property(indicator, "modulate:a", 0.5, 0.5)
			tween.tween_property(indicator, "modulate:a", 0.3, 0.5)

func clear_target_highlighting():
	"""Clear all target highlighting"""
	if highlighted_target:
		var indicator = highlighted_target.get_node_or_null("VisualIndicator")
		if indicator:
			indicator.visible = false
			# Stop any tweens on the indicator
			var tween = indicator.get_tree().create_tween()
			tween.kill()
		highlighted_target = null

func get_target_at_position(position: Vector2):
	"""Get the target information at the given position"""
	# Check enemy drop zones first (higher priority)
	for drop_zone in enemy_drop_zones:
		if not is_instance_valid(drop_zone):
			continue
		
		if is_position_in_drop_zone(position, drop_zone):
			return {
				"target_node": drop_zone.get_meta("target_node"),
				"target_type": drop_zone.get_meta("target_type"),
				"drop_zone": drop_zone
			}
	
	# Check skill drop zone
	if skill_drop_zone and is_position_in_drop_zone(position, skill_drop_zone):
		return {
			"target_node": skill_drop_zone.get_meta("target_node"),
			"target_type": skill_drop_zone.get_meta("target_type"),
			"drop_zone": skill_drop_zone
		}
	
	return null

func is_position_in_drop_zone(position: Vector2, drop_zone: Area2D) -> bool:
	"""Check if position is inside the drop zone"""
	var collision = drop_zone.get_node_or_null("CollisionShape2D")
	if not collision or not collision.shape:
		return false
	
	var local_pos = drop_zone.to_local(position)
	
	if collision.shape is RectangleShape2D:
		var rect_shape = collision.shape as RectangleShape2D
		var rect = Rect2(-rect_shape.size/2, rect_shape.size)
		return rect.has_point(local_pos)
	
	return false

func show_drop_zones():
	"""Show visual indicators for valid drop zones"""
	# Enemy drop zones stay hidden until mouse hovers
	# Skill drop zone shows a subtle hint
	if skill_drop_zone:
		var indicator = skill_drop_zone.get_node_or_null("VisualIndicator")
		if indicator:
			indicator.visible = true
			indicator.modulate.a = 0.1  # Very subtle

func hide_drop_zones():
	"""Hide all drop zone visual indicators"""
	for drop_zone in enemy_drop_zones:
		if is_instance_valid(drop_zone):
			var indicator = drop_zone.get_node_or_null("VisualIndicator")
			if indicator:
				indicator.visible = false
	
	if skill_drop_zone:
		var indicator = skill_drop_zone.get_node_or_null("VisualIndicator")
		if indicator:
			indicator.visible = false

func clear_targeting_arrow():
	"""Remove the targeting arrow"""
	if target_arrow:
		target_arrow.queue_free()
		target_arrow = null
	
	if arrow_head:
		arrow_head.queue_free()
		arrow_head = null

func cleanup():
	"""Clean up all targeting elements"""
	clear_targeting_arrow()
	
	# Clean up drop zones
	for drop_zone in enemy_drop_zones:
		if is_instance_valid(drop_zone):
			drop_zone.queue_free()
	enemy_drop_zones.clear()
	
	if skill_drop_zone:
		skill_drop_zone.queue_free()
		skill_drop_zone = null

func find_battle_manager():
	"""Find the battle manager node"""
	var node = get_parent()
	while node and not node.has_method("get_player"):
		node = node.get_parent()
	return node
