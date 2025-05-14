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
	#draw_card(5)

# Draw specified number of cards
func draw_card(count: int = 1):
	for i in range(count):
		# Check if deck is empty and reshuffle discard pile if needed
		if deck.size() <= 0:
			reshuffle_discard_pile()
			
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

# Move a card to the discard pile with animation
func move_card_to_discard(card):
	# Remove from hand if it's still there
	if card in cards_in_hand:
		cards_in_hand.erase(card)
	
	# Don't remove the card from the parent yet - we want to animate it first
	
	# Start animation to discard pile
	if discard_pile:
		# Calculate the global position of the discard pile
		var target_position = discard_pile.global_position
		
		# Create a tween for the animation
		var tween = get_tree().create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		
		# Animate the card to the discard pile position
		tween.tween_property(card, "global_position", target_position, 0.5)
		tween.parallel().tween_property(card, "scale", Vector2(0,0), 0.5)
		
		# Animate rotation to flat (or slightly random for visual effect)
		var target_rotation = randf_range(-10, 10)
		tween.parallel().tween_property(card, "rotation_degrees", target_rotation, 0.5)
		
		# Ensure card is at a good z-index during the animation
		card.z_index = 1000
		
		# After animation completes, add to discard pile
		tween.tween_callback(func():
			# Remove card from current parent
			if card.get_parent():
				card.get_parent().remove_child(card)
				
			# Add to discard pile
			if discard_pile.has_method("add_card"):
				discard_pile.add_card(card)
			else:
				# Fallback if no add_card method
				discard_pile.add_child(card)
				card.position = Vector2.ZERO
		)
	else:
		# If no discard pile found, just free the card
		print("Warning: Discard pile not found, card will be removed")
		card.queue_free()
	
	# Update hand (cards are already removed from the hand array)
	arrange_cards()
	update_ui()

# Remove a card from the hand without playing it
# This is called by CardManager after the card_played signal
func remove_card_from_hand(card):
	if card in cards_in_hand:
		print("Removing card from hand: ", card.card_name)
		cards_in_hand.erase(card)
		arrange_cards()
		update_ui()

# Input handling for card dragging
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Start dragging a card
			if not cards_in_hand.any(func(c): return c.being_dragged):
				var card = get_top_card_at_position(get_global_mouse_position())
				if card and card.draggable:
					card.start_drag()
		else:
			# Find the card being dragged and end its drag
			for card in cards_in_hand:
				if card.being_dragged:
					card.end_drag()
					break

# Handle card drag started
func on_card_drag_started(card):
	# Clear highlights on other cards
	for c in cards_in_hand:
		if c != card and c.has_method("set_highlight"):
			c.set_highlight(false)

# Handle card drag ended
func on_card_drag_ended(card, drop_position):
	# Check if dropped on a valid target
	var drop_target = get_drop_target_at_position(drop_position)
	
	if drop_target:
		# Valid drop - emit signal on the drop target
		# This will be handled by CardManager's _on_card_played
		if drop_target.has_signal("card_played"):
			drop_target.emit_signal("card_played", card)
		else:
			# Fallback if no signal - return card to hand without shaking
			return_card_to_hand(card, false)
	else:
		# Invalid drop - return to hand without shaking
		return_card_to_hand(card, false)

# Helper function to return a card to its original position in hand
# Added a parameter to control whether the card should shake
func return_card_to_hand(card, should_shake: bool = false):
	# Make sure card is still in the cards_in_hand array
	if not card in cards_in_hand:
		cards_in_hand.append(card)
	
	# Calculate what the rotation should be based on the card's position in the hand
	var card_index = cards_in_hand.find(card)
	var num_cards = cards_in_hand.size()
	var proper_rotation = 0.0
	
	if num_cards > 1:
		# Calculate the proper rotation based on the card's position in the hand
		var t = float(card_index) / float(num_cards - 1)
		proper_rotation = -CARD_ANGLE * (num_cards - 1) / 2 + card_index * CARD_ANGLE
	
	# Create tween to animate back to original position
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# This is called when card couldn't be played, so get the original position
	if "original_position" in card and card.original_position != Vector2.ZERO:
		var target_pos = card.original_position
		
		# Animate card back to position with proper rotation
		tween.tween_property(card, "position", target_pos, 0.3)
		tween.parallel().tween_property(card, "rotation_degrees", proper_rotation, 0.3)
		
		# Save the proper rotation so the card remembers it
		card.original_rotation = proper_rotation
		
		# Only shake if specifically requested (e.g., for insufficient energy)
		if should_shake:
			tween.tween_callback(func(): shake_card(card))
	else:
		# Fallback: just arrange all cards
		arrange_cards()
	
	# Update highlights
	update_all_highlights()

