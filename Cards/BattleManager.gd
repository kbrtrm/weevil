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
	# Add to battle managers group so Player/Enemy can call us
	add_to_group("battle_managers")
	
	# Connect end turn button
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	
	# Set up enemies from Global data
	setup_enemies()
	
	# Wait one frame to ensure all enemy instances are properly added to the scene
	await get_tree().process_frame
	
	# Start entrance animations AFTER enemies are fully set up
	animate_battle_start()
	
	# Wait for Global to initialize the deck
	if not Global.deck_initialized:
		await Global.deck_initialized_signal
	
	# Wait for Global to initialize the deck
	if not Global.deck_initialized:
		await Global.deck_initialized_signal
		
	# Add a slight delay to allow all nodes to fully initialize
	await get_tree().create_timer(0.1).timeout
	
	# Start the first turn
	start_turn()

# New function to set up enemies based on global data
func setup_enemies():
	if Global.current_battle_enemies.size() > 0:
		# Remove the default enemy if there are multiple enemies to spawn
		if Global.current_battle_enemies.size() > 1:
			var default_enemy = get_node_or_null("Enemy")
			if default_enemy:
				default_enemy.queue_free()
		
		# Create an enemy for each enemy data
		for i in range(Global.current_battle_enemies.size()):
			var enemy_data = Global.current_battle_enemies[i]
			var enemy_node = null
			
			if i == 0 and Global.current_battle_enemies.size() == 1:
				# Use the existing enemy for single enemy battles
				enemy_node = get_node_or_null("Enemy")
			else:
				# Create new enemy instances for multiple enemies
				var enemy_scene = preload("res://Battle/Enemy.tscn")
				enemy_node = enemy_scene.instantiate()
				enemy_node.name = "Enemy" + str(i + 1)
				add_child(enemy_node)
			
			if enemy_node:
				# Set enemy properties from data
				enemy_node.enemy_name = enemy_data.get("name", "Enemy")
				enemy_node.max_health = enemy_data.get("max_health", 15)
				enemy_node.base_damage = enemy_data.get("base_damage", 8)
				
				# Position enemies side by side
				if Global.current_battle_enemies.size() > 1:
					# Use the single enemy position as reference and position multiple enemies around it
					var base_x = 416  # Same as single enemy position
					var base_y = 100  # Same as single enemy position
					var spacing = 120  # Space between enemies
					
					# Calculate starting position so enemies are centered around the base position
					var total_width = (Global.current_battle_enemies.size() - 1) * spacing
					var start_x = base_x - (total_width / 2)
					
					enemy_node.position.x = start_x + (i * spacing)
					enemy_node.position.y = base_y
				else:
					# Single enemy positioning
					enemy_node.position.x = 416
					enemy_node.position.y = 100
				
				# Initialize health
				enemy_node.health = enemy_node.max_health
				
				# Update UI
				enemy_node.update_health_display()
				enemy_node.update_intent_display()
	
	# Create drop zones after enemies are set up
	# (Will be handled after entrance animations complete)


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
	
