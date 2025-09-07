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
@onready var block_label = $BlockBG/BlockLabel
@onready var block_bg = $BlockBG
@onready var status_container = $StatusContainer
@onready var health_bar = $HealthBarContainer/HealthBar
@onready var animated_sprite = $AnimatedSprite2D
@onready var slide_sprite = $SlideSprite

func _ready():
	# Add to player group
	add_to_group("player")
	
	# Set up sprites for entrance animation
	setup_sprites_for_entrance()
	
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
	
# Modify the die function
func die():
	# Handle game over
	print("Player Defeated - Game Over!")
	
	# Find battle manager to end battle
	var battle_manager = get_parent()
	if battle_manager and battle_manager.has_method("end_battle"):
		battle_manager.end_battle(false)  # false = player lost
	else:
		# Show game over screen as fallback
		get_tree().call_group("game_controllers", "player_died")

# Update the health display
func update_health_display():
	if health_label:
		health_label.text = str(int(health)) + "/" + str(int(max_health))

func update_block_display():
	if block_label:
		if block > 0:
			block_label.text = str(int(block))
			block_label.visible = true
			# Show icon only if we have block
			block_bg.visible = block > 0
		else:
			block_label.visible = false
			block_bg.visible = false
	
	update_health_bar_color()

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

# Update health bar color based on block status
func update_health_bar_color():
	if health_bar and health_bar.has_method("set_block_status"):
		health_bar.set_block_status(block)

# Set up sprites for entrance animation
func setup_sprites_for_entrance():
	if slide_sprite and animated_sprite:
		# Load the slide sprite texture with the correct filename
		var slide_texture = load("res://Battle/terb-slide-in.png")
		if slide_texture:
			slide_sprite.texture = slide_texture
			print("Player: Loaded terb-slide-in.png successfully")
		else:
			# Fallback: Try other possible locations
			slide_texture = load("res://Images/terb-slide-in.png")
			if slide_texture:
				slide_sprite.texture = slide_texture
				print("Player: Loaded terb-slide-in.png from Images folder")
			else:
				print("Player: terb-slide-in.png not found in Battle or Images folders")
		
		# Initially show slide sprite, hide animated sprite
		slide_sprite.visible = true
		animated_sprite.visible = false
		
		print("Player: Sprites set up for entrance animation")

# Hide player completely until entrance animation starts
func hide_for_enemy_entrance():
	visible = false
	print("Player: Hidden for enemy entrance animations")

# Show player when entrance animation starts
func show_for_entrance():
	visible = true
	print("Player: Made visible for entrance animation")

# Switch from slide sprite to animated sprite
func switch_to_animated_sprite():
	if slide_sprite and animated_sprite:
		slide_sprite.visible = false
		animated_sprite.visible = true
		print("Player: Switched to animated sprite")

# Animate player entrance from the left with sliding sprite
func animate_entrance():
	print("Player: Starting entrance animation with slide sprite")
	
	# Make player visible when entrance animation starts
	show_for_entrance()
	
	# Store the final position
	var final_position = global_position
	
	# Move player completely off-screen to the left
	# Get viewport width to ensure we're truly off-screen
	var viewport_width = get_viewport().get_visible_rect().size.x
	var off_screen_distance = viewport_width / 2 + 100  # Add extra margin to be completely off-screen
	global_position.x = final_position.x - off_screen_distance
	
	print("Player: Starting position: ", global_position, " Final position: ", final_position)
	
	# Create dust particle effect
	create_slide_dust_effect()
	
	# Create entrance animation with less extreme bounce
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)  # Changed from TRANS_BACK to TRANS_QUART for gentler bounce
	
	# Slide in from left with a gentler bounce
	tween.tween_property(self, "global_position", final_position, 0.8)
	
	# Reduce scale effect for less extreme bounce
	scale = Vector2(0.9, 0.9)  # Changed from 0.8 to 0.9 - less dramatic
	tween.parallel().tween_property(self, "scale", Vector2(1.05, 1.05), 0.6)  # Slight overshoot
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)  # Settle to normal
	
	# When animation completes, switch sprites and notify battle manager
	tween.finished.connect(func():
		print("Player: Entrance animation finished, switching to animated sprite")
		switch_to_animated_sprite()
		
		# Stop dust effect
		stop_slide_dust_effect()
		
		# Emit a custom signal that BattleManager can listen for
		get_tree().call_group("battle_managers", "on_player_entrance_complete")
	)
	
	print("Player: Entrance animation started with slide sprite")

# Create dust particle effect for sliding entrance
func create_slide_dust_effect():
	# Create multiple dust particle systems for more realistic effect
	create_main_dust_cloud()
	create_small_dust_puffs()
	create_ground_debris()

