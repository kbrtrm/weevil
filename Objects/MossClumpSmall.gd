extends Node2D

@onready var wiggleAnimation = $AnimationPlayer
@onready var mossMaterial = $MossClumpMaterial
# Called when the node enters the scene tree for the first time.


func _ready():
	pass
#	choose_random_flip(mossMaterial)


func _on_area_2d_body_entered(_body):
	wiggleAnimation.play("wiggle")

func choose_random_flip(sprite):
	# Generate a random integer between 0 and 1
	var random_choice = randi() % 2

	# Print the randomly chosen option
	match random_choice:
		0:
			sprite.flip_h = true
			# Call a function or perform actions for Option A
		1:
			pass
			# Call a function or perform actions for Option B
