extends Node2D
class_name PassThruObject

@onready var animation = $AnimationPlayer
@onready var sprite = $Material
@export var wiggle = true
@export var texture = Texture2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	sprite.texture = texture
	choose_random_flip(sprite)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_wiggle_detect_body_entered(body: Node2D) -> void:
	if wiggle:
		animation.play("wiggle")

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
