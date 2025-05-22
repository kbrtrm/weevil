# Cig.gd example
extends "res://Enemies/BaseEnemy.gd"

func _ready():
	# Set Cig-specific properties
	enemy_data = {
		"name": "Ciggy", 
		"max_health": 12,
		"base_damage": 5
	}
	
	# Customize movement for Cig - much more noticeable now
	MAX_SPEED = 40.0  # Fast speed
	ACCEL = 10.0       # Quick acceleration
	FRICTION = 8.0     # Less friction for more sliding
	
	# Call the parent _ready function
	super._ready()
