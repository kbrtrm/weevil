extends Control

@export var cardName = ""
@export var cardCost = ""
@export var cardDesc = ""



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var nameLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/NameLabel
	var costLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CostLabel
	var descLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer3/DescLabel
	nameLabel.text = cardName
	costLabel.text = str(cardCost)
	descLabel.text = cardDesc
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
