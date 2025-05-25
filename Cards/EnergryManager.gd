# EnergyManager.gd
extends Node2D

signal energy_changed(current, max_energy)
signal insufficient_energy

# Energy settings
@export var max_energy: int = 3
@export var energy_per_turn: int = 3
var current_energy: int = max_energy

# UI elements
@onready var energy_label = $"Energy-medallion/Energy"

func _ready():
	# Initialize energy display
	current_energy = max_energy
	update_display()

# Add energy
func add_energy(amount: int):
	current_energy = min(current_energy + amount, max_energy)
	update_display()
	emit_signal("energy_changed", current_energy, max_energy)

# Use energy
func use_energy(amount: int) -> bool:
	if current_energy >= amount:
		current_energy -= amount
		update_display()
		
		# Play skew animation when energy is successfully used
		play_energy_used_effect()
		
		emit_signal("energy_changed", current_energy, max_energy)
		return true
	else:
		# Not enough energy!
		emit_signal("insufficient_energy")
		# Play insufficient energy effect
		play_insufficient_energy_effect()
		return false

# Start a new turn
func new_turn():
	current_energy = energy_per_turn
	update_display()
	emit_signal("energy_changed", current_energy, max_energy)

# Check if a card can be played
func can_play_card(cost: int) -> bool:
	return current_energy >= cost

# Update the energy display
func update_display():
	if energy_label:
		energy_label.text = str(current_energy) + "/" + str(max_energy)

# Play insufficient energy effect
func play_insufficient_energy_effect():
	# Shake the energy display
	var original_pos = position
	var tween = create_tween()
	tween.tween_property(self, "position", position + Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", position - Vector2(5, 0), 0.05)
	tween.tween_property(self, "position", original_pos, 0.05)
	
	# Flash the energy label red
	if energy_label:
		var original_color = energy_label.modulate
		tween.parallel().tween_property(energy_label, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.1)
		tween.tween_property(energy_label, "modulate", original_color, 0.1)

# Play skew animation when energy is used
func play_energy_used_effect():
	# Get the energy medallion node for the skew effect
	var energy_medallion = $"Energy-medallion"
	
	if energy_medallion:
		# Store original transform
		var original_skew = energy_medallion.skew
		
		# Create skew animation
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		
		# Skew left slightly, then return to normal
		tween.tween_property(energy_medallion, "skew", -0.15, 0.1)
		tween.tween_property(energy_medallion, "skew", original_skew, 0.2)
		
		# Optional: Add a slight scale pulse too
		var original_scale = energy_medallion.scale
		tween.parallel().tween_property(energy_medallion, "scale", original_scale * 0.95, 0.1)
		tween.tween_property(energy_medallion, "scale", original_scale, 0.2)
