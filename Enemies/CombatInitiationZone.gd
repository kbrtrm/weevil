extends Area2D

@export var group_radius: float = 120.0  # How far to check for other enemies
@export var group_battle_delay: float = 1.5  # Time to wait for more enemies

var player = null
var group_battle_timer: Timer
var enemies_in_group: Array = []
var is_coordinating_battle: bool = false

func _ready():
	# Create timer for group battle coordination
	group_battle_timer = Timer.new()
	group_battle_timer.wait_time = group_battle_delay
	group_battle_timer.one_shot = true
	group_battle_timer.timeout.connect(_on_group_battle_timer_timeout)
	add_child(group_battle_timer)

func player_in_combat_zone():
	return player != null

func _on_body_entered(body):
	print("CombatZone: Body entered: " + body.name)
	
	# Check if the body is the player
	if body.is_in_group("player"):
		print("CombatZone: PLAYER DETECTED!")
		player = body
		
		# Check if this enemy is chasing the player
		var parent_enemy = get_parent()
		if is_enemy_chasing_player(parent_enemy):
			print("CombatZone: Enemy is chasing player, checking for group battle...")
			start_group_battle_check(parent_enemy)
		else:
			print("CombatZone: Enemy is not chasing player, no combat")

func _on_body_exited(body):
	if body == player:
		print("CombatZone: Player exited combat zone")
		player = null

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

func start_group_battle_check(initiating_enemy: Node):
	if is_coordinating_battle:
		return  # Already coordinating
	
	print("CombatZone: Starting group battle coordination for ", initiating_enemy.name)
	is_coordinating_battle = true
	enemies_in_group = [initiating_enemy]
	
	# Look for other nearby enemies that are also chasing the player
	find_nearby_chasing_enemies(initiating_enemy)
	
	# Pause non-participating enemies
	pause_other_enemies()
	
	# Start timer
	group_battle_timer.start()
	print("CombatZone: Group battle timer started, waiting ", group_battle_delay, " seconds...")

func find_nearby_chasing_enemies(initiating_enemy: Node):
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	var initiator_pos = initiating_enemy.global_position
	
	print("CombatZone: Checking ", all_enemies.size(), " enemies for group battle")
	
	for enemy in all_enemies:
		if enemy == initiating_enemy or enemy in enemies_in_group:
			continue
		
		var distance = initiator_pos.distance_to(enemy.global_position)
		if distance <= group_radius and is_enemy_chasing_player(enemy):
			enemies_in_group.append(enemy)
			print("CombatZone: Added enemy to group: ", enemy.name, " at distance ", distance)

func pause_other_enemies():
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy not in enemies_in_group:
			if "velocity" in enemy:
				enemy.velocity = Vector2.ZERO
			if enemy.has_method("pause_for_group_battle"):
				enemy.pause_for_group_battle()

func _on_group_battle_timer_timeout():
	print("CombatZone: Group battle timer finished! Starting battle with ", enemies_in_group.size(), " enemies")
	start_group_battle()

func start_group_battle():
	if enemies_in_group.size() == 0:
		print("CombatZone: No enemies for battle!")
		reset_battle_state()
		return
	
	# Collect enemy data
	var enemy_data_list = []
	for enemy in enemies_in_group:
		if "enemy_data" in enemy:
			enemy_data_list.append(enemy.enemy_data)
			print("CombatZone: Added enemy to battle: ", enemy.enemy_data.get("name", "Unknown"))
	
	if enemy_data_list.size() == 0:
		print("CombatZone: No valid enemy data!")
		reset_battle_state()
		return
	
	# Set up Global for battle
	Global.current_battle_enemies = enemy_data_list
	Global.enemy_position = enemies_in_group[0].global_position
	
	# Mark enemies as having initiated battle
	for enemy in enemies_in_group:
		if "battle_initiated" in enemy:
			enemy.battle_initiated = true
	
	# Save state and start battle
	Global.set_game_paused(true)
	Global.save_overworld_state()
	
	# Start battle
	var battle_scene = "res://Cards/test.tscn"
	TransitionManager.start_combat(Global.enemy_position, battle_scene)
	
	reset_battle_state()

func reset_battle_state():
	is_coordinating_battle = false
	enemies_in_group.clear()
	
	# Resume all enemies
	var all_enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in all_enemies:
		if enemy.has_method("resume_from_group_battle"):
			enemy.resume_from_group_battle()
