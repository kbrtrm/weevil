extends AnimatedSprite2D

func _ready():
	self.animation_finished.connect(_on_animated_sprite_2d_animation_finished)
	play("animate")
	
func _on_animated_sprite_2d_animation_finished():
	queue_free()
