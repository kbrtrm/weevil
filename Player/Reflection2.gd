extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready():
	set_transparency(0.5) # Set transparency to 50%


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


# Set the transparency of the sprite
func set_transparency(alpha: float):
	var current_modulate = modulate
	current_modulate.a = alpha
	modulate = current_modulate
