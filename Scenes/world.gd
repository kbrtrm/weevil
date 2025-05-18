extends Node2D

@onready var player = $YSort/Player
	
# Called when the node enters the scene tree for the first time.
func _ready():
	# Wait until the next frame to ensure all nodes are loaded
	await get_tree().process_frame
	
	# Handle player spawn if needed
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		if global.next_spawn_point != "":
			print("world._ready: Calling handle_player_spawn for: " + global.next_spawn_point)
			global.handle_player_spawn()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
