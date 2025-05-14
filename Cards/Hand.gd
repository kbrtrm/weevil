# Hand.gd - Attach this script to your Hand scene
extends Node2D

# Constants for card arrangement
const BASE_CARD_SPACING = 90  # Base horizontal spacing between cards
const MIN_CARD_SPACING = 40   # Minimum spacing when cards need to be compressed
const MAX_CARD_SPACING = 90   # Maximum spacing when few cards
const CARD_ANGLE = 5          # Angle between cards (in degrees)
const HAND_CURVE_HEIGHT = 40  # How much the hand curves upward in the middle
const HAND_Y_POSITION = 292   # Y position of the hand (adjust based on your screen)
const MAX_CARDS_IN_HAND = 10  # Maximum number of cards in hand
const CARD_WIDTH = 90         # Width of a card
const SCREEN_MARGIN = 40      # Margin from screen edges

# References
const CardScene = preload("res://Cards/Card2.tscn")
var deck = []                 # Reference to your global deck
var cards_in_hand = []        # Array to track cards currently in hand
var card_being_dragged = null
var drag_offset = Vector2.ZERO

# Add a tracking variable for the currently hovered card
var hovered_card = null
var original_rotation = 0
var original_position = Vector2.ZERO
var original_z_index = 0

# Add reference to discard pile
@onready var discard_pile = find_child("DiscardPile")

@onready var DeckStatusReference = find_child("DeckStatus")
@onready var DeckCountLabel = DeckStatusReference.find_child("Count")

# UI References
var draw_button: Button

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize the deck from your global deck array
	deck = Global.deck.duplicate()
	
	# Shuffle the deck (optional)
	randomize()
	deck.shuffle()
	
	draw_card(7)

# Create a button for drawing cards
func create_draw_button():
	draw_button = Button.new()
	draw_button.text = "Draw Card"
	draw_button.position = Vector2(20, 20)  # Top-left position
	draw_button.size = Vector2(120, 40)     # Button size
	draw_button.pressed.connect(_on_draw_button_pressed)
	add_child(draw_button)

# Draw multiple cards with a small delay between them
func draw_card(count: int = 1):
	draw_multiple_cards(count)

# Helper function for drawing multiple cards with delay
func draw_multiple_cards(count: int, current: int = 0):
	if current >= count:
		return
		
	if deck.size() <= 0:
		print("No more cards in deck!")
		# Update button state
		if draw_button:
			draw_button.disabled = true
			draw_button.text = "Deck Empty"
		return
		
	if cards_in_hand.size() >= MAX_CARDS_IN_HAND:
		print("Hand is full!")
		# Update button state
		if draw_button:
			draw_button.disabled = true
			draw_button.text = "Hand Full"
		return
	
	# Get card data from the deck
	var card_data = deck.pop_front()
	
	# Create the card instance
	var card_instance = CardScene.instantiate()
	
	# Set card properties
	card_instance.card_name = card_data.name
	card_instance.card_cost = card_data.cost
	card_instance.card_desc = card_data.desc
	
	# Load art texture
	if "art" in card_data:
		card_instance.card_art = load(card_data.art)
	
	# Add the card to the scene from the deck position
	add_child(card_instance)
	card_instance.position = DeckStatusReference.position
	
	# Start with a small scale
	card_instance.scale = Vector2(0.1, 0.1)
	card_instance.rotation_degrees = -60.0
	
	# Add to hand array
	cards_in_hand.append(card_instance)
	
	# Update the UI
	update_ui()
	
	# Arrange all cards in hand with the new card
	arrange_cards(true)  # Pass true to indicate this is from a draw operation
	
	# Update button text with remaining cards
	if draw_button:
		draw_button.text = "Draw Card (" + str(deck.size()) + ")"
	
	# Continue drawing the next card after a small delay
	if current < count - 1:
		var timer = get_tree().create_timer(0.15)  # 0.15 second delay
		timer.timeout.connect(func(): draw_multiple_cards(count, current + 1))

# Update UI elements based on current state
func update_ui():
	DeckCountLabel.text = str(deck.size())
	if draw_button:
		# Enable/disable button based on deck and hand state
		draw_button.disabled = (deck.size() <= 0 or cards_in_hand.size() >= MAX_CARDS_IN_HAND)
		
		# Update button text
		if deck.size() <= 0:
			draw_button.text = "Deck Empty"
		elif cards_in_hand.size() >= MAX_CARDS_IN_HAND:
			draw_button.text = "Hand Full"
		else:
			draw_button.text = "Draw Card (" + str(deck.size()) + ")"

