# TargetHighlight.gd - Simple modulate version
extends Node2D
class_name TargetHighlightSimple

var target_sprite: Sprite2D
var original_modulate: Color

func setup_target(sprite: Sprite2D):
	target_sprite = sprite
	if target_sprite:
		# Store original modulate color
		original_modulate = target_sprite.modulate

func show_outline(color: Color = Color.WHITE, width: float = 2.0):
	if target_sprite:
		# Create a strong color tint effect
		var highlight_color = Color.WHITE.lerp(color, 0.8)
		highlight_color.a = 1.0
		target_sprite.modulate = highlight_color

func hide_outline():
	if target_sprite:
		target_sprite.modulate = original_modulate

func cleanup():
	if target_sprite:
		target_sprite.modulate = original_modulate
	target_sprite = null
