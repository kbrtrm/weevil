extends ProgressBar

# Settings
@export var animate_changes: bool = true
@export var animation_duration: float = 0.3
@export var flash_on_damage: bool = true
@export var low_health_threshold: float = 0.3  # When to show low health color (30%)
@export var critical_health_threshold: float = 0.15  # When to show critical health color (15%)

# Color settings
@export var normal_color: Color = Color(0.886275, 0.294118, 0.294118, 1)  # Default red
@export var low_health_color: Color = Color(0.886275, 0.694118, 0.294118, 1)  # Orange-ish
@export var critical_health_color: Color = Color(0.886275, 0.1, 0.1, 1)  # Deep red
@export var damage_flash_color: Color = Color(1, 1, 1, 1)  # White flash

# Style references
var fill_style: StyleBoxFlat
var current_color_state: String = "normal"  # Keep track of current color state

# Initialization
func _ready():
	# Get the fill style
	fill_style = get("theme_override_styles/fill")
	
	if fill_style:
		# Store the initial normal color if not already set
		if normal_color == Color(0.886275, 0.294118, 0.294118, 1):  # If still default
			normal_color = fill_style.bg_color
	
	# Initial update
	update_color()

# Set current and max health
func set_health(current: int, maximum: int):
	max_value = maximum
	
	if animate_changes:
		# Create animation tween
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		
		# Flash effect for damage if enabled and health is decreasing
		if flash_on_damage and current < value:
			if fill_style:
				# Store the current color before flashing
				var current_color = fill_style.bg_color
				
				# Quick white flash
				fill_style.bg_color = damage_flash_color
				
				# Return to the proper color based on new health
				var health_percent = float(current) / float(maximum)
				var target_color
				
				if health_percent <= critical_health_threshold:
					target_color = critical_health_color
				elif health_percent <= low_health_threshold:
					target_color = low_health_color
				else:
					target_color = normal_color
					
				tween.tween_property(fill_style, "bg_color", target_color, 0.1)
		
		# Animate health change
		tween.tween_property(self, "value", current, animation_duration)
		tween.tween_callback(func(): update_color())
	else:
		# Immediate change
		value = current
		update_color()

# Update the color based on current health percentage
func update_color():
	if not fill_style:
		return
		
	var health_percent = value / max_value
	var new_color_state = "normal"
	
	if health_percent <= critical_health_threshold:
		fill_style.bg_color = critical_health_color
		new_color_state = "critical"
	elif health_percent <= low_health_threshold:
		fill_style.bg_color = low_health_color
		new_color_state = "low"
	else:
		fill_style.bg_color = normal_color
		new_color_state = "normal"
	
	# Update the current color state
	current_color_state = new_color_state
