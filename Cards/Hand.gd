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
const TargetingSystemScene = preload("res://Cards/CardTargetingSystem.gd")
var deck = []
var cards_in_hand = []

# Drag and hover tracking
var card_being_dragged = null
var drag_offset = Vector2.ZERO
var hovered_card = null

# Targeting arrow
var targeting_arrow: SimpleTargetingArrow
var targeting_manager: CardTargetingManager

# References to other nodes
@onready var discard_pile = find_child("DiscardPile")
@onready var deck_status = find_child("DeckStatus")
@onready var deck_count_label = deck_status.find_child("Count")

# Called when the node enters the scene tree
func _ready() -> void:
	# Create targeting arrow
	targeting_arrow = SimpleTargetingArrow.new()
	targeting_arrow.name = "TargetingArrow"
	add_child(targeting_arrow)
	
	# Don't create targeting manager - use the one from BattleManager
	# targeting_manager will be found dynamically
	
	# Wait for Global.deck to be initialized
	if not Global.deck_initialized:
		await Global.deck_initialized_signal
	
	# Initialize and shuffle deck
	if Global.deck.size() == 0:
		push_error("Hand: Global.deck is empty after initialization!")
		# Create an emergency deck to avoid crashes
		create_emergency_deck()
	else:
		deck = Global.deck.duplicate()
		
	randomize()
	deck.shuffle()
	
	# Update UI initially
	update_ui()

# Create an emergency deck if everything else fails
func create_emergency_deck():
	deck = [
		{
			"name": "Emergency Card",
			"desc": "Deal 5 damage.",
			"description": "Deal 5 damage.",
			"cost": 1,
			"effects": [
				{"type": "damage", "value": 5, "target": "enemy"}
			]
		}
	]
	
	# Duplicate to create multiple cards
	var base_card = deck[0]
	for i in range(9):
		deck.append(base_card.duplicate())

# Draw specified number of cards
func draw_card(count: int = 1):
	# Check if we need to reshuffle before attempting to draw
	if deck.size() == 0 and discard_pile and discard_pile.discarded_cards.size() > 0:
		reshuffle_discard_pile()
	
	# Now proceed with drawing if possible
	if deck.size() == 0:
		return
	
	for i in range(count):
		# Check if deck is empty and reshuffle discard pile if needed
		if deck.size() <= 0:
			reshuffle_discard_pile()
			
		if deck.size() <= 0 or cards_in_hand.size() >= MAX_CARDS_IN_HAND:
			break
			
		# Get card data and create instance
		var card_data = deck.pop_front()
		
		if card_data == null:
			continue
			
		var card = CardScene.instantiate()
		
		# Set properties
		card.card_name = card_data.name
		card.card_cost = card_data.cost if "cost" in card_data else 1
		card.card_type = card_data.type if "type" in card_data else ""
		
		# Handle different description property names
		if "description" in card_data:
			card.card_desc = card_data.description
		elif "desc" in card_data:
			card.card_desc = card_data.desc
		else:
			card.card_desc = "No description"
		
		# Handle different art property paths
		if "artwork_path" in card_data and card_data.artwork_path:
			card.card_art = load(card_data.artwork_path)
		elif "art" in card_data and card_data.art:
			card.card_art = load(card_data.art)
		
		# Add to scene with initial properties
		add_child(card)
		card.position = deck_status.position
		card.rotation_degrees = -60.0
		
		# Add to hand array
		cards_in_hand.append(card)
	
	# Update UI and arrange cards only once
	update_ui()
	arrange_cards(true)

# Update UI elements
func update_ui():
	if deck_count_label:
		deck_count_label.text = str(deck.size())

# Process input for dragging cards
func _process(delta: float) -> void:
	if card_being_dragged:
		# Update targeting arrow with raised card position
		if targeting_arrow:
			var mouse_pos = get_global_mouse_position()
			# Arrow starts from top center of raised card position
			var raised_card_position = card_being_dragged.original_position + Vector2(0, -20)
			var card_top_center = raised_card_position + Vector2(0, -62)
			targeting_arrow.start_position = card_top_center
			targeting_arrow.update_arrow(mouse_pos)
		
		# Update target highlighting based on mouse position
		var tm = get_targeting_manager()
		if tm:
			tm.update_hover_highlighting(get_global_mouse_position())

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
		cards_in_hand.erase(card)
		arrange_cards()
		update_ui()

