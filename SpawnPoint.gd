# SpawnPoint.gd - simplified version
extends Marker2D

@export var spawn_point_name: String = ""  # Should match target spawn_point_name in TransitionZone
@export var spawn_direction: Vector2 = Vector2.DOWN  # Direction player will face
@export var adjust_position: Vector2 = Vector2.ZERO  # Fine-tune spawn position

func _ready():
	# Check for empty name and set based on scene
	if spawn_point_name.is_empty():
		var scene_path = get_tree().current_scene.scene_file_path
		if scene_path == "res://testing_ground.tscn":
			spawn_point_name = "auto_from_2"
		elif scene_path == "res://testing_ground_2.tscn":
			spawn_point_name = "auto_tg2"
			
	print("SpawnPoint: '" + spawn_point_name + "' registered at " + str(global_position))
	add_to_group("spawn_points", true)
	call_deferred("check_for_player")

func check_for_player():
	# Check if Global is looking for this spawn point
	if Engine.has_singleton("Global"):
		var global_singleton = Engine.get_singleton("Global")
		if global_singleton.next_spawn_point == spawn_point_name:
			# Try to reposition the player
			var player = get_tree().get_first_node_in_group("player")
			if player:
				player.global_position = global_position + adjust_position
				print("SpawnPoint: Moved player to " + str(player.global_position))
			else:
				# Try again later if player not found
				get_tree().create_timer(0.2).timeout.connect(func():
					var player_retry = get_tree().get_first_node_in_group("player")
					if player_retry:
						player_retry.global_position = global_position + adjust_position
						print("SpawnPoint: Moved player to " + str(player_retry.global_position))
				)
