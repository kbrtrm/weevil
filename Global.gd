extends Node

var deck = []

func _ready():
	# Wait for CardDatabase to load
	await get_tree().process_frame
	initialize_deck()

# Set up the player's starting deck
func initialize_deck():
	# Clear the deck
	deck.clear()
	
	# Add starter cards
	# 5 Pebbles
	for i in range(5):
		add_card_to_deck("pebble")
	
	# 3 Paperclips
	for i in range(3):
		add_card_to_deck("paperclip")
	
	# 3 Acorns (block)
	for i in range(3):
		add_card_to_deck("acorn")
	
	# 1 Penny (draw)
	add_card_to_deck("penny")
	
	# Shuffle the deck
	randomize()
	deck.shuffle()

# Add a card to the deck by ID
func add_card_to_deck(card_id):
	var card_data = CardDatabase.get_card(card_id)
	if card_data:
		# Create a copy of the card data for the deck
		var deck_card = card_data.duplicate(true)
		deck.append(deck_card)
	else:
		push_error("Failed to add card to deck, ID not found: " + card_id)

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
