# Simplified Global.gd - Modified to remove transition and directly return to overworld

extends Node

var deck = []
var deck_initialized = false
signal deck_initialized_signal

var game_paused = false

# Battle system variables
var current_battle_enemies = []
var player_position = Vector2.ZERO
var current_scene_path = ""
var enemy_position = Vector2.ZERO
var enemy_instance_id = 0
var returning_from_battle = false

# Enemy tracking system
var defeated_enemy_registry = {}  # Dictionary that maps scene paths to arrays of defeated enemy IDs
var next_enemy_id = 1  # Counter for generating unique IDs
var current_enemy_id = -1  # ID of the enemy currently in battle
var defeated_enemies = {} # Dictionary to store defeated enemies by scene path and ID

var player_properties = null  # Will be populated by the Player's store_properties_to_global function

func _ready():
	print("Global: _ready() called")
	
	# First, check if CardDatabase exists
	if not has_node("/root/CardDatabase"):
		push_error("CardDatabase autoload not found! Check project settings.")
		return
	
	# Wait for CardDatabase to be fully initialized
	var card_db = get_node("/root/CardDatabase")
	if not card_db.initialized:
		print("Global: Waiting for CardDatabase to initialize...")
		await card_db.database_initialized
	
	print("Global: CardDatabase initialized, now initializing deck...")
	call_deferred("initialize_deck")
	
	# Debug all scenes after everything is loaded
	call_deferred("debug_scenes")

# Set up the player's starting deck
func initialize_deck():
	print("Global: Begin initialize_deck()")
	
	# Clear the deck
	deck.clear()
	
	# Get CardDatabase reference
	var card_db = get_node("/root/CardDatabase")
	if not card_db or not card_db.initialized:
		push_error("CardDatabase not initialized properly!")
		return
		
	print("Global: Adding starter cards to deck")
	var success_count = 0
	
	# Add starter cards
	# 5 Pebbles
	for i in range(5):
		if add_card_to_deck("pebble"):
			success_count += 1
	
	# 3 Paperclips
	for i in range(3):
		if add_card_to_deck("paperclip"):
			success_count += 1
	
	# 3 Acorns (block)
	for i in range(3):
		if add_card_to_deck("acorn"):
			success_count += 1
	
	# 1 Penny (draw)
	for i in range(5):
		if add_card_to_deck("penny"):
			success_count += 5
		
	# 1 Gum
	if add_card_to_deck("gum"):
		success_count += 1
		
	# 1 Rubber band
	if add_card_to_deck("rubber_band"):
		success_count += 1

	# 1 Thumbtack
	if add_card_to_deck("thumbtack"):
		success_count += 1
	
	# Shuffle the deck
	randomize()
	deck.shuffle()
	
	print("Global: Deck initialized with " + str(deck.size()) + " cards")
	print("Global: Successfully added " + str(success_count) + " cards to deck")
	
	# If for some reason we have no cards, create a fallback deck
	if deck.size() == 0:
		print("Global: No cards were added! Creating fallback deck.")
		create_fallback_deck()
	
	deck_initialized = true
	emit_signal("deck_initialized_signal")

# Add a card to the deck by ID
func add_card_to_deck(card_id):
	#print("Global: Adding card to deck: " + card_id)
	
	var card_db = get_node("/root/CardDatabase")
	if not card_db:
		push_error("CardDatabase not found!")
		return false
		
	var card_data = card_db.get_card(card_id)
	if card_data:
		# Create a copy of the card data for the deck
		var deck_card = card_data.duplicate(true)
		deck.append(deck_card)
		#print("Global: Successfully added: " + card_data.name)
		return true
	else:
		push_error("Failed to add card to deck, ID not found: " + card_id)
		return false

# Create a fallback deck if the card database fails
func create_fallback_deck():
	print("Global: Creating fallback deck as card database loading failed")
	
	deck = [
		{
			"name": "Pebble",
			"desc": "Deal 6 damage.",
			"description": "Deal 6 damage.",
			"cost": 1,
			"art": "res://Images/stone1.png",
			"effects": [
				{"type": "damage", "value": 6, "target": "enemy"}
			]
		},
		{
			"name": "Paperclip",
			"desc": "Apply 2 weak. Deal 3 damage.",
			"description": "Apply 2 weak. Deal 3 damage.",
			"cost": 1,
			"art": "res://Cards/paperclip-big.png",
			"effects": [
				{"type": "damage", "value": 3, "target": "enemy"},
				{"type": "weak", "value": 2, "target": "enemy"}
			]
		},
		{
			"name": "Acorn",
			"desc": "Gain 5 block.",
			"description": "Gain 5 block.",
			"cost": 1,
			"art": "res://Images/acorn.png",
			"effects": [
				{"type": "block", "value": 5, "target": "player"}
			]
		}
	]
	
	# Duplicate the cards to get a decent deck size
	var initial_cards = deck.duplicate()
	for i in range(4):
		deck.append_array(initial_cards.duplicate())

# Simplified save_overworld_state in Global.gd
func save_overworld_state():
	# Save current scene
	current_scene_path = get_tree().current_scene.scene_file_path
	print("Global: Saved current scene: " + current_scene_path)
	
	# Save player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_position = player.global_position
		print("Global: Saved player position: " + str(player_position))
		
		# Store player properties directly through the player's method
		if player.has_method("store_properties_to_global"):
			player.store_properties_to_global()
		else:
			print("Global: Warning - Player doesn't have store_properties_to_global method!")

