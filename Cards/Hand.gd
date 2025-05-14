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
var highlighted_card = null

# Add a tracking variable for the currently hovered card
var hovered_card = null
var original_rotation = 0
var original_position = Vector2.ZERO
var original_z_index = 0

var is_dragging = false  # Track dragging state
var just_dragged = false  # Track if we just finished dragging (to prevent immediate hover issues)
var highlight_clear_timer = null  # Timer to prevent highlight issues

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
	
	# Update z-indices BEFORE positioning
	update_card_z_indices()
	
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
	if is_dragging and card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = mouse_pos - drag_offset
		card_being_dragged.rotation_degrees = 0  # Keep card upright while dragging
		
		# Keep highlighted while dragging
		if card_being_dragged.has_method("set_highlight"):
			card_being_dragged.set_highlight(true)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Only start dragging if we're not already dragging
			if not is_dragging and not card_being_dragged:
				# Set dragging flag first to prevent multiple drag processing
				is_dragging = true
				
				# Clear all highlights first
				_clear_all_highlights()
				
				# Get the topmost card under the mouse
				var card = _get_topmost_card_at_position(get_global_mouse_position())
				
				if card:
					# Store the card being dragged
					card_being_dragged = card
					
					# Save original properties
					original_position = card.position
					original_rotation = card.rotation_degrees
					original_z_index = card.z_index
					
					# Bring to front while dragging
					card_being_dragged.z_index = cards_in_hand.size() + 100  # Much higher than normal
					
					# Calculate drag offset
					drag_offset = get_global_mouse_position() - card.position
					
					# Highlight only the dragged card
					if card.has_method("set_highlight"):
						card.set_highlight(true)
		else:  # Mouse released
			if is_dragging and card_being_dragged:
				# Check if dropped on a valid target
				var drop_target = _check_drop_targets(get_global_mouse_position())
				
				if drop_target:
					# Play the card on the target
					play_card_on_target(card_being_dragged, drop_target)
				else:
					# Return to hand
					var tween = get_tree().create_tween()
					tween.tween_property(card_being_dragged, "position", original_position, 0.2)
					tween.parallel().tween_property(card_being_dragged, "rotation_degrees", original_rotation, 0.2)
					
					# Reset z-index
					card_being_dragged.z_index = original_z_index
				
				# Set flag to prevent immediate hover issues
				just_dragged = true
				
				# Start a short timer to allow proper hover detection after drag
				if highlight_clear_timer:
					highlight_clear_timer.queue_free()
				highlight_clear_timer = get_tree().create_timer(0.1)
				highlight_clear_timer.timeout.connect(_after_drag_timer_timeout)
				
				# Clear dragging state
				card_being_dragged = null
				is_dragging = false
				
				# Update card positions and z-indices
				arrange_cards()

# Add this function to handle post-drag timer timeout
func _after_drag_timer_timeout():
	just_dragged = false
	
	# Clear all highlights
	_clear_all_highlights()
	
	# Check what's under the mouse now
	var current_card = _get_topmost_card_at_position(get_global_mouse_position())
	if current_card and current_card.has_method("set_highlight"):
		current_card.set_highlight(true)
		hovered_card = current_card

# Add this function to clear all card highlights
func _clear_all_highlights():
	for card in cards_in_hand:
		if card.has_method("set_highlight"):
			card.set_highlight(false)
	
	# Reset hovered card reference
	hovered_card = null

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
	arrange_cards()  # This now calls update_card_z_indices()
	
	# Update UI
	update_ui()
	
	# Check if mouse is over a card now and highlight it
	var current_card = _get_topmost_card_at_position(get_global_mouse_position())
	if current_card and current_card.has_method("set_highlight"):
		current_card.set_highlight(true)
		hovered_card = current_card

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
	return _get_topmost_card_at_position(get_global_mouse_position())

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
	
# Called when a card wants to be highlighted
func highlight_card(card):
	# First, unhighlight any currently highlighted card
	if highlighted_card and highlighted_card != card:
		# Call the unhighlight method on the previous card
		if highlighted_card.has_method("set_highlight"):
			highlighted_card.set_highlight(false)
	
	# Set the new highlighted card
	highlighted_card = card
	
	# Make sure no other cards are highlighted
	for c in cards_in_hand:
		if c != card and c.has_method("set_highlight"):
			c.set_highlight(false)
			
# Called when a card is hovered
func on_card_hovered(card):
	# Skip hover handling during dragging or right after dragging
	if is_dragging or just_dragged:
		return
	
	# Find the topmost card at the current mouse position
	var topmost_card = _get_topmost_card_at_position(get_global_mouse_position())
	
	# Only process if this is actually the topmost card
	if topmost_card == card:
		# Clear all other highlights first
		_clear_all_highlights()
		
		# Highlight this card
		if card.has_method("set_highlight"):
			card.set_highlight(true)
			
		# Save as currently hovered card
		hovered_card = card
	else:
		# This is not the topmost card, so it shouldn't be highlighted
		# This handles cases of overlapping cards triggering hover events
		if card.has_method("set_highlight"):
			card.set_highlight(false)

# Called when card hover ends
func on_card_unhovered(card):
	# Skip hover handling during dragging
	if is_dragging or just_dragged:
		return
	
	# Let's delay the unhover slightly to prevent flickering
	await get_tree().create_timer(0.05).timeout
	
	# Check what's currently under the mouse
	var current_topmost = _get_topmost_card_at_position(get_global_mouse_position())
	
	# If the mouse moved to a different card, highlight that one instead
	if current_topmost and current_topmost != card:
		# Clear all other highlights first
		_clear_all_highlights()
		
		# Highlight the new card
		if current_topmost.has_method("set_highlight"):
			current_topmost.set_highlight(true)
			
		# Update the hovered card reference
		hovered_card = current_topmost
	else:
		# Only unhighlight if this was the previously hovered card
		if hovered_card == card:
			# No other card under mouse, clear the highlight
			if card.has_method("set_highlight"):
				card.set_highlight(false)
			
			# Clear hovered card reference
			hovered_card = null

# Get the topmost card (highest z-index) at a given position
func _get_topmost_card_at_position(position):
	var highest_z_index = -1
	var topmost_card = null
	
	for card in cards_in_hand:
		var card_size = Vector2(90, 124)  # Use your actual card size
		var card_rect = Rect2(card.position - card_size/2, card_size)
		
		if card_rect.has_point(position) and card.z_index > highest_z_index:
			highest_z_index = card.z_index
			topmost_card = card
	
	return topmost_card
	
# Ensure z-indices are properly set for all cards
func update_card_z_indices():
	# Sort cards by their position in the cards_in_hand array
	# Later cards (higher index) should be displayed on top
	for i in range(cards_in_hand.size()):
		var card = cards_in_hand[i]
		card.z_index = i
	
	# If there's a card being dragged, ensure it's always on top
	if card_being_dragged and card_being_dragged in cards_in_hand:
		card_being_dragged.z_index = cards_in_hand.size() + 10
