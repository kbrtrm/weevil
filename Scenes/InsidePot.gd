extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	var player = $YSort/Player
	var animtree = $YSort/Player/AnimationTree
	var animstate = animtree.get("parameters/playback")
	animtree.set("parameters/Idle/blend_position", Vector2(0, -1))
#	animstate.travel("Idle")
	
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _on_door_body_entered(player):
	get_tree().change_scene_to_file("res://Scenes/world.tscn")
