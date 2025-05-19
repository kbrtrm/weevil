# SpawnPoint.gd
extends Marker2D

@export var spawn_point_name: String = ""  # Should match target spawn_point_name in TransitionZone
@export var spawn_direction: Vector2 = Vector2.DOWN  # Direction player will face
@export var adjust_position: Vector2 = Vector2.ZERO  # Fine-tune spawn position

func _ready():
	add_to_group("spawn_points", true) # Force priority setting
	call_deferred("notify_global_ready")
	print("SpawnPoint: '" + spawn_point_name + "' registered at " + str(global_position))

# Deferred call to ensure proper timing
func notify_global_ready():
	print("SpawnPoint '" + spawn_point_name + "' notifying Global it's ready")
	# This ensures the spawn point is fully registered before Global tries to find it
