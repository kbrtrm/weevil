extends Node2D

signal hovered
signal hovered_off

var position_in_hand: Vector2

func _ready():
	pass
	# CARD NEEDS TO BE CHILD OF CARDMANAGER
	#get_parent().connect_card_signals(self)

func _on_collision_area_mouse_entered() -> void:
	emit_signal("hovered", self)
	
func _on_collision_area_mouse_exited() -> void:
	emit_signal("hovered_off", self)