# Add a shake card effect for feedback
func shake_card(card):
	var original_pos = card.position
	var original_rot = card.rotation_degrees
	
	var tween = create_tween()
	# Shake horizontally
	tween.tween_property(card, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(card, "position", original_pos - Vector2(5, 0), 0.05)
	tween.tween_property(card, "position", original_pos, 0.05)
	
	# Ensure rotation is maintained after shaking
	tween.tween_property(card, "rotation_degrees", original_rot, 0.05)
	
	# Flash the cost label red
	if "cost_label" in card and card.cost_label:
		var original_color = card.cost_label.modulate
		tween.parallel().tween_property(card.cost_label, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.1)
		tween.tween_property(card.cost_label, "modulate", original_color, 0.1)

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
				# Make sure we're using Vector2 for all calculations
				var global_pos = Vector2(target.global_position)
				var extents = Vector2(shape.extents)
				
				var rect = Rect2(global_pos - extents, extents * 2)
				
				if rect.has_point(position):
					return target
	
	return null

## Play a card on a target
#func play_card(card, target):
	## Remove from hand
	#cards_in_hand.erase(card)
	#
	## Emit signal on target
	#if target.has_signal("card_played"):
		#target.emit_signal("card_played", card)
		#
	## Update hand
	#arrange_cards()
	#update_ui()

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



func _on_deck_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var viewer = preload("res://Cards/DeckViewer.tscn").instantiate()
			add_child(viewer)
			
			# Position at center of screen
			var screen_size = get_viewport_rect().size
			viewer.position = Vector2(screen_size.x / 2, screen_size.y / 2)
			viewer.z_index = 2000
			
			# Display the deck
			viewer.display_deck(deck, "Remaining Cards: " + str(deck.size()))
			
			## Connect to signals
			#viewer.card_clicked.connect(_on_deck_card_clicked)
			#viewer.viewer_closed.connect(_on_deck_viewer_closed)
			
func discard_card_to_pile(card):
	# Remove from hand if it's still there
	if card in cards_in_hand:
		cards_in_hand.erase(card)
	
	# Create tween for animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Animate the card to the discard pile
	var target_position = discard_pile.global_position
	tween.tween_property(card, "global_position", target_position, 0.3)
	tween.parallel().tween_property(card, "scale", Vector2(0.1, 0.1), 0.3)
	tween.parallel().tween_property(card, "rotation_degrees", randf_range(-10, 10), 0.3)
	
	# After animation completes, add to discard pile
	tween.tween_callback(func():
		if card.get_parent():
			card.get_parent().remove_child(card)
			
		if discard_pile:
			if discard_pile.has_method("add_card"):
				discard_pile.add_card(card)
			else:
				discard_pile.add_child(card)
				card.position = Vector2.ZERO
	)
	
	# Update UI
	update_ui()
	
# New function to reshuffle discard pile into deck
func reshuffle_discard_pile():
	# First, check if we have a discard pile reference
	if not discard_pile or discard_pile.discarded_cards.size() <= 0:
		print("No cards in discard pile to reshuffle!")
		return
		
	print("Reshuffling discard pile into deck...")
	
	# Create a temporary array to hold card data
	var cards_to_add = []
	
	# Get all card data from discarded cards
	for discarded_card in discard_pile.discarded_cards:
		# Extract the data we need to recreate this card
		var card_data = {
			"name": discarded_card.card_name,
			"cost": discarded_card.card_cost,
			"desc": discarded_card.card_desc
		}
		
		# Add art reference if available
		if discarded_card.card_art:
			card_data["art"] = discarded_card.card_art.resource_path
			
		# Add to our array of cards to shuffle back in
		cards_to_add.append(card_data)
		
		# Remove the card node
		discarded_card.queue_free()
	
	# Clear the discard pile
	discard_pile.discarded_cards.clear()
	
	# Update discard pile UI
	var label = discard_pile.find_child("Label")
	if label:
		label.text = "0"
		
	# Play a reshuffling animation/effect if desired
	play_reshuffle_effect()
	
	# Add the cards to the deck and shuffle
	deck.append_array(cards_to_add)
	randomize()
	deck.shuffle()
	
	# Update deck UI
	update_ui()	

# Play a visual effect for reshuffling
func play_reshuffle_effect():
	# Simple animation showing cards moving from discard to deck
	if discard_pile and deck_status:
		# Create a temporary sprite to show movement
		var temp_sprite = Sprite2D.new()
		temp_sprite.texture = preload("res://Cards/card-front-bg.png")  # Use an appropriate texture
		temp_sprite.scale = Vector2(0.5, 0.5)  # Smaller version for the animation
		add_child(temp_sprite)
		
		# Position at discard pile
		temp_sprite.global_position = discard_pile.global_position
		
		# Create animation
		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN_OUT)
		
		# Move to deck position
		tween.tween_property(temp_sprite, "global_position", deck_status.global_position, 0.5)
		
		# Scale down as it reaches the deck
		tween.parallel().tween_property(temp_sprite, "scale", Vector2(0.1, 0.1), 0.5)
		
		# Add a little rotation for visual interest
		tween.parallel().tween_property(temp_sprite, "rotation_degrees", 360, 0.5)
		
		# Clean up after animation
		tween.tween_callback(func(): temp_sprite.queue_free())
