# Enemy.gd
extends Node2D

signal health_changed(current, max_health)
signal block_changed(amount)
signal status_applied(status_type, amount)
signal enemy_died

# At the top of your script
@onready var custom_font = load("res://Themes/Tiny Click2.ttf") as FontFile

const StatusIconScene = preload("res://Battle/StatusIcon.tscn")

# Enemy stats
@export var enemy_name: String = "Enemy"
@export var max_health: int = 15
@export var base_damage: int = 8
var health: int
var block: int = 0
var intent: String = "attack"  # Can be "attack", "defend", "buff", etc.
var intent_value: int = 0

# Status effects
var weak: int = 0
var vulnerable: int = 0
var bleed: int = 0
var strength: int = 0

# UI references
@onready var health_label = $HealthLabel
@onready var block_icon = $BlockIcon
@onready var block_label = $BlockBG/BlockLabel
@onready var block_bg = $BlockBG
@onready var intent_icon = $IntentIcon
@onready var intent_label = $IntentLabel
@onready var status_container = $StatusContainer
@onready var health_bar = $HealthBarContainer/HealthBar

func _ready():
	# Add to enemies group
	add_to_group("enemies")
	
	# Initialize health to max at start
	health = max_health
	
	# Initialize UI
	update_health_display()
	update_block_display()
	update_status_display()
	
	if health_bar:
		health_bar.set_health(health, max_health)
	
	# Set initial intent
	choose_intent()

# Take damage with block reduction
func take_damage(amount: int):
	# Ensure amount is an integer
	amount = int(amount)
	print("Enemy.take_damage: Called with amount = " + str(amount))
	print("Enemy.take_damage: Current health = " + str(health) + ", Current block = " + str(block))
	
	# Apply vulnerable effect (50% more damage)
	var actual_damage = amount
	if vulnerable > 0:
		var vulnerable_multiplier = 1.5
		actual_damage = int(floor(actual_damage * vulnerable_multiplier))
		print("Enemy.take_damage: Vulnerable applied! Damage increased from " + str(amount) + " to " + str(actual_damage))
	
	# Store original values for comparison
	var original_damage = actual_damage
	var original_block = block
	var original_health = health
	
	# Apply damage reduction from block
	var damage_to_health = actual_damage
	if block > 0:
		var block_reduction = min(block, actual_damage)
		damage_to_health = actual_damage - block_reduction
		block = block - block_reduction
		print("Enemy.take_damage: Block absorbed " + str(block_reduction) + " damage")
		print("Enemy.take_damage: Remaining damage to health: " + str(damage_to_health))
		print("Enemy.take_damage: Block remaining: " + str(block))
	
	# Apply the remaining damage to health
	if damage_to_health > 0:
		health = max(0, health - damage_to_health)
		print("Enemy.take_damage: Health reduced from " + str(original_health) + " to " + str(health))
	
	# Emit signal
	emit_signal("health_changed", health, max_health)
	
	# Update UI - block first, then health
	update_block_display()
	update_health_display()
	
	# Update health bar with proper values
	if health_bar:
		health_bar.set_health(health, max_health)
		print("Enemy.take_damage: Updated health bar to " + str(health) + "/" + str(max_health))
	
	# Check for death
	if health <= 0:
		die()

# Enemy.gd - Updated add_block with integer conversion
func add_block(amount: int):
	# Ensure amount is an integer
	amount = int(amount)
	
	block += amount
	block = int(block)  # Ensure integer
	
	emit_signal("block_changed", block)
	update_block_display()

# Add weak status effect
func add_weak(amount: int):
	var old_weak = weak
	weak += amount
	emit_signal("status_applied", "weak", weak)
	update_status_display()
	
	# Recalculate intent value if this affects damage
	if intent == "attack":
		recalculate_intent_value()
		print("Enemy: Weak applied! Damage reduced from previous calculation")

# Add vulnerable status effect
func add_vulnerable(amount: int):
	vulnerable += amount
	emit_signal("status_applied", "vulnerable", vulnerable)
	update_status_display()

# Add bleed status effect
func add_bleed(amount: int):
	bleed += amount
	emit_signal("status_applied", "bleed", bleed)
	update_status_display()

# Add strength status effect
func add_strength(amount: int):
	var old_strength = strength
	strength += amount
	emit_signal("status_applied", "strength", strength)
	update_status_display()
	
	# Recalculate damage with new strength
	if intent == "attack":
		recalculate_damage_with_strength()
		print("Enemy: Strength changed! New damage: ", intent_value)

