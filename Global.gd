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
		
	# 1 Gum
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

# Save overworld state before entering a battle
func save_overworld_state():
	# Save current scene
	current_scene_path = get_tree().current_scene.scene_file_path
	print("Global: Saved current scene: " + current_scene_path)
	
	# Save player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player_position = player.global_position
		print("Global: Saved player position: " + str(player_position))

# Return to overworld after battle
func return_to_overworld(battle_won = false):
	print("Global: Returning to overworld. Battle won: " + str(battle_won))
	
	# Set flag to prevent re-triggering battles immediately
	returning_from_battle = true
	
	# Pause all game movement
	set_game_paused(true)
	
	# Create transition
	var transition = load("res://Effects/BattleTransition.tscn").instantiate()
	get_tree().root.add_child(transition)
	
	# Fade to black
	transition.fade_out(0.5)
	await transition.transition_halfway
	
	# Load the previous scene while black
	print("Global: Changing back to overworld scene")
	get_tree().change_scene_to_file(current_scene_path)
	
	# Wait for scene to initialize
	await transition.wait(0.1)
	
	# Make sure transition is still valid
	if is_instance_valid(transition) and transition.is_inside_tree():
		print("Global: Transition still valid after scene change")
		
		# Restore player position
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = player_position
			print("Global: Restored player position: " + str(player_position))
		
		# If player won, remove the defeated enemy
		if battle_won:
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				var distance = enemy_position.distance_to(enemy.global_position)
				if distance < 50:
					print("Global: Removing enemy: " + enemy.name)
					enemy.queue_free()
					break
		
		# Fade in to show the overworld
		transition.fade_in(0.5)
		
		# Clean up when done
		await transition.transition_completed
		transition.queue_free()
	else:
		print("Global: ERROR: Transition is no longer valid after scene change!")
	
	# At the end:
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

#var deck = [
	#{
		#"name": "Penny",
		#"desc": "Apply 2 [color=yellow]spark[/color]. Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Cards/penny.png"
	#},
	#{
		#"name": "Penny",
		#"desc": "Apply 2 [color=yellow]spark[/color]. Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Cards/penny.png"
	#},
	#{
		#"name": "Wad of Gum",
		#"desc": "Apply 2 [color=pink]sticky[/color]. Deal 8 damage.",
		#"cost": 2,
		#"art": "res://Cards/gum.png"
	#},
	#{
		#"name": "Pebble",
		#"desc": "Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Images/stone1.png"
	#},
	#{
		#"name": "Pebble",
		#"desc": "Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Images/stone1.png"
	#},
	#{
		#"name": "Pebble",
		#"desc": "Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Images/stone1.png"
	#},
	#{
		#"name": "Pebble",
		#"desc": "Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Images/stone1.png"
	#},
	#{
		#"name": "Pebble",
		#"desc": "Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Images/stone1.png"
	#},
	#{
		#"name": "Pebble",
		#"desc": "Deal 6 damage.",
		#"cost": 1,
		#"art": "res://Images/stone1.png"
	#},
	#{
		#"name": "Paperclip",
		#"desc": "Apply 2 [color=skyblue]weak[/color]. Deal 4 damage.",
		#"cost": 0,
		#"art": "res://Cards/paperclip-big.png"
	#},
	#{
		#"name": "Paperclip",
		#"desc": "Apply 2 [color=skyblue]weak[/color]. Deal 4 damage.",
		#"cost": 0,
		#"art": "res://Cards/paperclip-big.png"
	#}
#]
