extends Node2D

const CARD_SIZE =  Vector2(90, 124)

@export var card_cost: int = 1
@export var card_name: String = ""
@export_multiline var card_desc: String = ""
@export var card_art: Texture2D = null

# References to nodes
var cost_label: Label
var name_label: Label
var description_label: RichTextLabel
var art_texture: TextureRect

@onready var HoverHighlightRef = $Panel/HoverHighlight

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	center_pivot()
	# Get references to nodes (using find_child to be more robust)
	cost_label = find_child("Cost")
	name_label = find_child("Name")
	description_label = find_child("RichTextLabel")
	art_texture = find_child("CardArt")
	
	# Check if nodes exist before setting properties
	if cost_label:
		cost_label.text = str(card_cost)
	if name_label:
		name_label.text = card_name
	if description_label:
		description_label.text = card_desc
	if art_texture and card_art:
		art_texture.texture = card_art

# Function to center the pivot point
func center_pivot():
	# Calculate half the card size
	var half_size = CARD_SIZE / 2
	
	# Adjust the positions of all child nodes
	for child in get_children():
		child.position -= half_size

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _on_area_2d_mouse_entered() -> void:
	HoverHighlightRef.visible = true


func _on_area_2d_mouse_exited() -> void:
	HoverHighlightRef.visible = false
