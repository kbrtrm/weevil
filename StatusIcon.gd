# StatusIcon.gd
extends Control

@onready var label = $Label
const CUSTOM_FONT = preload("res://Themes/Tiny Click2.ttf")

# Store data if setup_status is called before _ready
var pending_status_name: String = ""
var pending_amount: int = 0
var pending_color: Color = Color.WHITE

# Called when the node enters the scene tree
func _ready():
	# Set up the label with custom font
	if label and CUSTOM_FONT:
		label.add_theme_font_override("normal_font", CUSTOM_FONT)
		label.add_theme_font_size_override("font_size", 8)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	
	# Set up the control node
	custom_minimum_size = Vector2(40, 25)
	
	# Apply pending status if it was set before _ready
	if pending_status_name != "":
		apply_status_to_label(pending_status_name, pending_amount, pending_color)

# Set the status icon data
func setup_status(status_name: String, amount: int, color: Color):
	if label and is_inside_tree():
		# Label is ready, apply immediately
		apply_status_to_label(status_name, amount, color)
	else:
		# Label not ready yet, store for later
		pending_status_name = status_name
		pending_amount = amount
		pending_color = color

# Apply the status data to the label
func apply_status_to_label(status_name: String, amount: int, color: Color):
	if label:
		label.text = status_name.capitalize() + "\n" + str(amount)
		label.add_theme_color_override("font_color", color)
		print("StatusIcon: Set text to: ", label.text)  # Debug print
	
	# Optional: Add background or border based on status type
	add_background_for_status(status_name, color)

# Optional: Add visual styling based on status type
func add_background_for_status(status_name: String, color: Color):
	# Create a subtle background panel
	var panel = Panel.new()
	add_child(panel)
	move_child(panel, 0)  # Put panel behind label
	
	# Style the panel
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(color.r, color.g, color.b, 0.2)  # Semi-transparent
	style_box.border_width_left = 1
	style_box.border_width_right = 1
	style_box.border_width_top = 1
	style_box.border_width_bottom = 1
	style_box.border_color = color
	style_box.corner_radius_top_left = 3
	style_box.corner_radius_top_right = 3
	style_box.corner_radius_bottom_left = 3
	style_box.corner_radius_bottom_right = 3
	
	panel.add_theme_stylebox_override("panel", style_box)
	
	# Make panel fill the control
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

# Animate the status icon (for when status changes)
func animate_update():
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Scale up slightly then back to normal
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1)

# Optional: Add pulsing effect for temporary status effects
func start_pulse_effect():
	var tween = create_tween()
	tween.set_loops()  # Loop forever
	tween.tween_property(self, "modulate", Color(1.2, 1.2, 1.2, 1.0), 0.5)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.5)

func stop_pulse_effect():
	# Stop any running tweens
	var tweens = get_tree().get_processed_tweens()
	for tween in tweens:
		if tween.get_object() == self:
			tween.kill()
	
	# Reset modulate
	modulate = Color(1.0, 1.0, 1.0, 1.0)
