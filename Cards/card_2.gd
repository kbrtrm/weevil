# card_2.gd
extends Node2D

const CARD_SIZE = Vector2(90, 124)

@export var card_cost: int = 1
@export var card_name: String = ""
@export_multiline var card_desc: String = ""
@export var card_art: Texture2D = null

# References to nodes
var cost_label: Label
var name_label: Label
var description_label: RichTextLabel
var art_texture: TextureRect

# Drag and drop state
var draggable = true
var being_dragged = false
var original_position = Vector2.ZERO
var original_rotation = 0.0
var original_z_index = 0
var drag_offset = Vector2.ZERO

@onready var hover_highlight = $Panel/HoverHighlight

# Called when the node enters the scene tree
func _ready() -> void:
	center_pivot()
	
	# Get references to nodes
	cost_label = find_child("Cost")
	name_label = find_child("Name")
	description_label = find_child("RichTextLabel")
	art_texture = find_child("CardArt")
	
	# Set properties
	if cost_label:
		cost_label.text = str(card_cost)
	if name_label:
		name_label.text = card_name
	if description_label:
		description_label.text = card_desc
	if art_texture and card_art:
		art_texture.texture = card_art
	
	# Make sure Area2D is pickable
	var area = $Panel/Area2D
	if area:
		area.input_pickable = true

# Center the pivot point
func center_pivot():
	var half_size = CARD_SIZE / 2
	for child in get_children():
		child.position -= half_size

# Hover effect
func set_highlight(state: bool):
	if hover_highlight:
		hover_highlight.visible = state

# Called when mouse enters the card
func _on_area_2d_mouse_entered():
	# Only highlight if not currently dragging
	if not being_dragged:
		set_highlight(true)
		
		# Notify hand about hover
		var hand = get_parent()
		if hand and hand.has_method("on_card_hovered"):
			hand.on_card_hovered(self)

# Called when mouse exits the card
func _on_area_2d_mouse_exited():
	# Only turn off highlight if not being dragged
	if not being_dragged:
		set_highlight(false)
		
		# Notify hand about hover end
		var hand = get_parent()
		if hand and hand.has_method("on_card_unhovered"):
			hand.on_card_unhovered(self)

# Start dragging the card
func start_drag():
	if not draggable:
		return
		
	# Store original state
	original_position = global_position
	original_rotation = rotation
	original_z_index = z_index
	
	# Set up dragging state
	being_dragged = true
	z_index = 1000
	drag_offset = get_global_mouse_position() - global_position
	
	# Show highlight during drag
	set_highlight(true)
	
	# Notify hand about drag start
	var hand = get_parent()
	if hand and hand.has_method("on_card_drag_started"):
		hand.on_card_drag_started(self)

# Stop dragging and handle drop
func end_drag():
	being_dragged = false
	
	# Notify hand about drag end
	var hand = get_parent()
	if hand and hand.has_method("on_card_drag_ended"):
		hand.on_card_drag_ended(self, get_global_mouse_position())
	else:
		# If no handler, just return to original position
		global_position = original_position
		rotation = original_rotation
		z_index = original_z_index
		set_highlight(false)

# Update position while dragging
func _process(delta):
	if being_dragged:
		global_position = get_global_mouse_position() - drag_offset
		rotation_degrees = 0  # Keep card upright while dragging

# Card effect when played
func play_effect():
	print("Playing card: ", card_name)
	
	# Get card data from the database
	var card_data = CardDatabase.get_card_by_name(card_name)
	
	if not card_data:
		print("Warning: Card data not found for: ", card_name)
		return
	
	# Find the battle scene/manager to apply effects
	var battle_manager = find_battle_manager()
	
	if battle_manager:
		# Apply each effect in sequence
		if "effects" in card_data:
			for effect in card_data.effects:
				apply_effect(battle_manager, effect)
	else:
		print("Warning: Could not find battle manager to apply card effects")
		
# Find the battle manager to apply effects
func find_battle_manager():
	# Look for the battle manager in the scene
	var node = self
	while node and not node.has_method("get_enemy"):
		node = node.get_parent()
	
	return node
	
