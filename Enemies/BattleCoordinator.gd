# BattleCoordinator.gd - Manages group combat scenarios
extends Node

# Singleton pattern - this will be autoloaded
signal group_battle_ready(enemies: Array)

@export var group_radius: float = 150.0  # Radius to check for other enemies
@export var coordination_timeout: float = 5.0  # Max time to wait for enemies to gather

var active_group_battle: Dictionary = {}
var coordination_timer: float = 0.0
var is_coordinating: bool = false

func _ready():
	# Add to group for easy finding
	add_to_group("battle_coordinator")
	print("BattleCoordinator: Ready and added to group")

func _process(delta):
	if is_coordinating:
		coordination_timer += delta
		
		# Check if all enemies in the group have reached combat zones
		if are_all_enemies_ready() or coordination_timer >= coordination_timeout:
			start_group_battle()

# Called when an enemy wants to initiate combat
func request_combat_initiation(initiating_enemy: Node, player: Node) -> bool:
	print("BattleCoordinator: Combat request from ", initiating_enemy.name)
	
	if is_coordinating:
		# Already coordinating a battle, add this enemy if it's part of the group
		if initiating_enemy in active_group_battle.get("enemies", []):
			mark_enemy_ready(initiating_enemy)
		return false  # Don't start battle yet
	
	# Find all nearby enemies who have detected the player
	var nearby_detecting_enemies = find_nearby_detecting_enemies(initiating_enemy, player)
	
	print("BattleCoordinator: Found ", nearby_detecting_enemies.size(), " nearby detecting enemies")
	
	if nearby_detecting_enemies.size() <= 1:
		# No other enemies, start individual combat immediately
		print("BattleCoordinator: Only one enemy, starting individual combat")
		return true
	
	# Multiple enemies detected, start coordination
	print("BattleCoordinator: Multiple enemies detected, starting coordination")
	start_coordination(nearby_detecting_enemies, player)
	mark_enemy_ready(initiating_enemy)
	return false  # Don't start battle yet

func find_nearby_detecting_enemies(initiating_enemy: Node, player: Node) -> Array:
	var nearby_enemies = []
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var initiator_pos = initiating_enemy.global_position
	
	print("BattleCoordinator: Checking ", all_enemies.size(), " total enemies")
	
	for enemy in all_enemies:
		if enemy == initiating_enemy:
			nearby_enemies.append(enemy)
			print("BattleCoordinator: Added initiating enemy: ", enemy.name)
			continue
			
		var distance = initiator_pos.distance_to(enemy.global_position)
		print("BattleCoordinator: Enemy ", enemy.name, " is ", distance, " units away")
		
		if distance <= group_radius:
			# Check if this enemy has detected the player
			var has_detected = enemy_has_detected_player(enemy)
			print("BattleCoordinator: Enemy ", enemy.name, " has detected player: ", has_detected)
			
			if has_detected:
				nearby_enemies.append(enemy)
				print("BattleCoordinator: Added nearby detecting enemy: ", enemy.name, " at distance ", distance)
	
	return nearby_enemies

func enemy_has_detected_player(enemy: Node) -> bool:
	# Check different enemy types for player detection
	if enemy.has_method("get_player_reference"):
		var player_ref = enemy.get_player_reference()
		print("BattleCoordinator: Enemy ", enemy.name, " player_ref: ", player_ref)
		
		if player_ref == null:
			return false
			
		# Check if enemy can see player (for BaseEnemy)
		if enemy.has_node("LineOfSightDetection"):
			var los = enemy.get_node("LineOfSightDetection")
			if los.has_method("can_see_player"):
				var can_see = los.can_see_player()
				print("BattleCoordinator: Enemy ", enemy.name, " line of sight: ", can_see)
				if can_see:
					return true
		
		# Check state for chase/spotted (for BaseEnemy)
		if "state" in enemy:
			var current_state = enemy.state
			var is_chasing = current_state == enemy.EnemyState.CHASE or current_state == enemy.EnemyState.SPOTTED
			print("BattleCoordinator: Enemy ", enemy.name, " state: ", current_state, " is chasing: ", is_chasing)
			if is_chasing:
				return true
	
	# Check for CleanEnemy (EnemyAI)
	if "can_see_player" in enemy:
		var can_see = enemy.can_see_player
		print("BattleCoordinator: CleanEnemy ", enemy.name, " can_see_player: ", can_see)
		return can_see
	
	return false

