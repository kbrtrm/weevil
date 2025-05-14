# Hand.gd - Simplified version
extends Node2D

# Constants
const BASE_CARD_SPACING = 90
const MIN_CARD_SPACING = 40
const MAX_CARD_SPACING = 90
const CARD_ANGLE = 5
const HAND_CURVE_HEIGHT = 40
const HAND_Y_POSITION = 292
const MAX_CARDS_IN_HAND = 10
const CARD_WIDTH = 90
const SCREEN_MARGIN = 120

# Card references
const CardScene = preload("res://Cards/Card2.tscn")
var deck = []
var cards_in_hand = []

# Drag and hover tracking
var card_being_dragged = null
var drag_offset = Vector2.ZERO
var hovered_card = null

# References to other nodes
@onready var discard_pile = find_child("DiscardPile")
@onready var deck_status = find_child("DeckStatus")
@onready var deck_count_label = deck_status.find_child("Count")

# Called when the node enters the scene tree
func _ready() -> void:
	# Initialize and shuffle deck
	deck = Global.deck.duplicate()
	randomize()
	deck.shuffle()
	
	# Initial draw
	draw_card(5)

# Draw specified number of cards
func draw_card(count: int = 1):
	for i in range(count):
		if deck.size() <= 0 or cards_in_hand.size() >= MAX_CARDS_IN_HAND:
			break
			
		# Get card data and create instance
		var card_data = deck.pop_front()
		var card = CardScene.instantiate()
		
		# Set properties
		card.card_name = card_data.name
		card.card_cost = card_data.cost
		card.card_desc = card_data.desc
		
		if "art" in card_data:
			card.card_art = load(card_data.art)
		
		# Add to scene with initial properties
		add_child(card)
		card.position = deck_status.position
		#card.scale = Vector2(0.1, 0.1)  # Start small
		card.rotation_degrees = -60.0
		
		# Add to hand array
		cards_in_hand.append(card)
		
		# If drawing multiple cards, add a small delay between each
		#if i < count - 1:
			#await get_tree().create_timer(0.15).timeout
	
	# Update UI and arrange cards only once
	update_ui()
	arrange_cards(true)

# Update UI elements
func update_ui():
	deck_count_label.text = str(deck.size())

# Process input for dragging cards
func _process(delta: float) -> void:
	if card_being_dragged:
		card_being_dragged.position = get_global_mouse_position() - drag_offset
		card_being_dragged.rotation_degrees = 0

# Input handling
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging
			if not card_being_dragged:
				var card = get_top_card_at_position(get_global_mouse_position())
				if card:
					start_drag(card)
		else:
			# End dragging
			if card_being_dragged:
				end_drag()

# Start dragging a card
func start_drag(card):
	card_being_dragged = card
	
	# Store original state
	card.set_meta("original_position", card.position)
	card.set_meta("original_rotation", card.rotation_degrees)
	card.set_meta("original_z_index", card.z_index)
	
	# Setup dragging
	drag_offset = get_global_mouse_position() - card.position
	card.z_index = 1000
	
	# Update highlights
	update_all_highlights()

# End dragging a card
func end_drag():
	var drop_target = get_drop_target_at_position(get_global_mouse_position())
	
	if drop_target:
		# Play card on target
		play_card(card_being_dragged, drop_target)
	else:
		# Return to hand
		var tween = get_tree().create_tween()
		tween.tween_property(card_being_dragged, "position", card_being_dragged.get_meta("original_position"), 0.3)
		tween.tween_property(card_being_dragged, "rotation_degrees", card_being_dragged.get_meta("original_rotation"), 0.3)
		
		# Reset z-index after animation
		tween.tween_callback(func():
			if is_instance_valid(card_being_dragged):
				card_being_dragged.z_index = card_being_dragged.get_meta("original_z_index")
		)
	
	card_being_dragged = null
	arrange_cards()
	update_all_highlights()

