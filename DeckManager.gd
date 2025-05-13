# DeckManager.gd
extends Node

var deck = []
var discard_pile = []

signal card_drawn(card_id)
signal deck_empty
signal deck_shuffled

func initialize_deck(card_ids: Array):
	deck = card_ids.duplicate()
	discard_pile.clear()
	
	print("Deck initialized with " + str(deck.size()) + " cards")

func shuffle():
	if deck.size() > 0:
		deck.shuffle()
		emit_signal("deck_shuffled")
		print("Deck shuffled, cards: " + str(deck.size()))

func draw_card() -> String:
	if deck.size() == 0:
		if discard_pile.size() > 0:
			# Auto-shuffle discard into deck
			deck = discard_pile.duplicate()
			discard_pile.clear()
			shuffle()
		else:
			emit_signal("deck_empty")
			print("Deck and discard empty, cannot draw")
			return ""
	
	var card_id = deck.pop_front()
	emit_signal("card_drawn", card_id)
	return card_id

func draw_cards(count: int) -> Array:
	var cards = []
	for i in range(count):
		var card = draw_card()
		if card != "":
			cards.append(card)
		else:
			break
	return cards

func add_to_discard(card_id: String):
	discard_pile.append(card_id)

func get_deck_size() -> int:
	return deck.size()

func get_discard_size() -> int:
	return discard_pile.size()
