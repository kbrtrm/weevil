extends Node2D

signal hovered
signal hovered_off

var position_in_hand: Vector2

@onready var highlight = $Highlight  # Reference to a child node for the highlight effect

func _ready():
	pass
	# CARD NEEDS TO BE CHILD OF CARDMANAGER
	#get_parent().connect_card_signals(self)

func set_highlight(enabled: bool) -> void:
	highlight.visible = enabled


