extends Panel  # Change to Panel

var dragging = false
var drag_offset = Vector2()

func _ready():
	# Panels handle drawing automatically
	custom_minimum_size = Vector2(100, 100)
	
	# Make it visibly stand out
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.5, 0.8, 0.7)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	add_theme_stylebox_override("panel", style)
	
	# Critical input settings
	mouse_filter = Control.MOUSE_FILTER_STOP

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var rect = get_global_rect()
		var in_bounds = rect.has_point(event.global_position)
		
		if event.pressed and in_bounds:
			print("Panel clicked")
			dragging = true
			drag_offset = event.global_position - global_position
		elif dragging:
			dragging = false
	
	if dragging and event is InputEventMouseMotion:
		global_position = event.global_position - drag_offset