# Main dust cloud - billowing behind the player
func create_main_dust_cloud():
	var main_dust = CPUParticles2D.new()
	main_dust.name = "MainDustCloud"
	add_child(main_dust)
	
	# Position at player's feet, slightly behind
	main_dust.position = Vector2(-8, 8)
	
	# Configure main dust emission
	main_dust.emitting = true
	main_dust.amount = 20
	main_dust.lifetime = 2.0
	main_dust.one_shot = false
	
	# Dust has forward momentum from following player's motion, then spreads
	main_dust.direction = Vector2(0.3, -0.4)  # Forward and upward momentum
	main_dust.spread = 40.0
	
	# Varied particle speeds - some follow player momentum
	main_dust.initial_velocity_min = 25.0
	main_dust.initial_velocity_max = 55.0
	main_dust.angular_velocity_min = -20.0  # Less rotation for cleaner look
	main_dust.angular_velocity_max = 20.0
	
	# Dust scales up more dramatically as it spreads
	main_dust.scale_amount_min = 0.4
	main_dust.scale_amount_max = 2.0  # Much bigger scaling
	
	# Clean white dust
	main_dust.color = Color(1.0, 1.0, 1.0, 0.8)  # Pure white, less transparent
	
	# Physics with forward momentum decay
	main_dust.gravity = Vector2(0, 12)  # Slightly less gravity
	main_dust.linear_accel_min = -20.0  # More air resistance to slow forward momentum
	main_dust.linear_accel_max = -10.0
	
	print("Player: Created main dust cloud effect")

# Small dust puffs - quick bursts
func create_small_dust_puffs():
	var small_dust = CPUParticles2D.new()
	small_dust.name = "SmallDustPuffs"
	add_child(small_dust)
	
	# Position closer to player
	small_dust.position = Vector2(-4, 6)
	
	# Quick, small bursts
	small_dust.emitting = true
	small_dust.amount = 12
	small_dust.lifetime = 1.2
	small_dust.one_shot = false
	
	# Forward momentum with more upward spread
	small_dust.direction = Vector2(0.5, -0.7)  # Forward and up
	small_dust.spread = 50.0
	
	# Fast particles with forward momentum
	small_dust.initial_velocity_min = 40.0
	small_dust.initial_velocity_max = 80.0
	small_dust.angular_velocity_min = -15.0  # Less sparkly rotation
	small_dust.angular_velocity_max = 15.0
	
	# Smaller particles that still scale up nicely
	small_dust.scale_amount_min = 0.2
	small_dust.scale_amount_max = 1.5  # Bigger scaling
	
	# Clean white dust, slightly more transparent
	small_dust.color = Color(1.0, 1.0, 1.0, 0.6)
	
	# Less gravity for longer float time
	small_dust.gravity = Vector2(0, 6)
	small_dust.linear_accel_min = -25.0  # More air resistance
	small_dust.linear_accel_max = -15.0
	
	print("Player: Created small dust puffs effect")

# Ground debris - heavier particles that fall quickly
func create_ground_debris():
	var debris = CPUParticles2D.new()
	debris.name = "GroundDebris"
	add_child(debris)
	
	# Position at ground level
	debris.position = Vector2(-6, 10)
	
	# Sparse, heavier particles
	debris.emitting = true
	debris.amount = 6
	debris.lifetime = 1.5
	debris.one_shot = false
	
	# Forward momentum but heavier, so less upward
	debris.direction = Vector2(0.2, -0.1)  # Slight forward, minimal up
	debris.spread = 25.0
	
	# Heavier particles with some forward momentum
	debris.initial_velocity_min = 20.0
	debris.initial_velocity_max = 45.0
	debris.angular_velocity_min = -30.0  # Less sparkly
	debris.angular_velocity_max = 30.0
	
	# Chunkier particles that scale up
	debris.scale_amount_min = 0.6
	debris.scale_amount_max = 2.2  # Even bigger scaling
	
	# White but slightly gray for heavier chunks
	debris.color = Color(0.9, 0.9, 0.9, 0.9)  # Off-white
	
	# Strong gravity but with initial forward momentum
	debris.gravity = Vector2(0, 35)
	debris.linear_accel_min = -8.0  # Less air resistance for heavier particles
	debris.linear_accel_max = -2.0
	
	print("Player: Created ground debris effect")

# Stop the dust particle effect
func stop_slide_dust_effect():
	# Stop all dust particle systems
	var particle_systems = ["MainDustCloud", "SmallDustPuffs", "GroundDebris"]
	
	for system_name in particle_systems:
		var particles = get_node_or_null(system_name)
		if particles:
			particles.emitting = false
			print("Player: Stopped " + system_name)
	
	# Remove all systems after particles finish their lifetime
	await get_tree().create_timer(2.5).timeout
	
	for system_name in particle_systems:
		var particles = get_node_or_null(system_name)
		if particles and is_instance_valid(particles):
			particles.queue_free()
			print("Player: Removed " + system_name)
	
	print("Player: All slide dust effects cleaned up")