# Add this method to handle battle completion
func end_battle(player_won = true):
	# Get the stored enemy ID and position
	var enemy_id = Global.current_enemy_id
	var enemy_ids = Global.current_battle_enemy_ids
	var enemy_position = Global.enemy_position
	var overworld_scene = Global.previous_scene_path
	
	# Enhanced debugging
	print("\n=== BattleManager.end_battle ===")
	print("player_won: " + str(player_won))
	print("primary_enemy_id: " + str(enemy_id))
	print("all_enemy_ids: " + str(enemy_ids))
	print("enemy_position: " + str(enemy_position))
	print("overworld_scene: " + str(overworld_scene))
	
	if player_won:
		print("BattleManager: Battle won! All enemies will be removed.")
		
		# Mark ALL participating enemies as defeated
		if enemy_ids.size() > 0:
			for id in enemy_ids:
				print("BattleManager: Marking enemy " + str(id) + " as defeated")
				Global.mark_enemy_defeated(overworld_scene, id)
				
				# Verify each enemy was marked
				if Global.is_enemy_defeated(overworld_scene, id):
					print("BattleManager: Successfully verified enemy " + str(id) + " is marked as defeated")
				else:
					print("BattleManager: WARNING - Failed to mark enemy " + str(id) + " as defeated!")
			
			print("BattleManager: Marked ", enemy_ids.size(), " enemies as defeated")
		else:
			print("BattleManager: WARNING - No enemy IDs to mark as defeated!")
			
			# Fallback to single enemy ID if available
			if enemy_id != -1:
				print("BattleManager: Using fallback - marking single enemy " + str(enemy_id) + " as defeated")
				Global.mark_enemy_defeated(overworld_scene, enemy_id)
	else:
		print("BattleManager: Battle lost.")
	
	# Clear the battle enemy IDs for next battle
	Global.current_battle_enemy_ids = []
	
	# End the battle with transition effect
	TransitionManager.end_combat(enemy_position, overworld_scene, player_won)
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

# Check if all enemies are defeated
func check_battle_end():
	var all_enemies = get_all_enemies()
	var alive_enemies = []
	
	for enemy in all_enemies:
		if enemy.health > 0:
			alive_enemies.append(enemy)
	
	print("BattleManager: check_battle_end - ", alive_enemies.size(), " enemies still alive out of ", all_enemies.size(), " total")
	
	if alive_enemies.size() == 0:
		print("BattleManager: All enemies defeated! Player wins!")
		end_battle(true)  # true = player won
	else:
		print("BattleManager: Battle continues with ", alive_enemies.size(), " enemies remaining")

# Set up individual drop zones for each enemy and the player
func setup_drop_zones():
	print("BattleManager: Setting up drop zones")
	
	# Remove the existing single drop target
	var old_drop_target = get_node_or_null("DropTarget")
	if old_drop_target:
		print("BattleManager: Removing old drop target")
		old_drop_target.queue_free()
	
	# Create drop zone for player
	var player = get_player()
	if player:
		print("BattleManager: Found player at position: ", player.position, " global: ", player.global_position)
		create_drop_zone_for_target(player, "player")
	else:
		print("BattleManager: WARNING - No player found for drop zone creation")
	
	# Create drop zones for all enemies
	var all_enemies = get_all_enemies()
	print("BattleManager: Found ", all_enemies.size(), " enemies")
	for i in range(all_enemies.size()):
		var enemy = all_enemies[i]
		print("BattleManager: Found enemy ", i, " at position: ", enemy.position, " global: ", enemy.global_position)
		create_drop_zone_for_target(enemy, "enemy_" + str(i))

func create_drop_zone_for_target(target_node: Node2D, target_type: String):
	var drop_zone = Area2D.new()
	drop_zone.name = "DropZone_" + target_type
	drop_zone.input_pickable = true
	
	# Add the drop zone to the battle scene FIRST
	add_child(drop_zone)
	
	# Position the drop zone over the target - use the target's position directly
	drop_zone.position = target_node.position  # This should match the target's position
	
	print("BattleManager: Target ", target_type, " position: ", target_node.position)
	print("BattleManager: Target ", target_type, " global_position: ", target_node.global_position)
	print("BattleManager: Drop zone positioned at: ", drop_zone.position)
	
	# Create collision shape - SMALLER SIZE
	var collision_shape = CollisionShape2D.new()
	var rectangle_shape = RectangleShape2D.new()
	rectangle_shape.size = Vector2(80, 120)  # Reduced from 120x180 to 80x120
	collision_shape.shape = rectangle_shape
	collision_shape.name = "CollisionShape2D"
	drop_zone.add_child(collision_shape)
	
	# Create visual indicator - TRANSPARENT for release version
	var visual_indicator = ColorRect.new()
	visual_indicator.size = Vector2(80, 120)  # Match collision shape size
	visual_indicator.position = Vector2(-40, -60)  # Center it (half of size)
	visual_indicator.color = Color(0, 0, 0, 0)  # Fully transparent
	visual_indicator.visible = false  # Hidden by default
	visual_indicator.name = "VisualIndicator"
	drop_zone.add_child(visual_indicator)
	
	# Store reference to target
	drop_zone.set_meta("target_node", target_node)
	drop_zone.set_meta("target_type", target_type)
	
	# Add to group AFTER adding to scene and setting up children
	drop_zone.add_to_group("drop_targets")
	
	print("BattleManager: Created drop zone for ", target_type, " at position ", drop_zone.position, " global: ", drop_zone.global_position)
	
	# Debug: Verify collision shape was added
	var collision_check = drop_zone.get_node_or_null("CollisionShape2D")
	if collision_check:
		print("BattleManager: Collision shape successfully added to ", target_type)
	else:
		print("BattleManager: ERROR - Collision shape not found in ", target_type)
		
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