# Apply a specific effect from the JSON data
func apply_effect(battle_manager, effect_data):
	# Get needed references based on target
	var target_node = null
	
	match effect_data.target:
		"enemy":
			target_node = battle_manager.get_enemy()
		"player":
			target_node = battle_manager.get_player()
		"all_enemies":
			# Handle area effects later
			pass
		_:
			print("Warning: Unknown target type: ", effect_data.target)
			return
	
	if not target_node:
		print("Warning: Target node not found for effect: ", effect_data.type)
		return
	
	# Apply the effect based on type
	var effect_type = effect_data.type
	var value = effect_data.value
	
	match effect_type:
		"damage":
			apply_damage_effect(target_node, value)
		"block":
			apply_block_effect(target_node, value)
		"weak":
			apply_weak_effect(target_node, value)
		"vulnerable":
			apply_vulnerable_effect(target_node, value)
		"heal":
			apply_heal_effect(target_node, value)
		"draw":
			apply_draw_effect(battle_manager, value)
		"bleed":
			apply_bleed_effect(target_node, value)
		_:
			print("Warning: Unknown effect type: ", effect_type)

# Apply damage to a target
func apply_damage_effect(target, amount):
	if target.has_method("take_damage"):
		# Create damage effect
		create_damage_effect(target.global_position, amount)
		
		# Apply the actual damage
		target.take_damage(amount)
	else:
		print("Warning: Target cannot take damage")

# Apply block/defense to a target
func apply_block_effect(target, amount):
	if target.has_method("add_block"):
		# Create block effect
		create_block_effect(target.global_position, amount)
		
		# Apply the actual block
		target.add_block(amount)
	else:
		print("Warning: Target cannot receive block")

# Apply weak effect to a target
func apply_weak_effect(target, amount):
	if target.has_method("add_weak"):
		# Create status effect visual
		create_status_effect(target.global_position, "weak", amount)
		
		# Apply the actual status
		target.add_weak(amount)
	else:
		print("Warning: Target cannot be weakened")

# Apply vulnerable effect to a target
func apply_vulnerable_effect(target, amount):
	if target.has_method("add_vulnerable"):
		# Create status effect visual
		create_status_effect(target.global_position, "vulnerable", amount)
		
		# Apply the actual status
		target.add_vulnerable(amount)
	else:
		print("Warning: Target cannot be made vulnerable")

# Apply healing to a target
func apply_heal_effect(target, amount):
	if target.has_method("heal"):
		# Create healing effect
		create_heal_effect(target.global_position, amount)
		
		# Apply the actual healing
		target.heal(amount)
	else:
		print("Warning: Target cannot be healed")

# Apply draw card effect
func apply_draw_effect(battle_manager, amount):
	# Find the hand manager
	var hand = battle_manager.get_node_or_null("Hand")
	
	if hand and hand.has_method("draw_card"):
		# Create effect text
		create_draw_effect(hand.global_position, amount)
		
		# Draw the cards
		hand.draw_card(amount)
	else:
		print("Warning: Cannot draw cards")

# Apply bleed status to a target
func apply_bleed_effect(target, amount):
	if target.has_method("add_bleed"):
		# Create status effect visual
		create_status_effect(target.global_position, "bleed", amount)
		
		# Apply the actual status
		target.add_bleed(amount)
	else:
		print("Warning: Target cannot bleed")
		
		
