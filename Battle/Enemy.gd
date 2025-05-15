# Enemy.gd
extends Node2D

signal health_changed(current, max_health)
signal block_changed(amount)
signal status_applied(status_type, amount)
signal enemy_died

# Enemy stats
@export var enemy_name: String = "Enemy"
@export var max_health: int = 50
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

func _ready():
	# Add to enemies group
	add_to_group("enemies")
	
	# Initialize health to max at start
	health = max_health
	
	# Initialize UI
	update_health_display()
	update_block_display()
	update_status_display()
	
	# Set initial intent
	choose_intent()

# Take damage with block reduction
func take_damage(amount: int):
	# Apply vulnerable effect (50% more damage)
	var actual_damage = amount
	if vulnerable > 0:
		actual_damage = floor(actual_damage * 1.5)
	
	# Apply damage reduction from block
	if block > 0:
		var block_reduction = min(block, actual_damage)
		actual_damage -= block_reduction
		block -= block_reduction
		update_block_display()
	
	# Apply the remaining damage to health
	health = max(0, health - actual_damage)
	
	# Emit signal
	emit_signal("health_changed", health, max_health)
	
	# Update UI
	update_health_display()
	
	# Check for death
	if health <= 0:
		die()

# Add block/defense
func add_block(amount: int):
	block += amount
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
	update_block_display()
	update_status_display()

# Called at the end of the enemy's turn
func end_turn():
	# Reset block at end of turn
	block = 0
	update_block_display()
	
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
		intent_value = base_damage + strength
		
		# Apply weak effect (25% less damage)
		if weak > 0:
			intent_value = floor(intent_value * 0.75)
	
	elif roll < 0.85:  # 25% chance to defend
		intent = "defend"
		intent_value = randi_range(5, 10)
	
	else:  # 15% chance to buff
		intent = "buff"
		intent_value = 2
	
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
			# Attack the player
			player.take_damage(intent_value)
			
			# Create attack visual
			var damage_label = Label.new()
			damage_label.text = str(intent_value)
			damage_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			damage_label.add_theme_font_size_override("font_size", 16)
			player.add_child(damage_label)
			damage_label.position = Vector2(0, -20)
			
			# Animate and remove
			var tween = create_tween()
			tween.tween_property(damage_label, "position", Vector2(0, -40), 0.5)
			tween.parallel().tween_property(damage_label, "modulate", Color(1, 0.3, 0.3, 0), 0.5)
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
	tween.tween_callback(func(): queue_free())

# Update the health display
func update_health_display():
	if health_label:
		health_label.text = str(health) + "/" + str(max_health)

# Update the block display
func update_block_display():
	if block_label:
		block_label.text = str(block)
	
	if block_icon:
		block_icon.visible = block > 0

# Update intent display
# Add to Enemy.gd update_intent_display function
func update_intent_display():
	if intent_label:
		match intent:
			"attack":
				intent_label.text = str(intent_value) + " DMG"
			"defend":
				intent_label.text = "+" + str(intent_value) + " BLK"
			"buff":
				intent_label.text = "+" + str(intent_value) + " STR"
		
		# Make sure text is visible
		intent_label.add_theme_font_size_override("font_size", 12)
		
	if intent_icon:
		match intent:
			"attack":
				intent_icon.modulate = Color(1, 0.3, 0.3)  # Red for attack
			"defend":
				intent_icon.modulate = Color(0.3, 0.7, 1)  # Blue for defend
			"buff":
				intent_icon.modulate = Color(1, 0.8, 0.2)  # Yellow for buff

# Update status effect display
func update_status_display():
	# This would update any UI elements showing status effects
	# For example, showing icons for weak, vulnerable, etc.
	# You could implement this with a status effect container
	pass