# Arrange cards in a curved formation at the bottom of the screen
func arrange_cards(is_drawing: bool = false):
	var num_cards = cards_in_hand.size()
	if num_cards <= 0:
		return
	
	# Get screen width
	var screen_width = get_viewport_rect().size.x
	var available_width = screen_width - (2 * SCREEN_MARGIN)
	
	# Calculate spacing based on number of cards
	var card_spacing = BASE_CARD_SPACING
	
	# If cards would extend beyond the screen, reduce the spacing
	if (num_cards - 1) * card_spacing > available_width:
		card_spacing = max(MIN_CARD_SPACING, available_width / (num_cards - 1 if num_cards > 1 else 1))
	elif num_cards <= 3: 
		# For small number of cards, use maximum spacing
		card_spacing = MAX_CARD_SPACING
	
	# Calculate overlap ratio for fan effect
	var overlap_ratio = 1.0
	if num_cards > 5:
		# Gradually increase overlap as cards increase
		overlap_ratio = 0.8 - (min(num_cards, 10) - 5) * 0.05
	
	# Calculate the total width with overlap factor
	var total_width = (num_cards - 1) * card_spacing * overlap_ratio
	
	# Calculate the starting X position to center the hand
	var start_x = screen_width / 2 - (total_width / 2)
	
	# Ensure start_x respects the screen margin
	start_x = max(SCREEN_MARGIN, start_x)
	
	# Calculate the effective end position
	var end_x = start_x + total_width
	
	# If the end position exceeds the right margin, adjust start_x
	if end_x > screen_width - SCREEN_MARGIN:
		start_x = max(SCREEN_MARGIN, screen_width - SCREEN_MARGIN - total_width)
	
	# Final validation to ensure a valid start_x
	start_x = max(SCREEN_MARGIN, start_x)
	
	# Position each card
	for i in range(num_cards):
		var card = cards_in_hand[i]
		
		# Calculate normalized position (0 to 1) from left to right
		var t = 0.0
		if num_cards > 1:
			t = float(i) / float(num_cards - 1)
		
		# Calculate horizontal position with overlap
		var x_pos = start_x + i * card_spacing * overlap_ratio
		
		# Calculate vertical position (curved arrangement)
		var y_pos = HAND_Y_POSITION - sin(t * PI) * HAND_CURVE_HEIGHT
		
		# Calculate rotation (cards fan out)
		var adjusted_angle = CARD_ANGLE
		if num_cards > 5:
			adjusted_angle = CARD_ANGLE * (5.0 / num_cards)
		
		var angle = -adjusted_angle * (num_cards - 1) / 2 + i * adjusted_angle
		
		# Calculate z-index (overlapping)
		card.z_index = i
		
		# Create tween for position and rotation
		var tween = get_tree().create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)  # Set ease in/out for smooth animation
		
		# Add a slight delay for the newest card if it was just added
		var delay = 0.0
		if i == num_cards - 1 and is_drawing:
			delay = 0.15
		
		tween.tween_property(card, "position", Vector2(x_pos, y_pos), 0.3).set_delay(delay)
		tween.parallel().tween_property(card, "rotation_degrees", angle, 0.3)
		
		# Only apply the scale tween if this is from a draw operation and it's the most recently added card
		if is_drawing and i == num_cards - 1:
			var scaletween = get_tree().create_tween()
			scaletween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.3)

