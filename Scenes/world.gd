extends Node2D

@onready var player = $YSort/Player
@onready var reflection_texture = $YSort/Player/Reflection2
	
# Called when the node enters the scene tree for the first time.
func _ready():
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_door_body_entered(body):
#	load_scene()
	if body == player: 
		SceneManager.change_scene("res://Scenes/InsidePot.tscn", { "pattern": "fade", "speed": 4})
