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
var transition_screen_position = Vector2.ZERO

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
	
	print("Global: Saving overworld state")
	print("Global: Scene path: " + previous_scene_path)
	
	# Find player by group to be more reliable
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_position = player.global_position
		print("Global: Saved player position: " + str(player_position))
		
		# Store player properties directly through the player's method
		if player.has_method("store_properties_to_global"):
			player.store_properties_to_global()
		else:
			print("Global: Warning - Player doesn't have store_properties_to_global method!")
	else:
		push_error("Global: Failed to find player when saving overworld state!")

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

# Enhanced setup_returned_world in Global.gd
func setup_returned_world(battle_won):
	print("Global.setup_returned_world called with battle_won = " + str(battle_won))
	
	# Find the player by group
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Restore player position
		player.global_position = player_position
		print("Global: Restored player position: " + str(player_position))
		
		# IMPORTANT: Reset player state to MOVE
		if "state" in player:
			player.state = player.MOVE  # Reset to MOVE state
			print("Global: Reset player state to MOVE")
		
		# Reset velocity to zero
		if "velocity" in player:
			player.velocity = Vector2.ZERO
			print("Global: Reset player velocity to zero")
	else:
		print("Global: Player not found when setting up returned world!")
	
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

# Add this function to Global.gd or replace the existing one
func handle_player_spawn():
	print("Global.handle_player_spawn called! next_spawn_point = '" + next_spawn_point + "'")
	
	if next_spawn_point.is_empty():
		# Check if we have a fallback in scene_transition_data
		if scene_transition_data.has("target_spawn"):
			next_spawn_point = scene_transition_data["target_spawn"]
			print("Global: Using fallback spawn point from transition data: " + next_spawn_point)
		else:
			print("Global: No spawn point specified, using default")
			return false
		
	print("Global: Looking for spawn point: '" + next_spawn_point + "'")
	
	# Get all spawn points right away
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	print("Global: Found " + str(spawn_points.size()) + " spawn points")
	
	# Directly teleport player to spawn point if found
	var found_spawn = false
	for spawn in spawn_points:
		print("Global: Checking spawn point '" + spawn.spawn_point_name + "' against target '" + next_spawn_point + "'")
		
		if spawn.spawn_point_name == next_spawn_point:
			var player = get_tree().get_first_node_in_group("player")
			if player:
				print("Global: Found matching spawn point at " + str(spawn.global_position))
				print("Global: Moving player from " + str(player.global_position) + " to " + str(spawn.global_position))
				
				# Directly teleport player to spawn point
				player.global_position = spawn.global_position
				
				# Apply any adjustments from the spawn point
				if "adjust_position" in spawn and spawn.adjust_position != Vector2.ZERO:
					player.global_position += spawn.adjust_position
				
				# Set facing direction if applicable
				if "facing_direction" in player and "spawn_direction" in spawn and spawn.spawn_direction != Vector2.ZERO:
					player.facing_direction = spawn.spawn_direction
				
				print("Global: Final player position: " + str(player.global_position))
				found_spawn = true
				break
			else:
				print("Global: ERROR - Player not found!")
	
	# If spawn point wasn't found immediately, try again after a short delay
	if not found_spawn:
		print("Global: Spawn point not found immediately, will try again after delay")
		get_tree().create_timer(0.2).timeout.connect(func():
			# Try again with delay
			var spawn_points_retry = get_tree().get_nodes_in_group("spawn_points")
			print("Global: RETRY - Found " + str(spawn_points_retry.size()) + " spawn points")
			
			for spawn in spawn_points_retry:
				print("Global: RETRY - Checking spawn point '" + spawn.spawn_point_name + "' against target '" + next_spawn_point + "'")
				
				if spawn.spawn_point_name == next_spawn_point:
					var player = get_tree().get_first_node_in_group("player")
					if player:
						print("Global: RETRY - Found matching spawn point at " + str(spawn.global_position))
						print("Global: RETRY - Moving player from " + str(player.global_position) + " to " + str(spawn.global_position))
						
						# Directly teleport player to spawn point
						player.global_position = spawn.global_position
						
						# Apply any adjustments
						if "adjust_position" in spawn and spawn.adjust_position != Vector2.ZERO:
							player.global_position += spawn.adjust_position
						
						print("Global: RETRY - Final player position: " + str(player.global_position))
						break
					else:
						print("Global: RETRY - ERROR - Player not found!")
		)
	
	# Clear spawn point name after using it
	next_spawn_point = ""
	return found_spawn

# Add this to Global.gd
func _notification(what):
	if what == NOTIFICATION_READY:
		print("Global: NOTIFICATION_READY")
	elif what == NOTIFICATION_PREDELETE:
		print("Global: NOTIFICATION_PREDELETE")
	elif what == NOTIFICATION_POST_ENTER_TREE:
		print("Global: NOTIFICATION_POST_ENTER_TREE")
	elif what == NOTIFICATION_ENTER_TREE:
		print("Global: NOTIFICATION_ENTER_TREE")
	elif what == NOTIFICATION_EXIT_TREE:
		print("Global: NOTIFICATION_EXIT_TREE")
	elif what == NOTIFICATION_PARENTED:
		print("Global: NOTIFICATION_PARENTED")
	elif what == NOTIFICATION_UNPARENTED:
		print("Global: NOTIFICATION_UNPARENTED")
	elif what == NOTIFICATION_PROCESS:
		# Skip this frequent notification to avoid log spam
		pass
	elif what == NOTIFICATION_PHYSICS_PROCESS:
		# Skip this frequent notification to avoid log spam
		pass
	elif what == NOTIFICATION_SCENE_INSTANTIATED:
		print("Global: NOTIFICATION_INSTANCED")
	else:
		print("Global: Unknown notification: " + str(what))
		
	# If this is a potential scene change notification
	if what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_POST_ENTER_TREE:
		print("Global: Checking next_spawn_point = '" + next_spawn_point + "'")
		
		# Wait a bit for all nodes to load properly
		call_deferred("check_nodes_after_scene_change")
		
func check_nodes_after_scene_change():
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("Global: Checking nodes after scene change")
	
	# Check for spawn points
	var spawn_points = get_tree().get_nodes_in_group("spawn_points")
	print("Global: Found " + str(spawn_points.size()) + " spawn points")
	
	for point in spawn_points:
		print("Global: Spawn point '" + point.spawn_point_name + "' at " + str(point.global_position))
	
	# Check for player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		print("Global: Player found at " + str(player.global_position))
	else:
		print("Global: Player not found!")
