# EnemiesManager.gd
extends Node

var current_scene_path = ""

func _ready():
	# Wait for the scene to fully load
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("EnemiesManager: Initialized and scanning for defeated enemies...")
	remove_defeated_enemies()
	
	# Connect to the TransitionManager signals if available
	if has_node("/root/TransitionManager"):
		var transition_manager = get_node("/root/TransitionManager")
		if transition_manager.has_signal("transition_completed"):
			transition_manager.transition_completed.connect(_on_transition_completed)
		if transition_manager.has_signal("combat_ended"):
			transition_manager.combat_ended.connect(_on_combat_ended)

func _process(_delta):
	# Skip checking if the game is paused
	if get_tree().paused:
		return
		
	# Check if scene has changed
	if is_instance_valid(get_tree().current_scene) and get_tree().current_scene.scene_file_path != current_scene_path:
		var old_path = current_scene_path
		current_scene_path = get_tree().current_scene.scene_file_path
		
		# Only log if we had a previous scene (not on initial load)
		if old_path != "":
			print("EnemiesManager: Scene changed from " + old_path + " to " + current_scene_path)
		else:
			print("EnemiesManager: Initial scene set to " + current_scene_path)
			
		# Only check for enemies if we're moving to a new scene (not initial load)
		if old_path != "":
			call_deferred("remove_defeated_enemies")

func _on_transition_completed():
	print("EnemiesManager: Scene transition completed")
	call_deferred("remove_defeated_enemies")
	
func _on_combat_ended():
	print("EnemiesManager: Combat ended")
	call_deferred("remove_defeated_enemies")

# Public function that can be called from anywhere to manually check
func force_check_defeated_enemies():
	print("EnemiesManager: Manual check for defeated enemies triggered")
	call_deferred("remove_defeated_enemies")

func remove_defeated_enemies():
	# CHANGE THIS LINE: Instead of checking for a singleton, directly try to get the node
	var global = get_node_or_null("/root/Global")
	
	if not global:
		print("EnemiesManager: No Global node found at /root/Global!")
		# DEBUGGING: Print all nodes at /root to help diagnose
		print("EnemiesManager: Nodes at /root: " + str(get_node("/root").get_children()))
		return
		
	var current_scene_path = get_tree().current_scene.scene_file_path
	
	# Skip if not in a game scene
	if current_scene_path == "":
		print("EnemiesManager: Not in a game scene, skipping enemy check")
		return
	
	print("EnemiesManager: Checking enemies in scene: " + current_scene_path)
	
	# First make sure we have a defeated enemies list for this scene
	if not "defeated_enemies" in global or not global.defeated_enemies.has(current_scene_path) or global.defeated_enemies[current_scene_path].size() == 0:
		print("EnemiesManager: No defeated enemies recorded for this scene")
		return
	
	# Get all enemy nodes in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	print("EnemiesManager: Found " + str(enemies.size()) + " enemies in scene")
	
	var removed_count = 0
	
	# Check each enemy
	for enemy in enemies:
		# Skip enemies without the proper property
		if not "unique_id" in enemy:
			print("EnemiesManager: Enemy doesn't have unique_id property, skipping")
			continue
			
		var enemy_id = enemy.unique_id
		
		# Force enemies to initialize their ID if not set
		if enemy_id == -1 and enemy.has_method("init_unique_id"):
			print("EnemiesManager: Enemy has no ID, initializing...")
			enemy.init_unique_id()
			enemy_id = enemy.unique_id
		
		# Check if this enemy is defeated
		if global.has_method("is_enemy_defeated") and global.is_enemy_defeated(current_scene_path, enemy_id):
			print("EnemiesManager: Enemy " + str(enemy_id) + " is defeated, removing!")
			enemy.queue_free()
			removed_count += 1
	
	print("EnemiesManager: Removed " + str(removed_count) + " defeated enemies from scene")
