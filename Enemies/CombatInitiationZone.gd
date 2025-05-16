extends Area2D

var player = null

func player_in_combat_zone():
	return player != null

func _on_body_entered(body):
	print("Body entered combat zone: " + body.name)
	print("Body is in player group: " + str(body.is_in_group("player")))
	
	# Check if the body is in the "player" group
	if body.is_in_group("player"):
		print("PLAYER DETECTED IN COMBAT ZONE!")
		player = body
	else:
		print("Body doesn't seem to be in the player group.")

func _on_body_exited(body):
	if body == player:
		print("Player exited combat zone")
		player = null
