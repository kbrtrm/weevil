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
var is_player: bool = false  # Flag to identify if this is the player's health bar

# Initialization
func _ready():
	# CRITICAL FIX: Make a unique copy of the StyleBoxFlat resource
	# This ensures each health bar has its own independent style
	var original_style = get("theme_override_styles/fill")
	if original_style:
		# Create a fresh duplicate of the style
		fill_style = original_style.duplicate()
		# Apply the duplicated style back to the progress bar
		set("theme_override_styles/fill", fill_style)
		
		# Store the initial normal color
		normal_color = fill_style.bg_color
	
	# Determine if this is a player health bar by checking parent
	var parent = get_parent()
	if parent and parent.is_in_group("player"):
		is_player = true
	
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
			# Only flash if this is NOT a player health bar or if it's the player's turn
			var battle_manager = find_battle_manager()
			var is_player_turn = true  # Default assumption
			
			if battle_manager and "is_player_turn" in battle_manager:
				is_player_turn = battle_manager.is_player_turn
			
			# Flash enemy bar when player's turn, flash player bar when enemy's turn
			var should_flash = (is_player and not is_player_turn) or (not is_player and is_player_turn)
			
			if should_flash and fill_style:
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

# Helper function to find the battle manager
func find_battle_manager():
	var node = self
	while node:
		if node.has_method("get_enemy") and node.has_method("get_player"):
			return node
		node = node.get_parent()
	return null

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