# Called at the start of the enemy's turn
func start_turn():
	# Reset block at START of turn (after player attack)
	block = 0
	update_block_display()
	print("Enemy.start_turn: Block reset to 0 at the start of turn")
	
	# Process status effects - like bleed damage
	if bleed > 0:
		take_damage(bleed)
		
		# Create bleed effect
		var bleed_label = Label.new()
		bleed_label.text = str(bleed) + " Bleed"
		bleed_label.add_theme_color_override("font_color", Color(0.8, 0.1, 0.1))
		bleed_label.add_theme_font_size_override("font_size", 16)
		add_child(bleed_label)
		bleed_label.position = Vector2(0, -20)
		
		# Animate and remove
		var tween = create_tween()
		tween.tween_property(bleed_label, "position", Vector2(0, -40), 0.5)
		tween.parallel().tween_property(bleed_label, "modulate", Color(0.8, 0.1, 0.1, 0), 0.5)
		tween.tween_callback(func(): bleed_label.queue_free())
		
		# Reduce bleed by 1
		bleed -= 1
		update_status_display()
	
	# Execute intent
	execute_intent()
	
	# Choose next intent
	choose_intent()
	
	# Update UI
	update_health_display()
	update_status_display()

func end_turn():
	# DO NOT reset block here, keep it for player attacks
	print("Enemy.end_turn: Block preserved for player attacks: " + str(block))
	
	# Store old values to see if they changed
	var old_weak = weak
	var old_strength = strength
	
	# Reduce duration of status effects
	if weak > 0:
		weak -= 1
		print("Enemy: Weak reduced to ", weak)
	if vulnerable > 0:
		vulnerable -= 1
		print("Enemy: Vulnerable reduced to ", vulnerable)
	
	# Recalculate intent if status effects that affect damage changed
	if (old_weak != weak or old_strength != strength) and intent == "attack":
		recalculate_intent_value()
		print("Enemy: Status effects expired, recalculated damage")
	
	# Update status display
	update_status_display()

# Choose the next intent (attack, defend, etc.)
func choose_intent():
	# Random intent selection
	var roll = randf()
	
	if roll < 0.6:  # 60% chance to attack
		intent = "attack"
		var base_attack = base_damage + strength
		intent_value = int(base_attack)  # Ensure integer
		
		# Apply weak effect (25% less damage)
		if weak > 0:
			var old_value = intent_value
			intent_value = int(floor(intent_value * 0.75))  # Ensure integer
	
	elif roll < 0.85:  # 25% chance to defend
		intent = "defend"
		intent_value = int(randi_range(5, 10))  # Ensure integer
	
	else:  # 15% chance to buff
		intent = "buff"
		intent_value = int(2)  # Ensure integer
	
	# Update the intent display
	update_intent_display()

# Execute the current intent
func execute_intent():
	# Get references
	var battle_manager = get_parent()
	var player = battle_manager.get_player() if battle_manager.has_method("get_player") else null
	
	if not player:
		print("Warning: Cannot find player to execute intent!")
		return
	
	match intent:
		"attack":
			# Store original values to track what happened
			var original_health = player.health
			var original_block = player.block
			
			# Attack the player - this will handle vulnerable and block internally
			player.take_damage(intent_value)
			
			# Calculate what happened during damage application
			var block_used = max(0, original_block - player.block)
			var health_lost = max(0, original_health - player.health)
			
			# Create attack visual based on what happened
			var damage_label = Label.new()
			
			if health_lost == 0:
				# Attack was fully blocked
				damage_label.text = "BLOCK"
				damage_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))  # Blue for block
			else:
				# Some damage went through to health
				damage_label.text = str(int(health_lost))
				damage_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))  # Red for damage
			
			damage_label.add_theme_font_size_override("font_size", 16)
			player.add_child(damage_label)
			damage_label.position = Vector2(20, -20)
			
			# Animate and remove
			var tween = create_tween()
			tween.tween_property(damage_label, "position", Vector2(20, -40), 1.0)
			tween.parallel().tween_property(damage_label, "modulate", Color(damage_label.modulate.r, damage_label.modulate.g, damage_label.modulate.b, 0), 1.0)
			tween.tween_callback(func(): damage_label.queue_free())
			
		"defend":
			# Add block to self
			add_block(intent_value)
			
		"buff":
			# Add strength to self
			add_strength(intent_value)

# Enemy death
func die():
	# Handle death - rewards, animations, etc.
	print(enemy_name + " defeated!")
	emit_signal("enemy_died")
	
	# You could trigger an animation here and remove the enemy
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 0), 1.0)
	
	# When animation is done, end the battle with our transition
	tween.tween_callback(func():
		# Find the battle manager to end the battle
		var battle_manager = get_parent()
		if battle_manager and battle_manager.has_method("end_battle"):
			print("Enemy: Calling battle_manager.end_battle(true)")
			battle_manager.end_battle(true)  # true = player won
		else:
			# If we can't find the battle manager, call Global directly
			print("Enemy: Could not find battle_manager, calling Global directly")
			var global = get_node("/root/Global")
			if global and global.has_method("return_to_overworld"):
				global.return_to_overworld(true)  # true = player won
			else:
				print("ERROR: Could not find Global or return_to_overworld method!")
	)

# Update the health display
func update_health_display():
	if health_label:
		health_label.text = str(health) + "/" + str(max_health)

