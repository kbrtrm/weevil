extends Label

# Sway properties
@export var sway_amount: float = 4.0  # How far to sway in degrees
@export var sway_speed: float = 1.0   # How fast to sway
var time_elapsed: float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Center the pivot point so rotation happens around the center
	pivot_offset = size / 2

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update time
	time_elapsed += delta
	
	# Calculate sway using sine wave for smooth back-and-forth motion
	var sway_rotation = sin(time_elapsed * sway_speed) * sway_amount
	
	# Apply the sway rotation
	rotation_degrees = sway_rotation
