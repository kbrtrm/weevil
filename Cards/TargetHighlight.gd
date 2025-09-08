# TargetHighlight.gd - Fixed to avoid parse errors
extends Node2D
class_name TargetHighlightFixed

# Legacy class - functionality moved to OutlineComponent
func setup_target(sprite):
	pass

func show_outline(color: Color = Color.WHITE, width: float = 2.0):
	pass

func hide_outline():
	pass

func cleanup():
	pass
