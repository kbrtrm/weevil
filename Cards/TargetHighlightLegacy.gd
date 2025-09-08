# TargetHighlight.gd - Minimal version to avoid conflicts
extends Node2D
class_name TargetHighlightLegacy

# This is a legacy file - use OutlineComponent instead
func setup_target(sprite):
	pass

func show_outline(color: Color = Color.WHITE, width: float = 2.0):
	pass

func hide_outline():
	pass

func cleanup():
	pass
