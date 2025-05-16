# Player.gd
extends Node2D

signal health_changed(current, max_health)
signal block_changed(amount)
signal status_applied(status_type, amount)

# Player stats
var health: int = 80
var max_health: int = 80
var block: int = 0

# Status effects
var weak: int = 0
var vulnerable: int = 0
var strength: int = 0
var dexterity: int = 0

# UI references
@onready var health_label = $HealthLabel
@onready var block_icon = $BlockIcon
@onready var block_label = $BlockLabel
@onready var status_container = $StatusContainer
@onready var health_bar = $HealthBar

func _ready():
	# Add to player group
	add_to_group("player")
	
	# Initialize UI
	update_health_display()
	update_block_display()
	update_status_display()
	
	# Initialize the health bar with player-specific color (blue)
	if health_bar:
		# Initialize health
		health_bar.set_health(health, max_health)

# Take damage with block reduction
func take_damage(amount: int):
	print("Player: Taking " + str(amount) + " damage")
	print("Player: Current block = " + str(block))
	amount = int(amount)
	
	# Apply vulnerable effect (50% more damage)
	var actual_damage = amount
	if vulnerable > 0:
		var vulnerable_multiplier = 1.5
		actual_damage = int(floor(actual_damage * vulnerable_multiplier))
		print("Player: Vulnerable! Damage increased to " + str(actual_damage))
	
	# Apply damage reduction from block
	if block > 0:
		var block_reduction = min(block, actual_damage)
		actual_damage -= block_reduction
		block -= block_reduction
		print("Player: Block absorbed " + str(block_reduction) + " damage. Remaining block: " + str(block))
		print("Player: Damage after block: " + str(actual_damage))
		update_block_display()
	
	# Apply the remaining damage to health
	actual_damage = int(actual_damage)  # Ensure integer
	var old_health = health
	health = max(0, health - actual_damage)
	print("Player: Health reduced from " + str(old_health) + " to " + str(health) + " (damage taken: " + str(old_health - health) + ")")
	
	# Emit signal
	emit_signal("health_changed", health, max_health)
	
	# Update UI
	update_health_display()
	
	if health_bar:
		health_bar.set_health(health, max_health)
	
	# Check for death
	if health <= 0:
		die()

# Add block/defense
func add_block(amount: int):
	# Ensure amount is an integer
	amount = int(amount)
	print("Player.add_block: Adding " + str(amount) + " block")
	print("Player.add_block: Current block was: " + str(block))
	
	# Add the block
	block += amount
	block = int(block)  # Ensure integer
	
	print("Player.add_block: New block total: " + str(block))
	
	# Emit signal
	emit_signal("block_changed", block)
	
	# REMOVED: Visual effect creation
	# (The card's apply_block_effect function will handle this)
	
	# Update display
	update_block_display()

# Heal health
func heal(amount: int):
	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)
	update_health_display()
	
	# Add this after updating health_label
	if health_bar:
		health_bar.set_health(health, max_health)

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

# Add strength status effect
func add_strength(amount: int):
	strength += amount
	emit_signal("status_applied", "strength", strength)
	update_status_display()

# Add dexterity status effect
func add_dexterity(amount: int):
	dexterity += amount
	emit_signal("status_applied", "dexterity", dexterity)
	update_status_display()

# Called at the start of the player's turn
func start_turn():
	# Reset block at START of turn (after enemy attack)
	block = 0
	update_block_display()
	print("Player.start_turn: Block reset to 0 at the start of turn")
	
	# Process status effects
	
	# Update UI elements
	update_health_display()
	update_status_display()

func end_turn():
	# DO NOT reset block here, keep it for enemy attacks
	print("Player.end_turn: Block preserved for enemy attacks: " + str(block))
	
	# Reduce duration of status effects
	if weak > 0:
		weak -= 1
	if vulnerable > 0:
		vulnerable -= 1
	
	# Update status display
	update_status_display()
	
# Player death
func die():
	# Handle game over
	print("Player Defeated - Game Over!")
	# You could emit a signal here to trigger a game over screen
	# get_tree().call_group("game_controllers", "player_died")

# Update the health display
func update_health_display():
	if health_label:
		health_label.text = str(int(health)) + "/" + str(int(max_health))

func update_block_display():
	if block_label:
		block_label.text = str(int(block))
		
		# Show icon only if we have block
		block_icon.visible = block > 0

# Player.gd - Updated update_status_display function
func update_status_display():
	# Clear existing status icons
	for child in status_container.get_children():
		child.queue_free()
	
	# Create status effect displays
	if weak > 0:
		add_status_icon("weak", weak, Color(0.7, 0.3, 0.7))  # Purple
	
	if vulnerable > 0:
		add_status_icon("vulnerable", vulnerable, Color(1.0, 0.5, 0.1))  # Orange
	
	if strength > 0:
		add_status_icon("strength", strength, Color(0.9, 0.1, 0.3))  # Red
	
	if dexterity > 0:
		add_status_icon("dexterity", dexterity, Color(0.1, 0.8, 0.3))  # Green

# Helper function to add a status icon
func add_status_icon(status_name, amount, color):
	var icon = Label.new()
	icon.text = status_name.capitalize() + "\n" + str(amount)
	icon.add_theme_color_override("font_color", color)
	icon.add_theme_font_size_override("font_size", 8)
	icon.custom_minimum_size = Vector2(40, 25)
	
	# Add to status container
	status_container.add_child(icon)
