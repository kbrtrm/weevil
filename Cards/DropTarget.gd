# DropTarget.gd
extends Area2D

signal card_played(card)

func _ready():
	input_pickable = true
	add_to_group("drop_targets")

# These methods are part of Godot's drag and drop system
func can_drop_data(position, data):
	# Check if the data being dropped is from a card
	return data is Dictionary and data.has("card")

func drop_data(position, data):
	# Card was dropped on the target
	var card = data.card
	
	# Emit the signal
	card_played.emit(card)
