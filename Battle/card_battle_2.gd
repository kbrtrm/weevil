extends Control

@onready var handLine = $Line2D
@onready var handLineContainer = $HBoxContainer/Panel/VBoxContainer/MarginContainer2/VBoxContainer/MarginContainer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in 4:		
		var dummyRect = ColorRect.new()
		dummyRect.size = Vector2(80,112)
		dummyRect.color = Color.AQUAMARINE
		dummyRect.position = handLine.global_position + Vector2(i*90, 0)
		add_child(dummyRect)
	print(handLine.position)
	print(handLineContainer.position)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