# Arrange cards in hand
func arrange_cards(is_drawing: bool = false):
	# Remove invalid cards
	for i in range(cards_in_hand.size() - 1, -1, -1):
		if not is_instance_valid(cards_in_hand[i]):
			cards_in_hand.remove_at(i)
	
	var num_cards = cards_in_hand.size()
	if num_cards <= 0:
		return
	
	# Calculate card positions
	var screen_width = get_viewport_rect().size.x
	var card_spacing = calculate_card_spacing(num_cards, screen_width)
	var start_x = calculate_start_position(num_cards, card_spacing, screen_width)
	
	# Position each card
	for i in range(num_cards):
		var card = cards_in_hand[i]
		if card == card_being_dragged:
			continue
			
		# Calculate position
		var t = 0.0 if num_cards <= 1 else float(i) / float(num_cards - 1)
		var x_pos = start_x + i * card_spacing
		var y_pos = HAND_Y_POSITION - sin(t * PI) * HAND_CURVE_HEIGHT
		
		# Calculate rotation
		var angle = -CARD_ANGLE * (num_cards - 1) / 2 + i * CARD_ANGLE
		
		# Set z-index
		card.z_index = i
		
		# Position and rotation animation
		var tween = get_tree().create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(card, "position", Vector2(x_pos, y_pos), 0.3)
		tween.parallel().tween_property(card, "rotation_degrees", angle, 0.3)
		
		# Handle scaling separately for newly drawn cards
		if is_drawing and card.scale.x < 0.9:  # Only scale up if not already scaled
			var scale_tween = get_tree().create_tween()
			scale_tween.set_ease(Tween.EASE_OUT)
			scale_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.3)

# Calculate appropriate card spacing based on number of cards
func calculate_card_spacing(num_cards, screen_width):
	var available_width = screen_width - (2 * SCREEN_MARGIN)
	var spacing = BASE_CARD_SPACING
	
	if num_cards <= 3:
		spacing = MAX_CARD_SPACING
	elif (num_cards - 1) * spacing > available_width:
		spacing = max(MIN_CARD_SPACING, available_width / (num_cards - 1))
		
	return spacing

# Calculate starting X position for cards
func calculate_start_position(num_cards, card_spacing, screen_width):
	var total_width = (num_cards - 1) * card_spacing
	var start_x = screen_width / 2 - (total_width / 2)
	start_x = max(SCREEN_MARGIN, min(start_x, screen_width - SCREEN_MARGIN - total_width))
	return start_x

# Get the top card at a position
func get_top_card_at_position(position):
	var candidates = []
	
	# First, collect all cards under the position
	for card in cards_in_hand:
		if not is_instance_valid(card):
			continue
			
		var card_rect = Rect2(card.position - Vector2(CARD_WIDTH, 124)/2, Vector2(CARD_WIDTH, 124))
		
		if card_rect.has_point(position):
			candidates.append(card)
	
	# If no cards found, return null
	if candidates.size() == 0:
		return null
		
	# Sort candidates by z-index (highest first)
	candidates.sort_custom(func(a, b): return a.z_index > b.z_index)
	
	# Return the topmost card (first after sorting)
	return candidates[0]

# Get a drop target at position
func get_drop_target_at_position(position):
	var targets = get_tree().get_nodes_in_group("drop_targets")
	
	for target in targets:
		if target is Area2D and target.has_node("CollisionShape2D"):
			var collision = target.get_node("CollisionShape2D")
			var shape = collision.shape
			
			if shape is RectangleShape2D:
				var rect = Rect2(target.global_position - shape.extents, shape.extents * 2)
				if rect.has_point(position):
					return target
	
	return null

# Play a card on a target
func play_card(card, target):
	# Remove from hand
	cards_in_hand.erase(card)
	
	# Emit signal on target
	if target.has_signal("card_played"):
		target.emit_signal("card_played", card)
	elif target.has_method("play_card"):
		target.play_card(card)
	
	# Move to discard
	if card.get_parent():
		card.get_parent().remove_child(card)
		
	if discard_pile:
		if discard_pile.has_method("add_card"):
			discard_pile.add_card(card)
		else:
			discard_pile.add_child(card)
			card.position = Vector2.ZERO
			card.rotation_degrees = 0
	else:
		card.queue_free()
	
	# Update hand
	arrange_cards()
	update_ui()

# Handle card hover
func on_card_hovered(card):
	if card_being_dragged:
		return
		
	hovered_card = get_top_card_at_position(get_global_mouse_position())
	update_all_highlights()

# Handle card unhover
func on_card_unhovered(card):
	if card_being_dragged:
		return
		
	# Short delay to prevent flickering
	await get_tree().create_timer(0.05).timeout
	
	hovered_card = get_top_card_at_position(get_global_mouse_position())
	update_all_highlights()

# Update highlights for all cards
func update_all_highlights():
	# Clear all highlights first
	for card in cards_in_hand:
		if is_instance_valid(card) and card.has_method("set_highlight"):
			card.set_highlight(false)
	
	# Set highlight for dragged or hovered card
	if card_being_dragged and card_being_dragged.has_method("set_highlight"):
		card_being_dragged.set_highlight(true)
	elif hovered_card and hovered_card.has_method("set_highlight"):
		hovered_card.set_highlight(true)