# Input handling for card dragging and keyboard/controller navigation
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
	
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		# Right-click to deselect all cards
		deselect_all_cards()
	
	# Handle input actions (works for keyboard AND controller)
	if Input.is_action_just_pressed("ui_left"):
		select_previous_card()
	elif Input.is_action_just_pressed("ui_right"):
		select_next_card()
	elif Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("ui_select"):
		play_selected_card()
	elif Input.is_action_just_pressed("ui_cancel"):
		deselect_all_cards()
	elif Input.is_action_just_pressed("end_turn"):
		end_turn()
	
	# Handle number keys for direct card selection (keyboard only)
	elif event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9:
				var card_number = event.keycode - KEY_1
				if card_number < cards_in_hand.size():
					deselect_all_cards()
					cards_in_hand[card_number].select_card()
			KEY_0:
				var card_number = 9
				if card_number < cards_in_hand.size():
					deselect_all_cards()
					cards_in_hand[card_number].select_card()
			KEY_E:
				# Debug key to reduce energy (for testing insufficient energy)
				var battle_manager = get_battle_manager()
				if battle_manager:
					var energy_manager = battle_manager.get_node_or_null("EnergyManager")
					if energy_manager and energy_manager.has_method("use_energy"):
						energy_manager.use_energy(1)
						print("Hand: DEBUG - Reduced energy by 1")

# Handle card drag started
func on_card_drag_started(card):
	print("Hand: on_card_drag_started called for: ", card.card_name)
	card_being_dragged = card
	
	# Clear highlights on other cards
	for c in cards_in_hand:
		if c != card and c.has_method("set_highlight"):
			c.set_highlight(false)
	
	# Start highlighting valid targets immediately using the shared targeting manager
	var tm = get_targeting_manager()
	if tm:
		print("Hand: Found targeting manager, starting targeting")
		tm.start_targeting(card)
	else:
		print("Hand: ERROR - No targeting manager available!")
	
	# Wait for the card's animation to complete before showing arrow
	await get_tree().create_timer(0.15).timeout  # Match the animation duration
	
	# Only show arrow if card is still being dragged
	if card_being_dragged == card and targeting_arrow:
		# Card will be at raised position (original + 20 pixels up)
		var raised_card_position = card.original_position + Vector2(0, -20)
		var card_top_center = raised_card_position + Vector2(0, -62)
		targeting_arrow.show_arrow(card_top_center)

# Handle card drag ended - RESTORED ORIGINAL VERSION
func on_card_drag_ended(card, drop_position):
	print("Hand: on_card_drag_ended called for: ", card.card_name)
	card_being_dragged = null
	
	# Hide targeting arrow
	if targeting_arrow:
		targeting_arrow.hide_arrow()
	
	# Stop target highlighting using the shared targeting manager
	var tm = get_targeting_manager()
	if tm:
		print("Hand: Stopping targeting")
		tm.stop_targeting()
	else:
		print("Hand: ERROR - No targeting manager for stop_targeting!")
	
	# Use simple targeting - restored original system
	var drop_target = get_drop_target_at_position(drop_position)
	
	if drop_target:
		# Get target information from our simple system
		var target_node = drop_target.target_node
		var target_type = drop_target.target_type
		
		# Check if the card can be played (energy cost, etc.) - but don't remove it yet
		if can_play_card(card):
			# Play the card with targeting information
			play_card_on_target(card, target_node, target_type, drop_target)
		else:
			# Can't play card - return to hand with shake effect
			return_card_to_hand(card, true)  # true = shake for insufficient energy
	else:
		# Invalid drop - return to hand and select
		return_card_to_hand_and_select(card)

# Check if a card can be played (energy requirements, etc.)
func can_play_card(card) -> bool:
	# Get the energy manager
	var battle_manager = get_battle_manager()
	var energy_manager = null
	if battle_manager:
		energy_manager = battle_manager.get_node_or_null("EnergyManager")
	
	if energy_manager and energy_manager.has_method("can_play_card"):
		return energy_manager.can_play_card(card.card_cost)
	elif energy_manager and energy_manager.has_method("get_current_energy"):
		var current_energy = energy_manager.get_current_energy()
		return current_energy >= card.card_cost
	else:
		return true

