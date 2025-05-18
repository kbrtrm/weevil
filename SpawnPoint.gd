# SpawnPoint.gd
extends Marker2D

@export var spawn_point_name: String = ""  # Should match target spawn_point_name in TransitionZone
@export var spawn_direction: Vector2 = Vector2.DOWN  # Direction player will face
@export var adjust_position: Vector2 = Vector2.ZERO  # Fine-tune spawn position

func _ready():
	# Register with spawn point system
	add_to_group("spawn_points")
	
	# Validate configuration
	if spawn_point_name.is_empty():
		push_warning("SpawnPoint has no name set!")
	else:
		print("spawned")