func start_coordination(enemies: Array, player: Node):
	print("BattleCoordinator: Starting coordination for ", enemies.size(), " enemies")
	is_coordinating = true
	coordination_timer = 0.0
	
	active_group_battle = {
		"enemies": enemies,
		"player": player,
		"ready_enemies": [],
		"enemy_data": []
	}
	
	# Pause all non-participating enemies
	pause_non_participating_enemies(enemies)
	
	# Notify participating enemies about group coordination
	for enemy in enemies:
		if enemy.has_method("enter_group_coordination"):
			enemy.enter_group_coordination()

func pause_non_participating_enemies(participating_enemies: Array):
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in all_enemies:
		if enemy not in participating_enemies:
			if enemy.has_method("pause_for_group_battle"):
				enemy.pause_for_group_battle()
			elif "velocity" in enemy:
				enemy.velocity = Vector2.ZERO

func mark_enemy_ready(enemy: Node):
	if not is_coordinating:
		return
		
	var ready_enemies = active_group_battle.get("ready_enemies", [])
	if enemy not in ready_enemies:
		ready_enemies.append(enemy)
		active_group_battle["ready_enemies"] = ready_enemies
		print("BattleCoordinator: Enemy ", enemy.name, " is ready for battle (", ready_enemies.size(), "/", active_group_battle.enemies.size(), ")")

func are_all_enemies_ready() -> bool:
	if not is_coordinating:
		return false
		
	var ready_count = active_group_battle.get("ready_enemies", []).size()
	var total_count = active_group_battle.get("enemies", []).size()
	return ready_count >= total_count

func start_group_battle():
	if not is_coordinating:
		return
		
	print("BattleCoordinator: Starting group battle with ", active_group_battle.ready_enemies.size(), " enemies")
	
	# Collect enemy data for battle
	var enemy_data_list = []
	for enemy in active_group_battle.get("ready_enemies", []):
		if "enemy_data" in enemy:
			enemy_data_list.append(enemy.enemy_data)
	
	# If no enemies reached the combat zone, cancel
	if enemy_data_list.size() == 0:
		print("BattleCoordinator: No enemies ready, canceling group battle")
		cancel_coordination()
		return
	
	# Set up global battle data
	Global.current_battle_enemies = enemy_data_list
	
	# Use the first ready enemy for position and battle scene
	var first_enemy = active_group_battle.ready_enemies[0]
	Global.enemy_position = first_enemy.global_position
	
	# Start the battle
	var battle_scene_path = "res://Cards/test.tscn"  # Default battle scene
	if "battle_scene" in first_enemy and first_enemy.battle_scene:
		battle_scene_path = first_enemy.battle_scene.resource_path
	
	# Pause game and start transition
	Global.set_game_paused(true)
	Global.save_overworld_state()
	
	# Get screen position for transition
	var screen_pos = first_enemy.global_position
	if first_enemy.has_method("get_screen_position"):
		screen_pos = first_enemy.get_screen_position()
	
	TransitionManager.start_combat(screen_pos, battle_scene_path)
	
	# Mark all participating enemies as initiated
	for enemy in active_group_battle.enemies:
		if "battle_initiated" in enemy:
			enemy.battle_initiated = true
	
	# Clean up
	is_coordinating = false
	active_group_battle.clear()

func cancel_coordination():
	print("BattleCoordinator: Canceling coordination")
	
	# Resume all paused enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy.has_method("resume_from_group_battle"):
			enemy.resume_from_group_battle()
	
	# Reset flags
	for enemy in active_group_battle.get("enemies", []):
		if enemy.has_method("exit_group_coordination"):
			enemy.exit_group_coordination()
	
	is_coordinating = false
	active_group_battle.clear()
