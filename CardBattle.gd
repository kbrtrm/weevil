extends Node2D

@onready var card = preload("res://Battle/Card.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var card_to_add = card.instantiate()
	card_to_add.cardName = "Pebble"
	card_to_add.cardDesc = "Deal 6 damage"
	card_to_add.global_position = Vector2(80,80)
	card_to_add.SlotL = true
	add_child(card_to_add)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

