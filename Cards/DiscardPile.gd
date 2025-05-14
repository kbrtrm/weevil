# DiscardPile.gd
extends Node2D

var discarded_cards = []

func add_card(card):
	# Add to tracking array
	discarded_cards.append(card)
	
	# Add as child
	add_child(card)
	
	## Reset position (we'll offset it slightly for a stacked look)
	#card.position = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	#
	## Start with a slightly larger scale and fade in
	card.scale = Vector2(1, 1)
	
	# Create a settling animation
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Scale down slightly and fade in completely
	tween.tween_property(card, "scale", Vector2(0, 0), 0.2)
	
	# Update any UI elements if needed
	var label = find_child("Label")
	if label:
		label.text = str(discarded_cards.size())
