# Global.gd - Modified to clean up enemy tracking

extends Node

var deck = []
var deck_initialized = false
signal deck_initialized_signal

var game_paused = false

# Battle system variables
var current_battle_enemies = []
var player_position = Vector2.ZERO
# With a more robust tracking system:
var previous_scene_path = ""  # Scene before battle
var current_scene_path = ""   # Current scene

var enemy_position = Vector2.ZERO
var enemy_instance_id = 0
var returning_from_battle = false

# Enemy tracking system - CONSOLIDATED APPROACH
var next_enemy_id = 100  # Counter for generating unique IDs
var current_enemy_id = -1  # ID of the enemy currently in battle
var defeated_enemies = {} # Dictionary to store defeated enemies by scene path and ID
var instance_id_to_unique_id = {}  # Maps Godot instance IDs to our unique enemy IDs

var player_properties = null  # Will be populated by the Player's store_properties_to_global function

# Room transition variables
var next_spawn_point = ""  # Name of spawn point to use in next scene
var scene_transition_data = {}  # Store data between scenes

func _ready():
	print("Global: _ready() called")
	
	# VERY IMPORTANT: Load game state first, before anything else
	print("Global: Loading game state...")
	load_game_state()
	print("Global: After loading, defeated_enemies = " + str(defeated_enemies))
	
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
	var card_db = get_node("/root/CardDatabase")
	if not card_db:
		push_error("CardDatabase not found!")
		return false
		
	var card_data = card_db.get_card(card_id)
	if card_data:
		# Create a copy of the card data for the deck
		var deck_card = card_data.duplicate(true)
		deck.append(deck_card)
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
	# Store current scene as the scene to return to after battle
	previous_scene_path = get_tree().current_scene.scene_file_path
	current_scene_path = previous_scene_path
	
	print("Global: Saved previous scene: " + previous_scene_path)
	
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
	print("Global: Will return to scene: " + previous_scene_path)
	
	# Set flag to prevent re-triggering battles immediately
	returning_from_battle = true
	
	# Pause all game movement
	set_game_paused(true)
	
	# Get the center position for the transition - use enemy_position for the center
	var center_position = enemy_position
	
	# Tell TransitionManager to handle the scene transition
	# Use the previous_scene_path instead of a hardcoded path
	TransitionManager.end_combat(center_position, previous_scene_path, battle_won)
	
	# Note: The rest of this function's original code will be handled by TransitionManager
	# TransitionManager will call our setup_returned_world function after the transition completes

# Enhanced setup_returned_world in Global.gd for better enemy handling
func setup_returned_world(battle_won):
	print("Global.setup_returned_world called with battle_won = " + str(battle_won))
	# Restore player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.global_position = player_position
		print("Global: Restored player position: " + str(player_position))
	
	# Note: We no longer mark the enemy as defeated here
	# This is now handled directly in BattleManager.end_battle
	
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
	print("Global: Generated new enemy ID: " + str(id))
	return id

# Modify the mark_enemy_defeated function for better debugging
func mark_enemy_defeated(scene_path, enemy_id):
	print("Global.mark_enemy_defeated called:")
	print("  - Scene path: " + scene_path) 
	print("  - Enemy ID: " + str(enemy_id))
	
	# Initialize the array if needed
	if not defeated_enemies.has(scene_path):
		defeated_enemies[scene_path] = []
	
	# Add the ID if not already there
	if not enemy_id in defeated_enemies[scene_path]:
		defeated_enemies[scene_path].append(enemy_id)
		print("Global: Enemy " + str(enemy_id) + " marked as defeated in " + scene_path)
		
		# Print the current state of the defeated_enemies dictionary
		print("Current defeated_enemies state:")
		for path in defeated_enemies:
			print("  Scene: " + path)
			print("  IDs: " + str(defeated_enemies[path]))
		
		# Save game state
		save_game_state()
	else:
		print("Global: Enemy " + str(enemy_id) + " was already marked as defeated")

# Enhanced check for defeated enemies with better debugging
func is_enemy_defeated(scene_path, enemy_id):
	print("Global.is_enemy_defeated: Checking if enemy " + str(enemy_id) + " is defeated in " + scene_path)
	
	# Debug the current state
	print("  Current defeated_enemies content:")
	for path in defeated_enemies:
		print("    Scene: " + path)
		print("    IDs: " + str(defeated_enemies[path]))
	
	# Check if scene path exists
	if not defeated_enemies.has(scene_path):
		print("  Result: Scene path not found")
		return false
	
	# Check if ID is in the array for that scene
	var id_list = defeated_enemies[scene_path]
	if id_list is Array and enemy_id in id_list:
		print("  Result: Enemy " + str(enemy_id) + " IS in the defeated list")
		return true
	else:
		print("  Result: Enemy " + str(enemy_id) + " is NOT in the defeated list")
		return false