# Play a card on a specific target
func play_card_on_target(card, target_node, target_type, drop_target):
	# Get the energy manager to check and deduct energy
	var battle_manager = get_battle_manager()
	var energy_manager = null
	if battle_manager:
		energy_manager = battle_manager.get_node_or_null("EnergyManager")
	
	# Try to use energy - the EnergyManager will handle the check and deduction
	var energy_used_successfully = false
	if energy_manager and energy_manager.has_method("use_energy"):
		energy_used_successfully = energy_manager.use_energy(card.card_cost)
		
		if not energy_used_successfully:
			# Return card to hand with shake effect
			return_card_to_hand(card, true)  # true = shake for insufficient energy
			return  # Exit early - don't play the card
	else:
		energy_used_successfully = true
	
	# Only proceed if energy was successfully used
	if energy_used_successfully:
		# Remove card from hand ONLY after energy is successfully used
		cards_in_hand.erase(card)
		
		# Apply card effects with targeting
		if card.has_method("play_effect"):
			card.play_effect(target_node, target_type)
		
		# Move card to discard pile
		move_card_to_discard(card)
		
		# Update hand arrangement
		arrange_cards()
		update_ui()

# Get the targeting manager from the scene
func get_targeting_manager():
	if not targeting_manager:
		# Look for targeting manager in the scene
		targeting_manager = get_tree().get_first_node_in_group("targeting_manager")
		if not targeting_manager:
			print("Hand: WARNING - No targeting manager found in scene!")
	return targeting_manager

# Helper function to get battle manager
func get_battle_manager():
	var current_node = get_parent()
	while current_node and not current_node.has_method("get_player"):
		current_node = current_node.get_parent()
	return current_node

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

# Get a drop target at position - NEW VERSION using actual drop zones
func get_drop_target_at_position(position):
	# Get all drop zone Area2D nodes
	var drop_zones = get_tree().get_nodes_in_group("drop_targets")
	
	# Check each drop zone to see if position is inside it
	for drop_zone in drop_zones:
		if not is_instance_valid(drop_zone):
			continue
			
		var collision_shape = drop_zone.get_node_or_null("CollisionShape2D")
		if not collision_shape or not collision_shape.shape:
			continue
		
		# Convert global position to drop zone's local space
		var local_pos = drop_zone.to_local(position)
		
		# Check if position is inside the collision shape
		if collision_shape.shape is RectangleShape2D:
			var rect_shape = collision_shape.shape as RectangleShape2D
			var rect = Rect2(-rect_shape.size/2, rect_shape.size)
			
			if rect.has_point(local_pos):
				var target_node = drop_zone.get_meta("target_node", null)
				var target_type = drop_zone.get_meta("target_type", "unknown")
				
				return {
					"target_node": target_node,
					"target_type": target_type,
					"drop_zone": drop_zone
				}
	
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
	if card_being_dragged or card.is_selected:
		return
		
	hovered_card = get_top_card_at_position(get_global_mouse_position())
	update_all_highlights()

# Handle card unhover
func on_card_unhovered(card):
	if card_being_dragged or card.is_selected:
		return
		
	# Short delay to prevent flickering
	await get_tree().create_timer(0.05).timeout
	
	hovered_card = get_top_card_at_position(get_global_mouse_position())
	update_all_highlights()

# Update highlights for all cards
func update_all_highlights():
	# Clear all highlights first, but preserve selected cards
	for card in cards_in_hand:
		if is_instance_valid(card) and card.has_method("set_highlight"):
			# Only clear highlight if card is not selected
			if not card.is_selected:
				card.set_highlight(false)
	
	# Set highlight for dragged card (highest priority)
	if card_being_dragged and card_being_dragged.has_method("set_highlight"):
		card_being_dragged.set_highlight(true)
	# Set highlight for selected cards (second priority)
	elif hovered_card and hovered_card.has_method("set_highlight") and not hovered_card.is_selected:
		# Only highlight hovered card if it's not already selected
		hovered_card.set_highlight(true)