# Process input for dragging cards
func _process(_delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = mouse_pos - drag_offset
		card_being_dragged.rotation_degrees = 0  # Keep card upright while dragging

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging a card
			var card = _get_card_under_mouse()
			if card:
				card_being_dragged = card
				# Save original position and rotation for returning if needed
				original_position = card.position
				original_rotation = card.rotation_degrees
				original_z_index = card.z_index
				# Bring the dragged card to the front
				card_being_dragged.z_index = 100
				# Calculate drag offset
				drag_offset = get_global_mouse_position() - card.position
		else:
			# Stop dragging
			if card_being_dragged:
				# Check if the card is dropped on a valid play area
				var drop_target = _check_drop_targets(get_global_mouse_position())
				
				if drop_target:
					# Card was dropped on a valid target
					play_card_on_target(card_being_dragged, drop_target)
				else:
					# No valid target, return the card to hand
					card_being_dragged.z_index = original_z_index
					var tween = get_tree().create_tween()
					tween.tween_property(card_being_dragged, "position", original_position, 0.2)
					tween.parallel().tween_property(card_being_dragged, "rotation_degrees", original_rotation, 0.2)
				
				card_being_dragged = null

# NEW FUNCTION: Check if mouse position is over any drop target
func _check_drop_targets(mouse_pos):
	# Get all nodes in the "drop_targets" group
	var drop_targets = get_tree().get_nodes_in_group("drop_targets")
	
	for target in drop_targets:
		# Check if target has a collision shape and the mouse is inside it
		if target is Area2D:
			# Simple point inside rect check (improved from original solution)
			# This assumes the Area2D has a CollisionShape2D child
			var collision = target.get_node_or_null("CollisionShape2D")
			if collision and collision.shape:
				var shape = collision.shape
				var rect = Rect2()
				
				if shape is RectangleShape2D:
					var extents = shape.extents
					var global_pos = target.global_position
					rect = Rect2(global_pos - extents, extents * 2)
				elif shape is CircleShape2D:
					var radius = shape.radius
					var global_pos = target.global_position
					# Create a square that encompasses the circle
					rect = Rect2(global_pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
				
				if rect.has_point(mouse_pos):
					return target
	
	return null

# NEW FUNCTION: Play a card on a drop target
func play_card_on_target(card, target):
	# First remove the card from the hand array
	if card in cards_in_hand:
		cards_in_hand.erase(card)
	else:
		print("Error: Card not found in hand")
		return
	
	# Emit the card_played signal from the target
	if target.has_signal("card_played"):
		target.emit_signal("card_played", card)
	elif target.has_method("play_card"):
		target.play_card(card)
	
	# Move the card to the discard pile
	move_to_discard_pile(card)
	
	# Rearrange the hand
	arrange_cards()
	
	# Update UI
	update_ui()

# NEW FUNCTION: Move a card to the discard pile
func move_to_discard_pile(card):
	if discard_pile:
		# Remove card from its current parent
		if card.get_parent():
			card.get_parent().remove_child(card)
		
		# Add to discard pile
		if discard_pile.has_method("add_card"):
			discard_pile.add_card(card)
		else:
			# Fallback if no add_card method
			discard_pile.add_child(card)
			card.position = Vector2.ZERO
			card.rotation_degrees = 0
	else:
		print("Warning: Discard pile not found, card will be removed")
		card.queue_free()

# Helper function to get the card under the mouse
func _get_card_under_mouse():
	var mouse_pos = get_global_mouse_position()
	
	# Check cards in reverse order (top to bottom) for better usability
	for i in range(cards_in_hand.size() - 1, -1, -1):
		var card = cards_in_hand[i]
		
		# Simple rectangular collision check
		# You might want to use Area2D for more accurate collision
		var card_size = Vector2(90, 124)  # Use your actual card size
		var card_rect = Rect2(card.position - card_size/2, card_size)
		
		if card_rect.has_point(mouse_pos):
			return card
			
	return null

# Add a card to hand (can be called from outside)
func add_card_to_hand(card_data):
	if cards_in_hand.size() >= MAX_CARDS_IN_HAND:
		print("Hand is full!")
		return
		
	# Create card instance from data
	var card_instance = CardScene.instantiate()
	
	# Set card properties
	card_instance.card_name = card_data.name
	card_instance.card_cost = card_data.cost
	card_instance.card_desc = card_data.desc
	
	# Load art texture
	if "art" in card_data:
		card_instance.card_art = load(card_data.art)
	
	# Add the card to the scene
	add_child(card_instance)
	cards_in_hand.append(card_instance)
	
	# Arrange all cards
	arrange_cards()
	
	# Update UI
	update_ui()

# Discard a card from hand
func discard_card(card):
	if card in cards_in_hand:
		cards_in_hand.erase(card)
		card.queue_free()
		arrange_cards()
		
		# Update UI
		update_ui()

# Draw a new card button callback
func _on_draw_button_pressed():
	draw_card(1)

# Create a shuffle button (optional)
func add_shuffle_button():
	var shuffle_button = Button.new()
	shuffle_button.text = "Shuffle Deck"
	shuffle_button.position = Vector2(150, 20)  # Position to the right of draw button
	shuffle_button.size = Vector2(120, 40)      # Button size
	shuffle_button.pressed.connect(_on_shuffle_button_pressed)
	add_child(shuffle_button)

# Shuffle button callback
func _on_shuffle_button_pressed():
	# Shuffle the deck
	randomize()
	deck.shuffle()
	print("Deck shuffled!")