# Track entrance animation completion
var entrance_animations_completed = 0
var total_entrance_animations = 0
var drop_zones_setup = false

# Animate the start of battle (supports multiple enemies)
func animate_battle_start():
	print("BattleManager: Starting battle entrance animations")
	
	# Get player
	var player = get_player()
	print("BattleManager: Found player: ", player != null)
	
	# Get all enemies
	var enemies = get_all_enemies()
	print("BattleManager: Found enemies: ", enemies.size())
	for i in range(enemies.size()):
		print("BattleManager: Enemy ", i, " name: ", enemies[i].name, " position: ", enemies[i].position)
	
	# Calculate total animations
	total_entrance_animations = 0
	entrance_animations_completed = 0
	drop_zones_setup = false  # Reset this flag
	
	if player and player.has_method("animate_entrance"):
		total_entrance_animations += 1
		print("BattleManager: Player will animate")
	
	for enemy in enemies:
		if enemy.has_method("animate_entrance"):
			total_entrance_animations += 1
			print("BattleManager: Enemy ", enemy.name, " will animate")
	
	print("BattleManager: Expecting ", total_entrance_animations, " entrance animations")
	
	# Start player animation
	if player and player.has_method("animate_entrance"):
		player.animate_entrance()
		print("BattleManager: Started player animation")
	
	# Start enemy animations with staggered delays
	for i in range(enemies.size()):
		var enemy = enemies[i]
		if enemy and enemy.has_method("animate_entrance"):
			enemy.animate_entrance(i, enemies.size())
			print("BattleManager: Started enemy ", i, " (", enemy.name, ") animation")
	
	print("BattleManager: All animations started")

# Called by Player when entrance animation completes
func on_player_entrance_complete():
	entrance_animations_completed += 1
	print("BattleManager: Player entrance completed (", entrance_animations_completed, "/", total_entrance_animations, ")")
	check_setup_drop_zones()

# Called by Enemy when entrance animation completes
func on_enemy_entrance_complete(enemy_index: int):
	entrance_animations_completed += 1
	print("BattleManager: Enemy ", enemy_index + 1, " entrance completed (", entrance_animations_completed, "/", total_entrance_animations, ")")
	check_setup_drop_zones()

# Check if we should setup drop zones
func check_setup_drop_zones():
	if not drop_zones_setup and entrance_animations_completed >= total_entrance_animations:
		drop_zones_setup = true
		print("BattleManager: All entrance animations complete! Setting up drop zones...")
		# Add a tiny delay to ensure everything is settled
		await get_tree().create_timer(0.1).timeout
		setup_drop_zones()
	
# Get all enemies in the battle
func get_all_enemies():
	var enemies = []
	
	# Search all children for enemy nodes, excluding player
	for child in get_children():
		if (child.name.begins_with("Enemy") or child.has_method("take_damage")) and not child.is_in_group("player"):
			enemies.append(child)
	
	print("BattleManager: Found ", enemies.size(), " enemies")
	return enemies
