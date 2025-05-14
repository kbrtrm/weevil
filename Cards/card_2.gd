# card_2.gd
extends Node2D

const CARD_SIZE = Vector2(90, 124)

@export var card_cost: int = 1
@export var card_name: String = ""
@export_multiline var card_desc: String = ""
@export var card_art: Texture2D = null

# References to nodes
var cost_label: Label
var name_label: Label
var description_label: RichTextLabel
var art_texture: TextureRect

# Drag and drop state
var draggable = true
var being_dragged = false
var original_position = Vector2.ZERO
var original_rotation = 0.0
var original_z_index = 0
var drag_offset = Vector2.ZERO

@onready var hover_highlight = $Panel/HoverHighlight

# Called when the node enters the scene tree
func _ready() -> void:
	center_pivot()
	
	# Get references to nodes
	cost_label = find_child("Cost")
	name_label = find_child("Name")
	description_label = find_child("RichTextLabel")
	art_texture = find_child("CardArt")
	
	# Set properties
	if cost_label:
		cost_label.text = str(card_cost)
	if name_label:
		name_label.text = card_name
	if description_label:
		description_label.text = card_desc
	if art_texture and card_art:
		art_texture.texture = card_art
	
	# Make sure Area2D is pickable
	var area = $Panel/Area2D
	if area:
		area.input_pickable = true

# Center the pivot point
func center_pivot():
	var half_size = CARD_SIZE / 2
	for child in get_children():
		child.position -= half_size

# Hover effect
func set_highlight(state: bool):
	if hover_highlight:
		hover_highlight.visible = state

# Called when mouse enters the card
func _on_area_2d_mouse_entered():
	# Only highlight if not currently dragging
	if not being_dragged:
		set_highlight(true)
		
		# Notify hand about hover
		var hand = get_parent()
		if hand and hand.has_method("on_card_hovered"):
			hand.on_card_hovered(self)

# Called when mouse exits the card
func _on_area_2d_mouse_exited():
	# Only turn off highlight if not being dragged
	if not being_dragged:
		set_highlight(false)
		
		# Notify hand about hover end
		var hand = get_parent()
		if hand and hand.has_method("on_card_unhovered"):
			hand.on_card_unhovered(self)

# Start dragging the card
func start_drag():
	if not draggable:
		return
		
	# Store original state
	original_position = global_position
	original_rotation = rotation
	original_z_index = z_index
	
	# Set up dragging state
	being_dragged = true
	z_index = 1000
	drag_offset = get_global_mouse_position() - global_position
	
	# Show highlight during drag
	set_highlight(true)
	
	# Notify hand about drag start
	var hand = get_parent()
	if hand and hand.has_method("on_card_drag_started"):
		hand.on_card_drag_started(self)

# Stop dragging and handle drop
func end_drag():
	being_dragged = false
	
	# Notify hand about drag end
	var hand = get_parent()
	if hand and hand.has_method("on_card_drag_ended"):
		hand.on_card_drag_ended(self, get_global_mouse_position())
	else:
		# If no handler, just return to original position
		global_position = original_position
		rotation = original_rotation
		z_index = original_z_index
		set_highlight(false)

# Update position while dragging
func _process(delta):
	if being_dragged:
		global_position = get_global_mouse_position() - drag_offset
		rotation_degrees = 0  # Keep card upright while dragging

# Card effect when played
func play_effect():
	print("Playing card: ", card_name)
	# Implement specific card effects here
