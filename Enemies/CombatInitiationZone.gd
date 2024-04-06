extends Area2D

var player = null

func player_in_combat_zone():
	return player !=null

func _on_body_entered(body):
	print("fight!")
	player = body

func _on_body_exited(body):
	player = null