# Modified return_to_overworld function in Global.gd
func return_to_overworld(battle_won = false):
	print("Global: Returning to overworld. Battle won: " + str(battle_won))
	
	# Set flag to prevent re-triggering battles immediately
	returning_from_battle = true
	
	# Pause all game movement
	set_game_paused(true)
	
	# Get the center position for the transition - use enemy_position for the center
	var center_position = enemy_position
	
	# Tell TransitionManager to handle the scene transition
	TransitionManager.end_combat(center_position, current_scene_path, battle_won)
	
	# Note: The rest of this function's original code will be handled by TransitionManager
	# TransitionManager will call our setup_returned_world function after the transition completes

# New function to be called by TransitionManager after transition completes
# Enhanced setup_returned_world in Global.gd for better enemy handling
func setup_returned_world(battle_won):
	# Restore player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = player_position
		print("Global: Restored player position: " + str(player_position))
	
	# If player won, remove the defeated enemy
	if battle_won:
		print("Global: Battle won, looking for enemy to remove at position: " + str(enemy_position))
		print("Global: Enemy ID to remove: " + str(current_enemy_id))
		
		var enemies = get_tree().get_nodes_in_group("enemies")
		print("Global: Found " + str(enemies.size()) + " enemies in scene")
		
		# First try to find by ID if we have one
		var found_by_id = false
		if current_enemy_id != -1:
			for enemy in enemies:
				if enemy.has_meta("unique_id") and enemy.get_meta("unique_id") == current_enemy_id:
					print("Global: Found enemy by ID: " + str(current_enemy_id))
					enemy.queue_free()
					
					# Register as defeated for persistence
					register_defeated_enemy(current_scene_path, current_enemy_id)
					found_by_id = true
					break
		
		# If we didn't find by ID, fall back to position-based matching
		if not found_by_id:
			var closest_enemy = null
			var closest_distance = 999999.0
			
			# Find the enemy closest to the stored enemy position
			for enemy in enemies:
				var distance = enemy_position.distance_to(enemy.global_position)
				print("Global: Enemy " + enemy.name + " at distance " + str(distance))
				
				if distance < closest_distance:
					closest_distance = distance
					closest_enemy = enemy
			
			# Delete the closest enemy if it's within a reasonable range
			if closest_enemy and closest_distance < 100:
				print("Global: Removing enemy by position: " + closest_enemy.name)
				
				# Get the enemy's unique ID if available for registration
				if closest_enemy.has_meta("unique_id"):
					var enemy_id = closest_enemy.get_meta("unique_id")
					register_defeated_enemy(current_scene_path, enemy_id)
				
				closest_enemy.queue_free()
			else:
				print("Global: No matching enemy found near position: " + str(enemy_position))
	else:
		print("Global: Battle was lost or abandoned")
	
	# Reset battle flag and unpause after a short delay
	await get_tree().create_timer(0.5).timeout
	returning_from_battle = false
	set_game_paused(false)

func debug_scenes():
	# Wait for everything to load
	await get_tree().process_frame
	
	# Find all combat initiation zones
	var zones = get_tree().get_nodes_in_group("combat_zones")
	print("Found " + str(zones.size()) + " combat zones")
	
	# If none found, check all nodes
	if zones.size() == 0:
		print("Searching for CombatInitiationZone nodes...")
		var all_nodes = get_tree().get_nodes_in_group("*")
		for node in all_nodes:
			if "CombatInitiationZone" in node.name:
				print("Found node: " + node.name)
				print("  Script: " + str(node.get_script()))
				print("  Collision layer: " + str(node.collision_layer))
				print("  Collision mask: " + str(node.collision_mask))

func set_game_paused(paused):
	game_paused = paused
	
	# Pause physics processing for all relevant nodes
	get_tree().call_group("players", "set_physics_process", !paused)
	get_tree().call_group("enemies", "set_physics_process", !paused)
	
func get_overworld_scene_path() -> String:
	# Return the path to your overworld scene
	return "res://testing_ground.tscn" # Adjust this path to match your game structure

# Function to generate a unique ID for an enemy
func generate_enemy_id():
	var id = next_enemy_id
	next_enemy_id += 1
	return id

# Function to register an enemy as defeated
func register_defeated_enemy(scene_path, enemy_id):
	if not scene_path in defeated_enemy_registry:
		defeated_enemy_registry[scene_path] = []
	
	if not enemy_id in defeated_enemy_registry[scene_path]:
		defeated_enemy_registry[scene_path].append(enemy_id)
		print("Global: Registered enemy ID " + str(enemy_id) + " as defeated in " + scene_path)

# Function to mark an enemy as defeated
func mark_enemy_defeated(scene_path, enemy_id):
	if not defeated_enemies.has(scene_path):
		defeated_enemies[scene_path] = []
	
	if not enemy_id in defeated_enemies[scene_path]:
		defeated_enemies[scene_path].append(enemy_id)

# Function to check if an enemy is defeated
func is_enemy_defeated(scene_path, enemy_id):
	if not defeated_enemies.has(scene_path):
		return false
	
	return enemy_id in defeated_enemies[scene_path]
