extends Area2D

signal card_played(card)

func _ready():
	input_pickable = true
	add_to_group("drop_targets")
	
	# Make sure we have a collision shape
	if not has_node("CollisionShape2D"):
		push_error("DropTarget needs a CollisionShape2D!")