func _on_deck_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			print("Opening deck viewer with " + str(deck.size()) + " cards")
			
			# Create a safe version of the deck for viewing
			var view_deck = []
			for card_data in deck:
				# Create a clean copy with only the necessary properties
				var safe_card = {
					"name": card_data.name,
					"cost": card_data.cost if "cost" in card_data else 1
				}
				
				# Handle different property names
				if "description" in card_data:
					safe_card["description"] = card_data.description
				elif "desc" in card_data:
					safe_card["description"] = card_data.desc  # Unify to use 'description'
				else:
					safe_card["description"] = "No description"
					
				# Handle different art property names
				if "artwork_path" in card_data and card_data.artwork_path:
					safe_card["art"] = card_data.artwork_path
				elif "art" in card_data and card_data.art:
					safe_card["art"] = card_data.art
					
				view_deck.append(safe_card)
			
			var viewer = preload("res://Cards/DeckViewer.tscn").instantiate()
			add_child(viewer)
			
			# Position at center of screen
			var screen_size = get_viewport_rect().size
			viewer.position = Vector2(screen_size.x / 2, screen_size.y / 2)
			viewer.z_index = 2000
			
			# Display the deck
			viewer.display_deck(view_deck, "Remaining Cards: " + str(deck.size()))
			
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
	
# Reshuffle discard pile into deck
func reshuffle_discard_pile():
	# First, check if we have a discard pile reference
	if not discard_pile or discard_pile.discarded_cards.size() <= 0:
		return
		
	# Create a temporary array to hold card data
	var cards_to_add = []
	
	# Get all card data from discarded cards
	for discarded_card in discard_pile.discarded_cards:
		# Try to get original card data from CardDatabase for proper effects
		var original_card_data = CardDatabase.get_card_by_name(discarded_card.card_name)
		
		if original_card_data:
			# If we found it in the database, use that data (complete with effects)
			cards_to_add.append(original_card_data)
		else:
			# Fallback to reconstructing from the card instance
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

# Return card to hand position and select it
func return_card_to_hand_and_select(card):
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
	
	# Get the original position
	if "original_position" in card and card.original_position != Vector2.ZERO:
		var target_pos = card.original_position
		
		# Animate card back to position with proper rotation
		tween.tween_property(card, "position", target_pos, 0.3)
		tween.parallel().tween_property(card, "rotation_degrees", proper_rotation, 0.3)
		
		# Save the proper rotation so the card remembers it
		card.original_rotation = proper_rotation
		
		# After animation completes, select the card
		tween.tween_callback(func(): card.select_card())
	else:
		# Fallback: just arrange all cards and select
		arrange_cards()
		card.select_card()
	
	# Update highlights
	update_all_highlights()

# Select the previous card (left)
func select_previous_card():
	if cards_in_hand.size() == 0:
		return
	
	var current_selected = get_selected_card()
	var current_index = -1
	
	# Find current selected card index
	if current_selected:
		current_index = cards_in_hand.find(current_selected)
	
	# Calculate previous index (wrap around)
	var previous_index = current_index - 1
	if previous_index < 0:
		previous_index = cards_in_hand.size() - 1
	
	# If no card was selected, start with the last card
	if current_index == -1:
		previous_index = cards_in_hand.size() - 1
	
	# Deselect current and select previous
	deselect_all_cards()
	if previous_index >= 0 and previous_index < cards_in_hand.size():
		cards_in_hand[previous_index].select_card()

# Select the next card (right)
func select_next_card():
	if cards_in_hand.size() == 0:
		return
	
	var current_selected = get_selected_card()
	var current_index = -1
	
	# Find current selected card index
	if current_selected:
		current_index = cards_in_hand.find(current_selected)
	
	# Calculate next index (wrap around)
	var next_index = current_index + 1
	if next_index >= cards_in_hand.size():
		next_index = 0
	
	# If no card was selected, start with the first card
	if current_index == -1:
		next_index = 0
	
	# Deselect current and select next
	deselect_all_cards()
	if next_index >= 0 and next_index < cards_in_hand.size():
		cards_in_hand[next_index].select_card()

