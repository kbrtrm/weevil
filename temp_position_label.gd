# temp_position_label.gd
extends Label

func _process(_delta):
	var player = get_parent().get_parent()
	text = str(player.global_position.x).pad_decimals(1) + ", " + str(player.global_position.y).pad_decimals(1)
