# Enemy.gd
extends Node2D

signal health_changed(current, max_health)
signal block_changed(amount)
signal status_applied(status_type, amount)
signal enemy_died

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
@onready var block_label = $BlockLabel
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
	print("Enemy.take_damage: Current block = " + str(block))
	
	# Apply vulnerable effect (50% more damage)
	var actual_damage = amount
	if vulnerable > 0:
		var vulnerable_multiplier = 1.5
		actual_damage = int(floor(actual_damage * vulnerable_multiplier))
		print("Enemy.take_damage: Vulnerable applied! Damage increased to " + str(actual_damage))
	
	# Apply damage reduction from block
	if block > 0:
		var block_reduction = min(block, actual_damage)
		block_reduction = int(block_reduction)  # Ensure integer
		actual_damage -= block_reduction
		block -= block_reduction
		print("Enemy.take_damage: Block absorbed " + str(block_reduction) + " damage. Remaining block: " + str(block))
		print("Enemy.take_damage: Damage after block: " + str(actual_damage))
		update_block_display()
	
	# Apply the remaining damage to health
	actual_damage = int(actual_damage)  # Ensure integer
	var old_health = health
	health = max(0, health - actual_damage)
	print("Enemy.take_damage: Health reduced from " + str(old_health) + " to " + str(health) + " (damage taken: " + str(old_health - health) + ")")
	
	# Emit signal
	emit_signal("health_changed", health, max_health)
	
	# Update UI
	update_health_display()
	
	# Add this after updating health_label
	if health_bar:
		health_bar.set_health(health, max_health)
	
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
	weak += amount
	emit_signal("status_applied", "weak", weak)
	update_status_display()

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
	strength += amount
	emit_signal("status_applied", "strength", strength)
	update_status_display()

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
	
	# Reduce duration of status effects
	if weak > 0:
		weak -= 1
	if vulnerable > 0:
		vulnerable -= 1
	
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
			damage_label.position = Vector2(0, -20)
			
			# Animate and remove
			var tween = create_tween()
			tween.tween_property(damage_label, "position", Vector2(0, -40), 1.0)
			#tween.parallel().tween_property(damage_label, "modulate", damage_label.modulate.with_alpha(0), 0.5)
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
	
	if block_icon:
		block_icon.visible = block > 0

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

# Helper function to add a status icon
func add_status_icon(status_name, amount, color):
	var icon = Label.new()
	icon.text = status_name.capitalize() + "\n" + str(amount)
	icon.add_theme_color_override("font_color", color)
	icon.add_theme_font_size_override("font_size", 8)
	icon.custom_minimum_size = Vector2(40, 25)
	
	# Add to status container
	status_container.add_child(icon)
