extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
		# Find the camera
	var camera = $PlayerFollowCamera  # Adjust the path as needed
	
	# Set limits based on your scene's needs
	if camera:
		camera.set_limits(0, 0, 1000, 600)  # Example values


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
