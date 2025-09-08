# TargetHighlightGlow.gd - Simple glow effect that definitely works
extends Node2D
class_name TargetHighlightGlow

var target_sprite: Sprite2D
var original_modulate: Color
var glow_tween: Tween

func setup_target(sprite: Sprite2D):
	print("TargetHighlightGlow: setup_target called")
	target_sprite = sprite
	if target_sprite:
		# Store original modulate
		original_modulate = target_sprite.modulate
		print("TargetHighlightGlow: Target sprite found, original modulate: ", original_modulate)

func show_outline(color: Color = Color.WHITE, width: float = 4.0):
	print("TargetHighlightGlow: show_outline called with color: ", color)
	if not target_sprite:
		print("TargetHighlightGlow: ERROR - No target sprite")
		return
	
	# Stop any existing tween
	if glow_tween:
		glow_tween.kill()
	
	# Create a pulsing glow effect
	glow_tween = create_tween()
	glow_tween.set_loops()
	
	# Brighten the sprite with the target color
	var glow_color = original_modulate.lerp(color, 0.8)
	glow_color = glow_color * 1.3  # Make it brighter
	
	# Pulsing animation
	glow_tween.tween_property(target_sprite, "modulate", glow_color, 0.5)
	glow_tween.tween_property(target_sprite, "modulate", original_modulate.lerp(color, 0.4), 0.5)
	
	print("TargetHighlightGlow: Glow effect applied")

func hide_outline():
	if glow_tween:
		glow_tween.kill()
	if target_sprite:
		target_sprite.modulate = original_modulate

func cleanup():
	if glow_tween:
		glow_tween.kill()
	if target_sprite:
		target_sprite.modulate = original_modulate
	target_sprite = null
