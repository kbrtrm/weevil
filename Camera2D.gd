extends Camera2D

@onready var topLeft = $Limits/TopLeft
@onready var bottomRight = $Limits/BottomRight
@export var follow_speed = 5.0  # How quickly the camera follows the player

var player = null

func _ready():
	limit_top = topLeft.position.y
	limit_left = topLeft.position.x
	limit_bottom = bottomRight.position.y
	limit_right = bottomRight.position.x
	
	# Wait until tree is ready before finding player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("Camera: Found player at " + str(player.global_position))
	else:
		print("Camera: Player not found!")

func _process(delta):
	if player and is_instance_valid(player):
		# Smoothly move the camera toward the player
		global_position = global_position.lerp(player.global_position, follow_speed * delta)
