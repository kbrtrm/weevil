# SpawnPoint.gd
extends Marker2D

@export var spawn_point_name: String = ""  # Should match target spawn_point_name in TransitionZone
@export var spawn_direction: Vector2 = Vector2.DOWN  # Direction player will face
@export var adjust_position: Vector2 = Vector2.ZERO  # Fine-tune spawn position

func _ready():
	# Register with spawn point system immediately
	add_to_group("spawn_points")
	
	# Validate configuration
	if spawn_point_name.is_empty():
		push_warning("SpawnPoint has no name set!")
	else:
		print("SpawnPoint: '" + spawn_point_name + "' registered at " + str(global_position))
		
	# Notify Global that we're ready
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		# Make sure the spawn point is registered before the player tries to use it
		call_deferred("notify_global_ready")

# Deferred call to ensure proper timing
func notify_global_ready():
	print("SpawnPoint '" + spawn_point_name + "' notifying Global it's ready")
	# This ensures the spawn point is fully registered before Global tries to find it
