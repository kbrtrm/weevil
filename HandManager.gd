# HandManager.gd
extends Control

@export var card_scene: PackedScene
@export var cards_container_path: NodePath

var hand = []
@onready var cards_container = get_node(cards_container_path)

# Spacing properties
@export var card_spacing: float = 80
@export var card_overlap: float = 30
@export var max_hand_width: float = 800
@export var card_hover_raise: float = -50

signal card_played(card)

func _ready():
	print("HandManager ready")
	print("CardScene assigned: ", card_scene != null)
	print("CardsContainer: ", cards_container)
	
	if cards_container:
		print("CardsContainer rect: ", cards_container.get_rect())
		# Ensure container has enough space
		cards_container.custom_minimum_size = Vector2(1000, 200)
		# Use size flags to ensure it expands properly
		cards_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards_container.size_flags_vertical = Control.SIZE_EXPAND_FILL

func add_card(card_id: String):
	print("HandManager.add_card called with ID: ", card_id)
	
	if hand.size() >= 10:  # Typical max hand size
		print("Hand is full")
		return null
		
	var card_data = CardDatabase.get_card(card_id)
	print("Card data retrieved: ", card_data)
	
	if card_data.size() == 0:
		print("Card ID not found: ", card_id)
		return null
	
	if card_scene == null:
		print("ERROR: card_scene is null! Make sure to assign it in the Inspector")
		return null
	
	print("Instantiating card scene")
	var card_instance = card_scene.instantiate()
	
	if card_instance == null:
		print("ERROR: Failed to instantiate card scene")
		return null
	
	print("Adding card to container")
	cards_container.add_child(card_instance)
	
	print("Loading card data")
	if card_instance.has_method("load_data"):
		card_instance.load_data(card_data)
	else:
		print("ERROR: Card instance doesn't have load_data method")
		card_instance.queue_free()
		return null
	
	print("Card added to hand: ", card_instance.card_name if "card_name" in card_instance else "Unknown")
	hand.append(card_instance)
	
	print("Arranging cards")
	arrange_cards()
	
	card_instance.visible = true
	card_instance.z_index = hand.size()
	
	return card_instance

func remove_card(card):
	hand.erase(card)
	card.queue_free()
	arrange_cards()

func clear_hand():
	for card in hand:
		card.queue_free()
	hand.clear()

func draw_from_deck(deck: Array, count: int = 1):
	print("HandManager.draw_from_deck called with deck: ", deck)
	var cards_drawn = []
	
	for i in range(min(count, deck.size())):
		if deck.size() > 0:
			var card_id = deck.pop_front()
			print("Drawing card ID: ", card_id)
			var card = add_card(card_id)
			if card:
				cards_drawn.append(card)
				print("Card added successfully")
			else:
				print("Failed to add card")
	
	print("Total cards drawn: ", cards_drawn.size())
	return cards_drawn

func arrange_cards():
	# Skip if no cards
	if hand.size() == 0:
		return
	
	# Get the actual viewport size instead of container size
	var viewport_size = get_viewport_rect().size
	print("Viewport size: ", viewport_size)
	
	# Calculate spacing based on hand size
	var card_width = 120  # Adjust based on your actual card width
	var total_width = min(viewport_size.x * 0.8, hand.size() * card_width * 1.2)
	var spacing = total_width / max(1, hand.size())
	
	# Calculate starting position (centered)
	var start_x = (viewport_size.x - total_width) / 2 + spacing / 2
	
	print("Viewport width: ", viewport_size.x)
	print("Total cards width: ", total_width)
	print("Starting X: ", start_x)
	
	for i in range(hand.size()):
		var card = hand[i]
		# Position cards lower in the view
		var target_pos = Vector2(start_x + i * spacing, viewport_size.y * 0.7)
		print("Positioning card ", i, " at ", target_pos)
		
		# Set position directly first
		card.position = target_pos
		
		# Create animation tween
		var tween = create_tween()
		tween.tween_property(card, "position", target_pos, 0.3).set_ease(Tween.EASE_OUT)
		
		# Ensure card is visible
		card.visible = true
		card.modulate = Color(1, 1, 1)  # Make fully opaque
		card.z_index = 100 + i  # Ensure proper z-ordering

func _on_card_mouse_entered(card):
	# Raise card when hovered
	var tween = create_tween()
	tween.tween_property(card, "position:y", card_hover_raise, 0.2).set_ease(Tween.EASE_OUT)

func _on_card_mouse_exited(card):
	# Return card to original position
	var tween = create_tween()
	tween.tween_property(card, "position:y", 0, 0.2).set_ease(Tween.EASE_IN)

func _on_card_gui_input(event, card):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("card_played", card)