# Ensure save/load game state works properly
func save_game_state():
	# Create a dictionary to save
	var save_dict = {
		"defeated_enemies": defeated_enemies,
		"next_enemy_id": next_enemy_id
	}
	
	# Save to file
	var save_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if save_file:
		save_file.store_var(save_dict)
		save_file.close()
		print("Global: Game state saved successfully")
		print("Global: Saved " + str(defeated_enemies.size()) + " scene paths with defeated enemies")
	else:
		print("Global: Failed to save game state - " + str(FileAccess.get_open_error()))

# Enhanced load game state with better error handling
func load_game_state():
	if FileAccess.file_exists("user://savegame.save"):
		var save_file = FileAccess.open("user://savegame.save", FileAccess.READ)
		if save_file:
			var json_error = OK
			
			# Safely load the save data
			var save_dict = save_file.get_var(json_error)
			save_file.close()
			
			if json_error != OK:
				print("Global: Error loading save file: " + str(json_error))
				return
			
			# Restore saved data
			if save_dict is Dictionary:
				if save_dict.has("defeated_enemies"):
					defeated_enemies = save_dict.defeated_enemies
				if save_dict.has("next_enemy_id"):
					next_enemy_id = save_dict.next_enemy_id
					
				print("Global: Game state loaded successfully")
				print("Global: Loaded " + str(defeated_enemies.size()) + " scene paths with defeated enemies")
			else:
				print("Global: Save file has invalid format")
		else:
			print("Global: Could not open save file - " + str(FileAccess.get_open_error()))
	else:
		print("Global: No save file found")
		
	if defeated_enemies.size() > 0:
		print("Global: Loaded defeated enemies for " + str(defeated_enemies.size()) + " scenes")
		for scene in defeated_enemies:
			print("  Scene: " + scene)
			print("  Defeated enemies: " + str(defeated_enemies[scene]))
	else:
		print("Global: No defeated enemies loaded (empty list)")

# Get all defeated enemies for a scene
func get_defeated_enemies_for_scene(scene_path: String) -> Array:
	if defeated_enemies.has(scene_path):
		return defeated_enemies[scene_path]
	return []

# Check if any enemies are defeated in a scene
func has_defeated_enemies(scene_path: String) -> bool:
	return defeated_enemies.has(scene_path) and defeated_enemies[scene_path].size() > 0

# Get total count of defeated enemies
func get_total_defeated_enemies() -> int:
	var count = 0
	for scene in defeated_enemies:
		count += defeated_enemies[scene].size()
	return count

# Store player state for transitions
func store_player_state_for_transition():
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Store basic information
		scene_transition_data["velocity"] = player.velocity if "velocity" in player else Vector2.ZERO
		scene_transition_data["state"] = player.state if "state" in player else 0
		
		# Store other data as needed
		# Call player's own storage method if available
		if player.has_method("store_transition_data"):
			var player_data = player.store_transition_data()
			for key in player_data:
				scene_transition_data[key] = player_data[key]

# Restore player state after transition
func restore_player_state_after_transition():
	var player = get_tree().get_first_node_in_group("player")
	if player and scene_transition_data.size() > 0:
		# Restore basic information
		if "velocity" in scene_transition_data and "velocity" in player:
			player.velocity = scene_transition_data["velocity"]
		if "state" in scene_transition_data and "state" in player:
			player.state = scene_transition_data["state"]
			
		# Call player's own restore method if available
		if player.has_method("restore_transition_data"):
			player.restore_transition_data(scene_transition_data)
			
		# Clear transition data
		scene_transition_data.clear()

func handle_player_spawn():
	print("Global.handle_player_spawn called! next_spawn_point = '" + next_spawn_point + "'")
	
	if next_spawn_point.is_empty():
		print("Global: No spawn point specified, using default")
		return false
		
	print("Global: Looking for spawn point: " + next_spawn_point)
	
	# Wait a frame to make sure everything is loaded
	await get_tree().process_frame
	
	# Find the matching spawn point
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	print("Global: Found " + str(spawn_points.size()) + " spawn points")
	
	for spawn in spawn_points:
		print("Global: Found spawn point: '" + spawn.spawn_point_name + "' at position " + str(spawn.global_position))
		
		if spawn.spawn_point_name == next_spawn_point:
			# Position the player at this spawn point
			var player = get_tree().get_first_node_in_group("player")
			if player:
				print("Global: Found player at " + str(player.global_position))
				print("Global: Moving player to spawn point '" + next_spawn_point + "' at " + str(spawn.global_position))
				
				player.global_position = spawn.global_position + spawn.adjust_position
				
				print("Global: Player moved to " + str(player.global_position))
				
				# Set player facing direction if applicable
				if "facing_direction" in player and spawn.spawn_direction != Vector2.ZERO:
					player.facing_direction = spawn.spawn_direction
					
				# Restore player state
				restore_player_state_after_transition()
				
				# Clear spawn point
				next_spawn_point = ""
				return true
			else:
				print("Global: ERROR - Player not found!")
				
	print("Global: WARNING - Spawn point '" + next_spawn_point + "' not found!")
	next_spawn_point = ""
	return false
