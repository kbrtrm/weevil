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
	
	# Wait for Global to initialize the deck
	if not Global.deck_initialized:
		print("BattleManager: Waiting for deck to be initialized...")
		await Global.deck_initialized_signal
		
	# Add a slight delay to allow all nodes to fully initialize
	await get_tree().create_timer(0.1).timeout
	
	print("BattleManager: Starting first turn")
	# Start the first turn
	start_turn()

func start_turn():
	if is_player_turn:
		# Player's turn
		energy_manager.new_turn()
		
		# Only draw cards if this isn't the very first turn (since we already drew in _ready)
		if current_turn == 1:
			# Initial hand draw at the start of the game
			print("BattleManager: Drawing initial hand of 5 cards")
			hand.draw_card(5)
		else:
			# Draw a card at the start of subsequent turns
			hand.draw_card(5)
	else:
		# Enemy's turn
		# Process enemy start_turn for all enemies
		get_tree().call_group("enemies", "start_turn")
		
		# Add a delay before automatically ending enemy turn
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
		# Call end_turn on player
		var player = get_player()
		if player and player.has_method("end_turn"):
			player.end_turn()
			
		# Play end turn effect
		play_end_turn_effect()
		
		# Wait for discard to complete before continuing
		await discard_hand()
	else:
		# Call end_turn on all enemies
		get_tree().call_group("enemies", "end_turn")
	
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
		
# Get the enemy and player functions
func get_enemy():
	# Look for the Enemy node directly in the scene
	var enemy = get_node_or_null("Enemy")
	if enemy:
		return enemy
	
	# If not found, search through all children
	for child in get_children():
		if child.name == "Enemy" or child.is_in_group("enemies"):
			return child
	
	return null

func get_player():
	# Look for the Player node directly in the scene 
	var player = get_node_or_null("Player")
	if player:
		return player
	
	# If not found, search through all children
	for child in get_children():
		if child.name == "Player" or child.is_in_group("player"):
			return child
	
	return null
