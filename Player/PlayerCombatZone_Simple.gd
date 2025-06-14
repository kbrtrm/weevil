# PlayerCombatZone.gd - Simple group combat system
extends Area2D

@export var group_battle_delay: float = 1.5  # Time to wait for more enemies
@export var group_radius: float = 120.0  # How far to check for other enemies

var enemies_ready_for_battle: Array = []
var battle_timer: Timer
var is_waiting_for_group: bool = false

func _ready():
	# Connect signals only if not already connected
	if not body_entered.is_connected(_on_enemy_entered):
		body_entered.connect(_on_enemy_entered)
	
	# Create a timer for group battle coordination
	battle_timer = Timer.new()
	battle_timer.wait_time = group_battle_delay
	battle_timer.one_shot = true
	battle_timer.timeout.connect(_on_battle_timer_timeout)
	add_child(battle_timer)

func _on_enemy_entered(body):
	if not body.is_in_group("enemies"):
		return
	
	print("PlayerCombatZone: Enemy entered: ", body.name)
	
	# Check if this enemy is actually chasing the player
	if not is_enemy_chasing_player(body):
		print("PlayerCombatZone: Enemy is not chasing player, ignoring")
		return
	
	# Add enemy to battle list
	if body not in enemies_ready_for_battle:
		enemies_ready_for_battle.append(body)
		print("PlayerCombatZone: Added enemy to battle group: ", body.name)
	
	if not is_waiting_for_group:
		print("PlayerCombatZone: Starting group battle timer...")
		is_waiting_for_group = true
		
		# Look for other nearby enemies that are also chasing
		find_nearby_chasing_enemies(body)
		
		# Start timer to wait for more enemies
		battle_timer.start()
		
		# Pause all non-participating enemies
		pause_other_enemies()

func is_enemy_chasing_player(enemy: Node) -> bool:
	# Check BaseEnemy state
	if "state" in enemy and "EnemyState" in enemy:
		var state = enemy.state
		return state == enemy.EnemyState.CHASE or state == enemy.EnemyState.SPOTTED
	
	# Check CleanEnemy
	if "can_see_player" in enemy:
		return enemy.can_see_player
	
	# Check if enemy has player reference
	if enemy.has_method("get_player_reference"):
		return enemy.get_player_reference() != null
	
	return false

func find_nearby_chasing_enemies(initiating_enemy: Node):
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var player_pos = get_parent().global_position  # Player position
	
	for enemy in all_enemies:
		if enemy == initiating_enemy or enemy in enemies_ready_for_battle:
			continue
		
		var distance = player_pos.distance_to(enemy.global_position)
		if distance <= group_radius and is_enemy_chasing_player(enemy):
			enemies_ready_for_battle.append(enemy)
			print("PlayerCombatZone: Found nearby chasing enemy: ", enemy.name, " at distance ", distance)

func pause_other_enemies():
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy not in enemies_ready_for_battle:
			if "velocity" in enemy:
				enemy.velocity = Vector2.ZERO
			if enemy.has_method("pause_for_group_battle"):
				enemy.pause_for_group_battle()

func _on_battle_timer_timeout():
	print("PlayerCombatZone: Timer finished, starting battle with ", enemies_ready_for_battle.size(), " enemies")
	start_group_battle()

func start_group_battle():
	if enemies_ready_for_battle.size() == 0:
		print("PlayerCombatZone: No enemies to fight!")
		reset_battle_state()
		return
	
	# Collect enemy data
	var enemy_data_list = []
	for enemy in enemies_ready_for_battle:
		if "enemy_data" in enemy:
			enemy_data_list.append(enemy.enemy_data)
			print("PlayerCombatZone: Added enemy data for: ", enemy.enemy_data.get("name", "Unknown"))
	
	if enemy_data_list.size() == 0:
		print("PlayerCombatZone: No valid enemy data found!")
		reset_battle_state()
		return
	
	print("PlayerCombatZone: Starting battle with ", enemy_data_list.size(), " enemies")
	
	# Set up Global for battle
	Global.current_battle_enemies = enemy_data_list
	Global.enemy_position = enemies_ready_for_battle[0].global_position
	
	# Mark enemies as having initiated battle
	for enemy in enemies_ready_for_battle:
		if "battle_initiated" in enemy:
			enemy.battle_initiated = true
	
	# Save state and start battle
	Global.set_game_paused(true) 
	Global.save_overworld_state()
	
	# Start battle transition
	var battle_scene = "res://Cards/test.tscn"
	TransitionManager.start_combat(Global.enemy_position, battle_scene)
	
	reset_battle_state()

func reset_battle_state():
	is_waiting_for_group = false
	enemies_ready_for_battle.clear()
	
	# Resume all enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy.has_method("resume_from_group_battle"):
			enemy.resume_from_group_battle()
