# TargetHighlightSprite.gd - Animated sprite outline approach
extends Node2D
class_name TargetHighlightSprite

var target_sprite: Sprite2D
var outline_sprites: Array = []
var pulse_tween: Tween

func setup_target(sprite: Sprite2D):
	print("TargetHighlightSprite: setup_target called for: ", sprite.name)
	target_sprite = sprite
	if target_sprite and target_sprite.texture:
		create_outline_sprites()

func create_outline_sprites():
	# Create 4 outline sprites positioned around the target
	var texture_size = target_sprite.texture.get_size()
	var scale = target_sprite.scale
	var actual_size = texture_size * scale
	
	# Outline thickness
	var thickness = 4.0
	var gap = 2.0  # Small gap between sprite and outline
	
	# Create top outline
	var top_outline = create_outline_rect(Vector2(actual_size.x + thickness * 2, thickness))
	top_outline.position = Vector2(-thickness, -actual_size.y/2 - gap - thickness)
	
	# Create bottom outline  
	var bottom_outline = create_outline_rect(Vector2(actual_size.x + thickness * 2, thickness))
	bottom_outline.position = Vector2(-thickness, actual_size.y/2 + gap)
	
	# Create left outline
	var left_outline = create_outline_rect(Vector2(thickness, actual_size.y + gap * 2))
	left_outline.position = Vector2(-actual_size.x/2 - gap - thickness, -gap)
	
	# Create right outline
	var right_outline = create_outline_rect(Vector2(thickness, actual_size.y + gap * 2))
	right_outline.position = Vector2(actual_size.x/2 + gap, -gap)
	
	outline_sprites = [top_outline, bottom_outline, left_outline, right_outline]
	
	# Add to target sprite's parent so they move together
	var parent = target_sprite.get_parent()
	for outline in outline_sprites:
		parent.add_child(outline)
		outline.global_position = target_sprite.global_position + outline.position
		outline.z_index = target_sprite.z_index + 1
		outline.visible = false
	
	print("TargetHighlightSprite: Created 4 outline sprites around target")

func create_outline_rect(size: Vector2) -> ColorRect:
	var rect = ColorRect.new()
	rect.size = size
	rect.color = Color.WHITE
	return rect

func show_outline(color: Color = Color.WHITE, width: float = 4.0):
	print("TargetHighlightSprite: show_outline called with color: ", color)
	
	if outline_sprites.size() == 0:
		print("TargetHighlightSprite: No outline sprites created")
		return
	
	# Update color and make visible
	for outline in outline_sprites:
		outline.color = color
		outline.visible = true
	
	# Start pulsing animation
	start_pulse_animation()
	print("TargetHighlightSprite: Outline sprites made visible and pulsing")

func start_pulse_animation():
	if pulse_tween:
		pulse_tween.kill()
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse the opacity for a breathing effect
	for outline in outline_sprites:
		pulse_tween.parallel().tween_property(outline, "modulate:a", 0.7, 0.8)
	
	pulse_tween.tween_callback(func():
		for outline in outline_sprites:
			pulse_tween.parallel().tween_property(outline, "modulate:a", 1.0, 0.8)
	)

func hide_outline():
	for outline in outline_sprites:
		outline.visible = false
	
	if pulse_tween:
		pulse_tween.kill()

func cleanup():
	for outline in outline_sprites:
		if outline:
			outline.queue_free()
	outline_sprites.clear()
	
	if pulse_tween:
		pulse_tween.kill()
	
	target_sprite = null
