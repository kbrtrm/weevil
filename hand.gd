@tool

extends Control

func _ready():
	# Method 1: Using preload (loads at compile time)
	var card_scene = preload("res://Cards/Card.tscn")
	
	for i in range(5):
		var card_instance = card_scene.instantiate()
		card_instance.position = Vector2(114*i, 0)    
		add_child(card_instance) 
