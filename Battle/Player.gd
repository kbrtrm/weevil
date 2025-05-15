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

func _ready():
	# Add to player group
	add_to_group("player")
	
	# Initialize UI
	update_health_display()
	update_block_display()
	update_status_display()

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

# Heal health
func heal(amount: int):
	health = min(health + amount, max_health)
	emit_signal("health_changed", health, max_health)
	update_health_display()

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
	# Process status effects
	
	# Update UI elements
	update_health_display()
	update_block_display()
	update_status_display()

# Called at the end of the player's turn
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

# Player death
func die():
	# Handle game over
	print("Player Defeated - Game Over!")
	# You could emit a signal here to trigger a game over screen
	# get_tree().call_group("game_controllers", "player_died")

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

# Update status effect display
func update_status_display():
	# This would update any UI elements showing status effects
	# For example, showing icons for weak, vulnerable, etc.
	# You could implement this with a status effect container
	pass