# Add new visual effect for drawing cards
func create_draw_effect(position, amount):
	# Create draw number popup
	var draw_popup = Label.new()
	draw_popup.text = "Draw " + str(amount) + " card" + ("s" if amount > 1 else "")
	draw_popup.add_theme_color_override("font_color", Color(0.9, 0.9, 0.2))
	draw_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(draw_popup)
	draw_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(draw_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(draw_popup, "modulate", Color(0.9, 0.9, 0.2, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): draw_popup.queue_free())
	
# Add these functions to card_2.gd

# Create visual effects for damage
func create_damage_effect(position, amount):
	# Create damage number popup
	var damage_popup = Label.new()
	damage_popup.text = str(amount)
	damage_popup.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	damage_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(damage_popup)
	damage_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(damage_popup, "modulate", Color(1, 0.3, 0.3, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): damage_popup.queue_free())

# Create visual effects for block
func create_block_effect(position, amount):
	# Create block number popup
	var block_popup = Label.new()
	block_popup.text = "+" + str(amount) + " Block"
	block_popup.add_theme_color_override("font_color", Color(0.2, 0.6, 1.0))
	block_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(block_popup)
	block_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(block_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(block_popup, "modulate", Color(0.2, 0.6, 1.0, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): block_popup.queue_free())

# Create visual effects for status effects (weak, vulnerable, etc.)
func create_status_effect(position, status_type, amount):
	# Create status effect popup
	var status_popup = Label.new()
	var color = Color.WHITE
	
	match status_type:
		"weak":
			status_popup.text = "+" + str(amount) + " Weak"
			color = Color(0.7, 0.3, 0.7)  # Purple
		"vulnerable":
			status_popup.text = "+" + str(amount) + " Vulnerable"
			color = Color(1.0, 0.5, 0.1)  # Orange
		"bleed":
			status_popup.text = "+" + str(amount) + " Bleed"
			color = Color(0.9, 0.1, 0.1)  # Dark red
		"poison":
			status_popup.text = "+" + str(amount) + " Poison"
			color = Color(0.2, 0.8, 0.4)  # Green
		"strength":
			status_popup.text = "+" + str(amount) + " Strength"
			color = Color(0.9, 0.1, 0.3)  # Red
		"dexterity":
			status_popup.text = "+" + str(amount) + " Dexterity"
			color = Color(0.1, 0.8, 0.3)  # Green
		_:
			# Default for any other status effects
			status_popup.text = "+" + str(amount) + " " + status_type.capitalize()
			color = Color(0.8, 0.8, 0.2)  # Yellow
	
	status_popup.add_theme_color_override("font_color", color)
	status_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(status_popup)
	status_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(status_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(status_popup, "modulate", Color(color.r, color.g, color.b, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): status_popup.queue_free())

# Create visual effects for healing
func create_heal_effect(position, amount):
	# Create heal number popup
	var heal_popup = Label.new()
	heal_popup.text = "+" + str(amount) + " HP"
	heal_popup.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	heal_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(heal_popup)
	heal_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(heal_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(heal_popup, "modulate", Color(0.2, 0.8, 0.2, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): heal_popup.queue_free())

# Create visual effect for gaining energy
func create_energy_effect(position, amount):
	# Create energy number popup
	var energy_popup = Label.new()
	energy_popup.text = "+" + str(amount) + " Energy"
	energy_popup.add_theme_color_override("font_color", Color(0.9, 0.7, 0.1))
	energy_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(energy_popup)
	energy_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(energy_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(energy_popup, "modulate", Color(0.9, 0.7, 0.1, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): energy_popup.queue_free())

# Create a more dramatic effect for critical hits or special attacks
func create_critical_hit_effect(position, amount):
	# Create critical hit popup with larger font and shaking animation
	var crit_popup = Label.new()
	crit_popup.text = str(amount) + "!"
	crit_popup.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	crit_popup.add_theme_font_size_override("font_size", 24)
	
	# Add to scene
	get_tree().root.add_child(crit_popup)
	crit_popup.global_position = position + Vector2(0, -20)
	
	# Create a more complex animation sequence
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# First grow slightly
	tween.tween_property(crit_popup, "scale", Vector2(1.2, 1.2), 0.1)
	
	# Then shake left and right while moving up
	tween.tween_property(crit_popup, "position", crit_popup.position + Vector2(5, -10), 0.05)
	tween.tween_property(crit_popup, "position", crit_popup.position + Vector2(-5, -20), 0.05)
	tween.tween_property(crit_popup, "position", crit_popup.position + Vector2(5, -30), 0.05)
	tween.tween_property(crit_popup, "position", crit_popup.position + Vector2(-5, -40), 0.05)
	
	# Finally fade out
	tween.tween_property(crit_popup, "modulate", Color(1, 0.1, 0.1, 0), 0.2)
	
	# Remove after animation
	tween.tween_callback(func(): crit_popup.queue_free())

# Create a text effect for "Not enough energy" or other error messages
func create_error_message(position, message):
	# Create error popup
	var error_popup = Label.new()
	error_popup.text = message
	error_popup.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	error_popup.add_theme_font_size_override("font_size", 16)
	
	# Add to scene
	get_tree().root.add_child(error_popup)
	error_popup.global_position = position + Vector2(0, -20)
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(error_popup, "global_position", position + Vector2(0, -40), 0.5)
	tween.parallel().tween_property(error_popup, "modulate", Color(1, 0.5, 0.5, 0), 0.5)
	
# Create a particle effect for special abilities
func create_particle_effect(position, effect_type):
	# In a more advanced implementation, you would create actual particles
	# For now, just create a text indicator as a placeholder
	var effect_popup = Label.new()
	
	match effect_type:
		"fire":
			effect_popup.text = "🔥"
		"lightning":
			effect_popup.text = "⚡"
		"magic":
			effect_popup.text = "✨"
		"explosion":
			effect_popup.text = "💥"
		_:
			effect_popup.text = "✨"
	
	effect_popup.add_theme_font_size_override("font_size", 32)
	
	# Add to scene
	get_tree().root.add_child(effect_popup)
	effect_popup.global_position = position
	
	# Animate
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Expand and fade
	tween.tween_property(effect_popup, "scale", Vector2(2, 2), 0.5)
	tween.parallel().tween_property(effect_popup, "modulate", Color(1, 1, 1, 0), 0.5)
	
	# Remove after animation
	tween.tween_callback(func(): effect_popup.queue_free())
	
