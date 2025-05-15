# CardDatabase.gd
extends Node

# Store loaded card data
var cards = {}
var card_list = []

func _ready():
	# Load the card database
	load_card_database()

# Load the card database from JSON
func load_card_database():
	var file = FileAccess.open("res://Cards/card_database.json", FileAccess.READ)
	if not file:
		push_error("Failed to open card database file")
		return
	
	var json_text = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_error("JSON Parse Error: " + str(error))
		return
	
	var data = json.data
	if not data or not "cards" in data:
		push_error("Invalid card database format")
		return
	
	# Process the cards
	for card_data in data.cards:
		if "id" in card_data:
			# Store by ID for easy lookup
			cards[card_data.id] = card_data
			card_list.append(card_data)

# Get card data by ID
func get_card(card_id):
	if card_id in cards:
		return cards[card_id]
	
	push_error("Card ID not found: " + card_id)
	return null

# Get card data by name
func get_card_by_name(card_name):
	for card in card_list:
		if card.name == card_name:
			return card
	
	push_error("Card name not found: " + card_name)
	return null

# Get a list of all cards
func get_all_cards():
	return card_list

# Get a random card
func get_random_card():
	if card_list.size() > 0:
		return card_list[randi() % card_list.size()]
	return null

# Get cards of a specific rarity
func get_cards_by_rarity(rarity):
	var result = []
	for card in card_list:
		if card.rarity == rarity:
			result.append(card)
	return result

# Get cards of a specific type
func get_cards_by_type(type):
	var result = []
	for card in card_list:
		if card.type == type:
			result.append(card)
	return result