# Play the currently selected card
func play_selected_card():
	var selected_card = get_selected_card()
	if not selected_card:
		print("Hand: No card selected to play")
		return
	
	print("Hand: Playing selected card via keyboard/controller: ", selected_card.card_name)
	
	# Find a valid drop target - for now, let's find the first one
	# Later you can expand this to cycle through multiple enemies
	var targets = get_tree().get_nodes_in_group("drop_targets")
	
	if targets.size() > 0:
		var target = targets[0]  # Play on first available target
		
		# Emit the card_played signal
		if target.has_signal("card_played"):
			target.emit_signal("card_played", selected_card)
			
			# After playing card, automatically select first remaining card
			await get_tree().process_frame  # Wait one frame for card to be removed
			auto_select_first_card()
		else:
			print("Hand: Target doesn't have card_played signal")
	else:
		print("Hand: No valid targets found for card")
		# Give user feedback that card can't be played
		selected_card.deselect_card()
		shake_card(selected_card)
		
# Select first card
func select_first_card():
	if cards_in_hand.size() > 0:
		deselect_all_cards()
		cards_in_hand[0].select_card()

# Select last card
func select_last_card():
	if cards_in_hand.size() > 0:
		deselect_all_cards()
		cards_in_hand[cards_in_hand.size() - 1].select_card()
		
# Deselect all cards (useful for canceling selection)
func deselect_all_cards():
	for card in cards_in_hand:
		if card.has_method("deselect_card"):
			card.deselect_card()

# Handle card selection
func on_card_selected(card):
	# Deselect all other cards first
	for c in cards_in_hand:
		if c != card and c.has_method("deselect_card"):
			c.deselect_card()
	
	print("Hand: Card selected - ", card.card_name)

# Get the currently selected card
func get_selected_card():
	for card in cards_in_hand:
		if card.has_method("is_card_selected") and card.is_card_selected():
			return card
	return null

# End the current turn
func end_turn():
	print("Hand: Ending turn via keyboard")
	
	# Deselect all cards when ending turn
	deselect_all_cards()
	
	# Find the battle manager to end the turn
	var battle_manager = get_parent()
	while battle_manager and not battle_manager.has_method("end_turn"):
		battle_manager = battle_manager.get_parent()
	
	if battle_manager and battle_manager.has_method("end_turn"):
		battle_manager.end_turn()
	else:
		print("Hand: Could not find battle manager to end turn")

# Show targeting indicators when dragging - TRANSPARENT VERSION
func show_targeting_indicators():
	# Get all drop zones
	var drop_zones = get_tree().get_nodes_in_group("drop_targets")
	
	for drop_zone in drop_zones:
		if not is_instance_valid(drop_zone):
			continue
			
		# Keep drop zones transparent - no color changes
		var visual_indicator = drop_zone.get_node_or_null("VisualIndicator")
		if visual_indicator:
			# Don't change color or visibility - keep them invisible
			pass

func create_targeting_indicator(target_node: Node2D, target_type: String, color: Color):
	var indicator = ColorRect.new()
	indicator.size = Vector2(80, 80)  # Match the targeting radius (80px)
	indicator.color = color
	indicator.position = target_node.global_position - Vector2(40, 40)  # Center it
	indicator.name = "TargetIndicator_" + target_type
	indicator.z_index = 500
	
	# Add to the scene root so it's visible over everything
	get_tree().root.add_child(indicator)

# Hide targeting indicators - TRANSPARENT VERSION
func hide_targeting_indicators():
	# Get all drop zones and ensure their indicators stay hidden
	var drop_zones = get_tree().get_nodes_in_group("drop_targets")
	
	for drop_zone in drop_zones:
		if not is_instance_valid(drop_zone):
			continue
			
		var visual_indicator = drop_zone.get_node_or_null("VisualIndicator")
		if visual_indicator:
			# Keep indicators transparent and hidden
			visual_indicator.visible = false

# Automatically select the first card in hand (for controller flow)
func auto_select_first_card():
	if cards_in_hand.size() > 0:
		# Make sure no cards are selected first
		deselect_all_cards()
		
		# Wait a tiny bit to ensure everything is updated
		await get_tree().create_timer(0.1).timeout
		
		# Select the first card
		if cards_in_hand.size() > 0:  # Check again in case hand changed
			cards_in_hand[0].select_card()
			print("Hand: Auto-selected first card for controller: ", cards_in_hand[0].card_name)
