# BattleSystem.gd
extends Node2D

const DeckManager = preload("res://DeckManager.gd")

@export var player_hand_path: NodePath
@export var player_field_path: NodePath
@export var enemy_field_path: NodePath

@onready var player_hand = get_node(player_hand_path)
@onready var player_field = get_node(player_field_path)
@onready var enemy_field = get_node(enemy_field_path)

@onready var player_info = $UI/UIRoot/PlayerInfo
@onready var enemy_info = $UI/UIRoot/EnemyInfo
@onready var start_game_button = $UI/UIRoot/StartGameButton

@onready var player_mana_label = $UI/UIRoot/PlayerInfo/ManaLabel
@onready var player_deck_label = $UI/UIRoot/PlayerInfo/DeckCountLabel
@onready var enemy_mana_label = $UI/UIRoot/EnemyInfo/EnemyManaLabel
@onready var enemy_deck_label = $UI/UIRoot/EnemyInfo/EnemyDeckCountLabel

@export var card_scene: PackedScene

var player_deck_manager = DeckManager.new()
var enemy_deck_manager = DeckManager.new()

var player_mana = 0
var max_player_mana = 10
var enemy_mana = 0

var game_started = false
var current_turn = "player"  # "player" or "enemy"

# Connect to the card_played signal from HandManager
func _ready():
	add_child(player_deck_manager)
	add_child(enemy_deck_manager)
	
	player_hand.card_played.connect(_on_player_card_played)
	
	# Example deck initialization - you would load this from saved data
	var player_deck_ids = ["0001", "0002"]
	player_deck_manager.initialize_deck(player_deck_ids)
	
	var enemy_deck_ids = ["0001", "0002"]
	enemy_deck_manager.initialize_deck(enemy_deck_ids)
	
	start_game_button.pressed.connect(_on_start_game_button_pressed)
	
	# For testing - add keys to draw cards
	set_process_input(true)

func start_game():
	if game_started:
		return
		
	game_started = true
	
	# Hide the start button
	start_game_button.visible = false
	
	# Shuffle decks
	player_deck_manager.shuffle()
	enemy_deck_manager.shuffle()
	
	print("Starting game - drawing initial hand")
	
	# Draw initial hands
	var initial_cards = player_deck_manager.draw_cards(5)
	print("Initial cards drawn: ", initial_cards)
	
	var cards_added = player_hand.draw_from_deck(initial_cards)
	print("Cards added to hand: ", cards_added.size())
	
	# Place initial enemy cards
	place_enemy_card(enemy_deck_manager.draw_card())
	place_enemy_card(enemy_deck_manager.draw_card())
	
	# Start first turn
	start_turn("player")

# Update the start_turn function to update UI
func start_turn(side: String):
	current_turn = side
	
	# Visual indication of current turn
	if side == "player":
		player_info.modulate = Color(1, 1, 0.7)  # Highlight
		enemy_info.modulate = Color(0.7, 0.7, 0.7)  # Dim
	else:
		enemy_info.modulate = Color(1, 0.7, 0.7)  # Highlight enemy
		player_info.modulate = Color(0.7, 0.7, 0.7)  # Dim player
	
	if side == "player":
		# Increase mana
		player_mana = min(max_player_mana, player_mana + 1)
		
		# Draw a card
		var card_id = player_deck_manager.draw_card()
		if card_id != "":
			player_hand.add_card(card_id)
			
		# Update which cards are playable
		update_playable_cards()
		
		print("Player turn started, mana: " + str(player_mana))
	else:
		# Enemy turn
		enemy_mana = min(max_player_mana, enemy_mana + 1)
		
		# Draw a card for enemy
		var card_id = enemy_deck_manager.draw_card()
		if card_id != "":
			# Simple AI - just play the card
			place_enemy_card(card_id)
		
		# End enemy turn after a delay
		await get_tree().create_timer(1.5).timeout
		end_turn()
		
		print("Enemy turn started, mana: " + str(enemy_mana))
	
	# Update UI
	update_ui()

# Add this function to update UI
func update_ui():
	player_mana_label.text = "Mana: %d/%d" % [player_mana, max_player_mana]
	player_deck_label.text = "Deck: %d" % player_deck_manager.get_deck_size()
	enemy_mana_label.text = "Mana: %d/%d" % [enemy_mana, max_player_mana]
	enemy_deck_label.text = "Deck: %d" % enemy_deck_manager.get_deck_size()

func end_turn():
	if current_turn == "player":
		start_turn("enemy")
	else:
		start_turn("player")

func update_playable_cards():
	# Update which cards can be played based on player's mana
	for card in player_hand.hand:
		var can_play = false
		
		# Get the card cost safely
		var card_cost = 0
		if card.has_method("get_cost"):
			card_cost = card.get_cost()
		else:
			print("Warning: Card doesn't have get_cost method")
			continue
		
		# Determine if card is playable
		can_play = card_cost <= player_mana
		
		# Set playability safely
		if card.has_method("set_playable"):
			card.set_playable(can_play)
		else:
			print("Warning: Card doesn't have set_playable method")
			# Fallback to just modifying the modulate property
			card.modulate = Color(1, 1, 1) if can_play else Color(0.7, 0.7, 0.7)

func _on_player_card_played(card):
	if current_turn != "player" or not card.is_playable:
		# Not player's turn or card not playable
		return
	
	# Spend mana
	player_mana -= card.cost
	
	# Remove from hand and place on field
	player_hand.remove_card(card)
	place_player_card(card)
	
	# Update which cards are now playable
	update_playable_cards()
	update_ui()

func place_player_card(card):
	print("Player played: " + card.card_name)
	# Create a copy of the card for the field
	var card_instance = card_scene.instantiate()
	card_instance.load_data(CardDatabase.get_card(card.card_id))
	
	# Add to player field
	player_field.add_child(card_instance)
	
	# Optional: Play animation
	card_instance.scale = Vector2(0.8, 0.8)  # Slightly smaller on field
	
	print("Player played: " + card_instance.card_name)
	
	# Apply card effects based on type
	match card_instance.type:
		card_instance.CardType.ATTACK:
			# Attack card logic
			pass
		card_instance.CardType.DEFENSE:
			# Defense card logic
			pass
		card_instance.CardType.SPELL:
			# Spell card logic
			pass

func place_enemy_card(card_id: String):
	if card_id.is_empty():
		return
		
	# Get card data
	var card_data = CardDatabase.get_card(card_id)
	if card_data.size() == 0:
		return
		
	# Create a card for the enemy field
	var card_instance = card_scene.instantiate()
	card_instance.load_data(card_data)
	
	# Add to enemy field
	enemy_field.add_child(card_instance)
	
	# Optional: Play animation
	card_instance.scale = Vector2(0.8, 0.8)
	card_instance.modulate = Color(1, 0.7, 0.7)  # Slight red tint for enemy cards
	
	print("Enemy played: " + card_instance.card_name)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_D:
			# Debug key to draw a card
			var card_id = player_deck_manager.draw_card()
			if card_id != "":
				player_hand.add_card(card_id)
			update_ui()
		
		elif event.keycode == KEY_M:
			# Debug key to add mana
			player_mana = min(max_player_mana, player_mana + 1)
			update_ui()
			update_playable_cards()
		
		elif event.keycode == KEY_S:
			# Debug key to start game
			start_game()

# UI Button handlers
func _on_end_turn_button_pressed():
	if current_turn == "player":
		end_turn()

func _on_start_game_button_pressed():
	start_game()
