# CardDatabase.gd
extends Node

var cards = {}

func _ready():
	load_card_database()

func load_card_database():
	var file = FileAccess.open("res://Cards/card_database.json", FileAccess.READ)
	if file:
		var json_text = file.get_as_text()
		file.close()
		
		var json = JSON.parse_string(json_text)
		if json and json.has("cards"):
			for card_data in json.cards:
				cards[card_data.id] = card_data
			print("Card Database: Loaded " + str(cards.size()) + " cards")
		else:
			print("Error parsing card database JSON")
	else:
		print("Error: Could not open card database file")

func get_card(id: String) -> Dictionary:
	if cards.has(id):
		return cards[id]
	return {}

func get_all_cards() -> Dictionary:
	return cards.duplicate()

func get_cards_by_type(type_id: int) -> Array:
	var result = []
	for id in cards:
		if cards[id].type == type_id:
			result.append(cards[id])
	return result
