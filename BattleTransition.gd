extends CanvasLayer

signal transition_completed
signal transition_halfway

@onready var color_rect = $ColorRect

# Add a Timer node as a member variable
var timer: Timer
var transition_debug = true  # Set to true for debug prints

func _ready():
	# Create a reusable timer
	timer = Timer.new()
	add_child(timer)
	timer.one_shot = true
	
	# Make sure we're on top of everything
	layer = 100
	
	if transition_debug:
		print("BattleTransition: Ready")

# Safe timer function
func wait(seconds: float):
	if transition_debug:
		print("BattleTransition: Waiting for " + str(seconds) + " seconds")
	timer.wait_time = seconds
	timer.start()
	await timer.timeout

# Call this to start fading in (from black to clear)
func fade_in(duration = 0.5):
	if transition_debug:
		print("BattleTransition: Starting fade_in")
	
	# Start with black
	color_rect.color = Color(0, 0, 0, 1)
	
	# Create tween for fade in
	var tween = create_tween()
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 0), duration)
	
	# Wait for tween to complete
	await tween.finished
	
	if transition_debug:
		print("BattleTransition: fade_in completed")
	
	emit_signal("transition_completed")

# Call this to start fading out (from clear to black)
func fade_out(duration = 0.5):
	if transition_debug:
		print("BattleTransition: Starting fade_out")
	
	# Start with transparent
	color_rect.color = Color(0, 0, 0, 0)
	
	# Create tween for fade out
	var tween = create_tween()
	tween.tween_property(color_rect, "color", Color(0, 0, 0, 1), duration)
	
	# Signal when halfway through (screen is half black)
	timer.wait_time = duration / 2.0
	timer.start()
	await timer.timeout
	
	if transition_debug:
		print("BattleTransition: fade_out halfway")
	
	emit_signal("transition_halfway")
	
	# Wait for tween to complete
	await tween.finished
	
	if transition_debug:
		print("BattleTransition: fade_out completed")
	
	emit_signal("transition_completed")

# Other functions remain the same...
