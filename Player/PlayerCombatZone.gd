# PlayerCombatZone.gd - Handles group combat when enemies get close to player
extends Area2D

@export var group_radius: float = 150.0  # How far to look for other enemies
@export var coordination_time: float = 2.0  # Time to wait for other enemies

var enemies_in_zone: Array = []
var coordination_timer: float = 0.0
var is_coordinating: bool = false
var initiating_enemy: Node = null

func _ready():
	# Connect signals only if not already connected
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _process(delta):
	if is_coordinating:
		coordination_timer += delta
		
		# Check if coordination time is up
		if coordination_timer >= coordination_time:
			start_group_battle()

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		print("PlayerCombatZone: Enemy entered zone: ", body.name)
		
		# Check if this enemy has detected the player
		if enemy_has_detected_player(body):
			if not is_coordinating:
				# Start coordination for group battle
				start_coordination(body)
			else:
				# Add to existing coordination
				if body not in enemies_in_zone:
					enemies_in_zone.append(body)
					print("PlayerCombatZone: Added enemy to group: ", body.name)

func _on_body_exited(body):
	if body in enemies_in_zone:
		enemies_in_zone.erase(body)
		print("PlayerCombatZone: Enemy left zone: ", body.name)

func enemy_has_detected_player(enemy: Node) -> bool:
	# Check different enemy types for player detection
	if enemy.has_method("get_player_reference"):
		var player_ref = enemy.get_player_reference()
		if player_ref == null:
			return false
			
		# Check if enemy can see player (for BaseEnemy)
		if enemy.has_node("LineOfSightDetection"):
			var los = enemy.get_node("LineOfSightDetection")
			if los.has_method("can_see_player"):
				if los.can_see_player():
					return true
		
		# Check state for chase/spotted (for BaseEnemy)
		if "state" in enemy:
			var current_state = enemy.state
			if current_state == enemy.EnemyState.CHASE or current_state == enemy.EnemyState.SPOTTED:
				return true
	
	# Check for CleanEnemy (EnemyAI)
	if "can_see_player" in enemy:
		return enemy.can_see_player
	
	return false

func start_coordination(enemy: Node):
	print("PlayerCombatZone: Starting coordination with ", enemy.name)
	is_coordinating = true
	coordination_timer = 0.0
	initiating_enemy = enemy
	enemies_in_zone = [enemy]
	
	# Look for other nearby enemies who have also detected the player
	find_nearby_detecting_enemies(enemy)
	
	# Pause non-participating enemies
	pause_non_participating_enemies()

func find_nearby_detecting_enemies(initiating_enemy: Node):
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var initiator_pos = initiating_enemy.global_position
	
	print("PlayerCombatZone: Checking ", all_enemies.size(), " total enemies for group battle")
	
	for enemy in all_enemies:
		if enemy == initiating_enemy:
			continue
			
		var distance = initiator_pos.distance_to(enemy.global_position)
		if distance <= group_radius:
			# Check if this enemy has detected the player
			if enemy_has_detected_player(enemy):
				if enemy not in enemies_in_zone:
					enemies_in_zone.append(enemy)
					print("PlayerCombatZone: Added nearby detecting enemy: ", enemy.name, " at distance ", distance)

func pause_non_participating_enemies():
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if enemy not in enemies_in_zone:
			if enemy.has_method("pause_for_group_battle"):
				enemy.pause_for_group_battle()
			elif "velocity" in enemy:
				enemy.velocity = Vector2.ZERO

func start_group_battle():
	print("PlayerCombatZone: Starting group battle with ", enemies_in_zone.size(), " enemies")
	
	# Collect enemy data for battle
	var enemy_data_list = []
	for enemy in enemies_in_zone:
		if "enemy_data" in enemy:
			enemy_data_list.append(enemy.enemy_data)
	
	if enemy_data_list.size() == 0:
		print("PlayerCombatZone: No valid enemies for battle, canceling")
		cancel_coordination()
		return
	
	# Set up global battle data
	Global.current_battle_enemies = enemy_data_list
	Global.enemy_position = initiating_enemy.global_position
	
	print("PlayerCombatZone: Set Global.current_battle_enemies to: ", Global.current_battle_enemies)
	
	# Mark all participating enemies as having initiated battle
	for enemy in enemies_in_zone:
		if "battle_initiated" in enemy:
			enemy.battle_initiated = true
	
	# Pause game and start transition
	Global.set_game_paused(true)
	Global.save_overworld_state()
	
	# Start battle transition - use the battle scene from the first enemy
	var battle_scene_path = "res://Cards/test.tscn"  # Default
	if "battle_scene" in initiating_enemy and initiating_enemy.battle_scene:
		battle_scene_path = initiating_enemy.battle_scene.resource_path
	
	# Get screen position for transition
	var screen_pos = initiating_enemy.global_position
	if initiating_enemy.has_method("get_screen_position"):
		screen_pos = initiating_enemy.get_screen_position()
	
	TransitionManager.start_combat(screen_pos, battle_scene_path)
	
	# Clean up
	is_coordinating = false
	enemies_in_zone.clear()

func cancel_coordination():
	print("PlayerCombatZone: Canceling coordination")
	
	# Resume all paused enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy.has_method("resume_from_group_battle"):
			enemy.resume_from_group_battle()
	
	is_coordinating = false
	enemies_in_zone.clear()
