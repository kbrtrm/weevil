extends Camera2D

@onready var topLeft = $Limits/TopLeft
@onready var bottomRight = $Limits/BottomRight

func _ready():
	limit_top = topLeft.position.y
	limit_left = topLeft.position.x
	limit_bottom = bottomRight.position.y
	limit_right = bottomRight.position.x

##ZOOM CAMERA IN AND OUT ON BODY ENTER
#func _on_zoom_area_body_entered(_player):
	#var tween = get_tree().create_tween()
	#tween.tween_property(self, "zoom", Vector2(2.5, 2.5), .75)
##
#func _on_zoom_area_body_exited(_player):
	#var tween = get_tree().create_tween()
	#tween.tween_property(self, "zoom", Vector2(1.5,1.5), 1)
#
#
#func _on_zoom_area_2_body_entered(body):
#	var tween = get_tree().create_tween()
#	tween.tween_property(self, "zoom", Vector2(1.0, 1.0), .75)
#
#func _on_zoom_area_2_body_exited(body):
#	var tween = get_tree().create_tween()
#	tween.tween_property(self, "zoom", Vector2(1.5,1.5), 1)
