extends Node

var deck = []
var deck_initialized = false
signal deck_initialized_signal

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
	print("Global: Adding card to deck: " + card_id)
	
	var card_db = get_node("/root/CardDatabase")
	if not card_db:
		push_error("CardDatabase not found!")
		return false
		
	var card_data = card_db.get_card(card_id)
	if card_data:
		# Create a copy of the card data for the deck
		var deck_card = card_data.duplicate(true)
		deck.append(deck_card)
		print("Global: Successfully added: " + card_data.name)
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