# Update the block display
func update_block_display():
	if block_label:
		if block > 0:
			block_label.text = str(block)
			block_label.visible = true
		else:
			block_label.visible = false
	
	if block_bg:
		block_bg.visible = block > 0
	else:
		block_bg.visible = false
	
	# Update health bar color based on block status
	update_health_bar_color()

# Update intent display
# Add to Enemy.gd update_intent_display function
func update_intent_display():
	if intent_label:
		match intent:
			"attack":
				intent_label.text = str(int(intent_value)) + " DMG"
			"defend":
				intent_label.text = "+" + str(int(intent_value)) + " BLK"
			"buff":
				intent_label.text = "+" + str(int(intent_value)) + " STR"
		
		# Make sure text is visible
		intent_label.add_theme_font_size_override("font_size", 8)
		
	if intent_icon:
		match intent:
			"attack":
				intent_icon.modulate = Color(1, 0.3, 0.3)  # Red for attack
			"defend":
				intent_icon.modulate = Color(0.3, 0.7, 1)  # Blue for defend
			"buff":
				intent_icon.modulate = Color(1, 0.8, 0.2)  # Yellow for buff

# Enemy.gd - Updated update_status_display function
func update_status_display():
	# Clear existing status icons
	for child in status_container.get_children():
		child.queue_free()
	
	# Create status effect displays
	if weak > 0:
		add_status_icon("weak", weak, Color(0.7, 0.3, 0.7))  # Purple
	
	if vulnerable > 0:
		add_status_icon("vulnerable", vulnerable, Color(1.0, 0.5, 0.1))  # Orange
	
	if bleed > 0:
		add_status_icon("bleed", bleed, Color(0.9, 0.1, 0.1))  # Dark red
	
	if strength > 0:
		add_status_icon("strength", strength, Color(0.9, 0.1, 0.3))  # Red

# Updated helper function to add a status icon
func add_status_icon(status_name, amount, color):
	var status_icon = StatusIconScene.instantiate()
	
	# Set up the status data
	status_icon.setup_status(status_name, amount, color)
	
	# Add to status container
	status_container.add_child(status_icon)
	
	# Optional: Animate the new status icon
	status_icon.animate_update()

# Recalculate the current intent value based on current status effects
func recalculate_intent_value():
	match intent:
		"attack":
			var base_attack = base_damage + strength
			intent_value = int(base_attack)
			
			# Apply weak effect (25% less damage)
			if weak > 0:
				intent_value = int(floor(intent_value * 0.75))
				
		"defend":
			# Defend value doesn't change with status effects usually
			pass
		"buff":
			# Buff value doesn't change with status effects usually
			pass
	
	# Update the UI to show the new intent value
	update_intent_display()
	print("Enemy: Recalculated intent value to ", intent_value, " (weak stacks: ", weak, ")")

# Recalculate damage when strength changes
func recalculate_damage_with_strength():
	if intent == "attack":
		var base_attack = base_damage + strength
		intent_value = int(base_attack)
		
		# Still apply weak if present
		if weak > 0:
			intent_value = int(floor(intent_value * 0.75))
		
		update_intent_display()
		print("Enemy: Recalculated damage with strength. New value: ", intent_value)
		
# Call this whenever a status effect changes that could affect current intent
func on_status_effect_changed():
	# Only recalculate if we have a current intent that could be affected
	if intent == "attack":
		recalculate_intent_value()
	
	# Update the display
	update_status_display()

# Update health bar color based on block status
func update_health_bar_color():
	if health_bar and health_bar.has_method("set_block_status"):
		health_bar.set_block_status(block)

# Animate enemy entrance from the right (supports multiple enemies)
func animate_entrance(enemy_index: int = 0, total_enemies: int = 1):
	print("Enemy: Starting entrance animation (", enemy_index + 1, " of ", total_enemies, ")")
	
	# Store the final position
	var final_position = global_position
	
	# Calculate staggered starting positions for multiple enemies
	var base_offset = 400  # Base distance off-screen
	var vertical_spread = 30  # Vertical spacing between enemies
	var delay_per_enemy = 0.15  # Delay between each enemy
	
	# Start position calculation
	var start_x = final_position.x + base_offset + (enemy_index * 50)  # Each enemy starts further right
	var start_y = final_position.y - (vertical_spread * (total_enemies - 1) / 2) + (enemy_index * vertical_spread)
	
	# Move enemy to starting position
	global_position = Vector2(start_x, start_y)
	
	# Calculate delay based on enemy index
	var entrance_delay = 0.2 + (enemy_index * delay_per_enemy)
	
	# Wait for the calculated delay
	await get_tree().create_timer(entrance_delay).timeout
	
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	
	# Slide in from right with a bounce
	tween.tween_property(self, "global_position", final_position, 0.8)
	
	# Optional: Add a slight scale effect
	scale = Vector2(0.8, 0.8)  # Start smaller
	tween.parallel().tween_property(self, "scale", Vector2(1.0, 1.0), 0.8)
	
	print("Enemy ", enemy_index + 1, ": Entrance animation started with ", entrance_delay, "s delay")
