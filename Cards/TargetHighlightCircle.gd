# TargetHighlightCircle.gd - Glowing circle approach
extends Node2D
class_name TargetHighlightCircle

var target_sprite: Sprite2D
var circle_sprite: Sprite2D
var pulse_tween: Tween

func setup_target(sprite: Sprite2D):
	print("TargetHighlightCircle: setup_target called for: ", sprite.name)
	target_sprite = sprite
	if target_sprite:
		create_circle_outline()

func create_circle_outline():
	# Create a simple circle texture programmatically
	var circle_texture = ImageTexture.new()
	var image = Image.create(128, 128, false, Image.FORMAT_RGBA8)
	
	# Draw a circle outline
	var center = Vector2(64, 64)
	var radius = 60
	var thickness = 8
	
	for x in range(128):
		for y in range(128):
			var dist = Vector2(x, y).distance_to(center)
			if dist >= radius - thickness and dist <= radius:
				image.set_pixel(x, y, Color.WHITE)
			else:
				image.set_pixel(x, y, Color.TRANSPARENT)
	
	circle_texture.set_image(image)
	
	# Create sprite with circle texture
	circle_sprite = Sprite2D.new()
	circle_sprite.texture = circle_texture
	circle_sprite.modulate = Color.WHITE
	circle_sprite.visible = false
	
	# Add to target's parent and position it
	var parent = target_sprite.get_parent()
	parent.add_child(circle_sprite)
	circle_sprite.global_position = target_sprite.global_position
	circle_sprite.z_index = target_sprite.z_index - 1  # Behind the sprite
	
	print("TargetHighlightCircle: Created circle outline around target")

func show_outline(color: Color = Color.WHITE, width: float = 4.0):
	print("TargetHighlightCircle: show_outline called with color: ", color)
	
	if not circle_sprite:
		print("TargetHighlightCircle: No circle sprite created")
		return
	
	# Update color and make visible
	circle_sprite.modulate = color
	circle_sprite.visible = true
	
	# Start pulsing/rotating animation
	start_animations()
	print("TargetHighlightCircle: Circle outline made visible")

func start_animations():
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulsing scale effect
	pulse_tween.parallel().tween_property(circle_sprite, "scale", Vector2(1.2, 1.2), 1.0)
	pulse_tween.parallel().tween_property(circle_sprite, "modulate:a", 0.6, 1.0)
	
	pulse_tween.tween_callback(func():
		pulse_tween.parallel().tween_property(circle_sprite, "scale", Vector2(1.0, 1.0), 1.0)
		pulse_tween.parallel().tween_property(circle_sprite, "modulate:a", 1.0, 1.0)
	)
	
	# Continuous rotation
	var rotate_tween = create_tween()
	rotate_tween.set_loops()
	rotate_tween.tween_property(circle_sprite, "rotation", TAU, 3.0)

func hide_outline():
	if circle_sprite:
		circle_sprite.visible = false
	
	if pulse_tween:
		pulse_tween.kill()

func cleanup():
	if circle_sprite:
		circle_sprite.queue_free()
		circle_sprite = null
	
	if pulse_tween:
		pulse_tween.kill()
	
	target_sprite = null
