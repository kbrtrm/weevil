# DeckViewer.gd
extends Node2D

# Constants for card display
const CARD_WIDTH = 90
const CARD_HEIGHT = 124
const DEFAULT_CARD_SCALE = 1.0
const DEFAULT_SPACING = 10
const DEFAULT_GRID_WIDTH = 5

# Card scene reference
const CardScene = preload("res://Cards/Card2.tscn")

# Signals
signal card_clicked(card_data)
signal viewer_closed()

# Node references
var scroll_container: Node2D
var title_label: Label
var background: ColorRect

# State
var current_deck = []
var view_mode = "grid"  # "grid" or "list"

# Called when the node enters the scene tree for the first time.
func _ready():
	# Create the background panel
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(background)
	
	# Add title
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	
	# Create container for cards
	scroll_container = Node2D.new()
	add_child(scroll_container)
	
	# Connect background click to close
	background.gui_input.connect(_on_background_gui_input)
	
	# Hide initially - will be shown when display_deck is called
	visible = false

# Display a deck of cards in a grid
func display_deck(deck_data, title_text="Deck Viewer", grid_width=DEFAULT_GRID_WIDTH, 
				 card_scale=DEFAULT_CARD_SCALE, spacing=DEFAULT_SPACING):
	# Store deck data for reference
	current_deck = deck_data
	
	# Update title
	title_label.text = title_text
	
	# Resize background to fit the screen
	var screen_size = get_viewport_rect().size
	background.size = screen_size
	background.position = -screen_size / 2
	
	# Position title at the top
	title_label.position = Vector2(-150, -screen_size.y/2 + 20)
	title_label.size = Vector2(300, 30)
	title_label.add_theme_font_size_override('font_size', 8)
	
	# Clear any existing cards
	for child in scroll_container.get_children():
		scroll_container.remove_child(child)
		child.queue_free()
	
	# Generate grid layout
	var grid_size = _create_card_grid(deck_data, grid_width, card_scale, spacing)
	
	# Position the grid
	scroll_container.position = Vector2(-grid_size.x/2, -grid_size.y/2 + 70)
	
	# Add close button
	var close_button = Button.new()
	close_button.text = "Close"
	close_button.position = Vector2(0,0)
	close_button.add_theme_font_size_override('font_size', 8)
	
	#add_child(close_button)
	close_button.pressed.connect(_on_close_pressed)
	
	# Show the viewer
	visible = true
	
	return grid_size

# Create the grid of cards
func _create_card_grid(deck_data, grid_width, card_scale, spacing):
	# Calculate grid positions
	var grid_positions = []
	var card_size = Vector2(CARD_WIDTH, CARD_HEIGHT) * card_scale
	var row_count = ceil(float(deck_data.size()) / grid_width)
	
	# Generate all grid positions
	for row in range(row_count):
		for col in range(grid_width):
			var index = row * grid_width + col
			if index >= deck_data.size():
				break
				
			var x_pos = col * (card_size.x + spacing)
			var y_pos = row * (card_size.y + spacing)
			grid_positions.append(Vector2(x_pos, y_pos))
	
	# Create cards and place them in the grid
	for i in range(deck_data.size()):
		var card_data = deck_data[i]
		var grid_pos = grid_positions[i]
		
		# Create card instance
		var card = CardScene.instantiate()
		
		# Set card properties
		card.card_name = card_data.name
		card.card_cost = card_data.cost if "cost" in card_data else 1
		
		# Handle different property names for description
		if "description" in card_data:
			card.card_desc = card_data.description
		elif "desc" in card_data:
			card.card_desc = card_data.desc
		else:
			card.card_desc = "No description available"
		
		# Handle different property names for artwork
		if "artwork_path" in card_data and card_data.artwork_path:
			card.card_art = load(card_data.artwork_path)
		elif "art" in card_data and card_data.art:
			card.card_art = load(card_data.art)
		
		# Add to container and position
		scroll_container.add_child(card)
		card.position = grid_pos
		card.scale = Vector2(card_scale, card_scale)
		card.rotation_degrees = 0  # Cards are flat in the grid
		
		# Store card data for callback
		card.set_meta("card_data", card_data)
		
		# Add click detection
		_make_card_clickable(card, card_size)
	
	# Return the total size of the grid
	var total_width = min(deck_data.size(), grid_width) * (card_size.x + spacing) - spacing
	var total_height = row_count * (card_size.y + spacing) - spacing
	return Vector2(total_width, total_height)

# Make a card clickable
func _make_card_clickable(card, card_size):
	# Check if card already has ClickArea
	var click_area = card.get_node_or_null("ClickArea")
	
	# Create ClickArea if it doesn't exist
	if not click_area:
		click_area = Area2D.new()
		click_area.name = "ClickArea"
		card.add_child(click_area)
		
		var collision = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = card_size
		collision.shape = shape
		collision.position = Vector2(card_size.x/2, card_size.y/2)  # Center the collision shape
		click_area.add_child(collision)
	
	# Connect the input event (using a unique function name to avoid conflicts)
	var callable = Callable(self, "_on_card_clicked").bind(card)
	click_area.input_event.connect(callable)

# Handle card click
func _on_card_clicked(viewport, event, shape_idx, card):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var card_data = card.get_meta("card_data")
		emit_signal("card_clicked", card_data)

# Handle background input
func _on_background_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		close()

# Handle close button press
func _on_close_pressed():
	close()

# Close the viewer
func close():
	visible = false
	emit_signal("viewer_closed")
	
	# Clean up any extra buttons
	for child in get_children():
		if child is Button:
			child.queue_free()

# Static methods for creating deck viewers

# Create a deck viewer and add it to the specified parent
static func create_viewer(parent_node):
	var viewer = preload("res://Cards/DeckViewer.tscn").instantiate()
	parent_node.add_child(viewer)
	
	# Position at center of screen
	var screen_size = parent_node.get_viewport_rect().size
	viewer.position = Vector2(screen_size.x / 2, screen_size.y / 2)
	
	return viewer

# Quick method to show a deck in a new viewer
static func show_deck(parent_node, deck_data, title="Deck Viewer"):
	var viewer = create_viewer(parent_node)
	viewer.display_deck(deck_data, title)
	return viewer
