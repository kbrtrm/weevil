# BattleManager.gd
extends Node2D

signal turn_started(turn_number, is_player_turn)
signal turn_ended(turn_number, is_player_turn)

var current_turn = 1
var is_player_turn = true

@onready var energy_manager = $"EnergyManager"
@onready var hand = $"Hand"
@onready var end_turn_button = $EndTurnButton

func _ready():
	# Connect end turn button
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Start the first turn
	start_turn()

func start_turn():
	if is_player_turn:
		# Player's turn
		energy_manager.new_turn()
		hand.draw_card(5)  # Draw a card at the start of turn
	else:
		# Enemy's turn
		# Implement enemy AI here
		await get_tree().create_timer(1.0).timeout
		end_turn()  # Automatically end enemy turn after AI acts
	
	# Emit signal
	turn_started.emit(current_turn, is_player_turn)

# Play a visual effect to indicate end of turn
func play_end_turn_effect():
	pass

# Make end_turn() an async function that waits for discard_hand to complete
func end_turn():
	if is_player_turn:
		# Play end turn effect
		play_end_turn_effect()
		
		# Wait for discard to complete before continuing
		await discard_hand()
	
	# Emit signal
	turn_ended.emit(current_turn, is_player_turn)
	
	# Switch turns
	is_player_turn = !is_player_turn
	
	if !is_player_turn:
		# If it's now enemy's turn
		current_turn += 1
	
	# Start the next turn
	start_turn()

# Modify discard_hand to properly return when complete
func discard_hand():
	# Create a copy of the array since we'll be modifying it while iterating
	var cards_to_discard = hand.cards_in_hand.duplicate()
	
	# Discard each card with a slight delay between them for visual effect
	for i in range(cards_to_discard.size()):
		var card = cards_to_discard[i]
		if card:
			# Animate each card to the discard pile with slight delay
			await get_tree().create_timer(0.1).timeout
			hand.discard_card_to_pile(card)

func _on_end_turn_pressed():
	if is_player_turn:
		end_turn()
		
# Get the enemy object
func get_enemy():
	# Return the current enemy in battle
	# For now, just return the first enemy node found
	return get_node_or_null("Enemy")

# Get the player object
func get_player():
	# Return the player object
	return get_node_or_null("Player")
