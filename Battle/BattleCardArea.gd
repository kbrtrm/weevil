extends Control

@onready var card = preload("res://Battle/Card.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return true
	
func _drop_data(at_position: Vector2, data: Variant) -> void:
	print("dropped on board")
	var dropped_card = card.instantiate()
	dropped_card.cardName = data.cardName
	dropped_card.position = get_local_mouse_position()
	add_child(dropped_card)
	dropped_card.size = Vector2(80,112)
