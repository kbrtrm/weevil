extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed():
	# Optional: Get the button's global position to center the transition there
	var button_center = $Button.global_position + $Button.size / 2
	TransitionManager.change_scene("res://Scene1.tscn", button_center)
