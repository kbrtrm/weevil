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
	
	# Set up enemies from Global data
	setup_enemies()
	
	# Wait for Global to initialize the deck
	if not Global.deck_initialized:
		print("BattleManager: Waiting for deck to be initialized...")
		await Global.deck_initialized_signal
	
	# Wait for Global to initialize the deck
	if not Global.deck_initialized:
		print("BattleManager: Waiting for deck to be initialized...")
		await Global.deck_initialized_signal
		
	# Add a slight delay to allow all nodes to fully initialize
	await get_tree().create_timer(0.1).timeout
	
	print("BattleManager: Starting first turn")
	# Start the first turn
	start_turn()

# New function to set up enemies based on global data
func setup_enemies():
	if Global.current_battle_enemies.size() > 0:
		var enemy = get_enemy()
		if enemy:
			var enemy_data = Global.current_battle_enemies[0]
			# Set enemy properties from data
			enemy.enemy_name = enemy_data.get("name", "Enemy")
			enemy.max_health = enemy_data.get("max_health", 15)
			enemy.base_damage = enemy_data.get("base_damage", 8)
			
			# Initialize health
			enemy.health = enemy.max_health
			
			# Update UI
			enemy.update_health_display()
			enemy.update_intent_display()
			
			print("BattleManager: Enemy setup complete - " + enemy.enemy_name)
	else:
		print("Warning: No enemy data found for battle")


func start_turn():
	if is_player_turn:
		# Player's turn - Make sure to reset player's block
		var player = get_player()
		if player and player.has_method("start_turn"):
			print("BattleManager: Calling player.start_turn()")
			player.start_turn()  # This will reset player's block to 0
			
		# Handle energy and card draw
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

# Helper function to convert world position to screen position
func get_screen_position(world_pos: Vector2) -> Vector2:
	# Get the current camera
	var camera = get_viewport().get_camera_2d()
	if not camera:
		# If no camera, use the global position directly
		return world_pos
	
	# Convert global position to screen position
	var viewport_transform = get_viewport().get_canvas_transform()
	var screen_pos = viewport_transform * world_pos
	
	return screen_pos

# Modified end_battle function in BattleManager.gd
func end_battle(player_won = true):
	# Get the stored enemy ID and position
	var enemy_id = Global.current_enemy_id
	var enemy_position = Global.enemy_position  # This is the global position in the overworld
	var overworld_scene = Global.previous_scene_path
	
	# Enhanced debugging
	print("\n=== BattleManager.end_battle ===")
	print("player_won: " + str(player_won))
	print("enemy_id: " + str(enemy_id))
	print("enemy_position: " + str(enemy_position))
	print("overworld_scene: " + str(overworld_scene))
	
	if player_won:
		print("BattleManager: Battle won! Enemy will be removed.")
		
		# CRITICAL: Mark the enemy as defeated in Global
		if enemy_id != -1:
			print("BattleManager: Marking enemy " + str(enemy_id) + " as defeated")
			Global.mark_enemy_defeated(overworld_scene, enemy_id)
			
			# Double-check that the enemy was actually marked
			if Global.is_enemy_defeated(overworld_scene, enemy_id):
				print("BattleManager: Successfully verified enemy " + str(enemy_id) + " is marked as defeated")
			else:
				print("BattleManager: WARNING - Failed to mark enemy as defeated! Check implementation.")
		else:
			print("BattleManager: WARNING - No valid enemy ID to mark as defeated!")
	else:
		print("BattleManager: Battle lost.")
	
	# Since we can't modify Global directly, let's use a position that makes sense for the battle scene
	# Calculate center of screen
	var screen_position = get_viewport().get_visible_rect().size / 2
	print("BattleManager: Using screen center for transition: " + str(screen_position))
	
	# End the battle with transition effect using the screen position
	TransitionManager.end_combat(screen_position, overworld_scene, player_won)
	print("=== End BattleManager.end_battle ===\n")

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
