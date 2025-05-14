extends Node2D
const CARD_SIZE = Vector2(90, 124)
const CARD_OFFSET = CARD_SIZE/2
var cards = []
var card_being_dragged
var drag_offset = Vector2.ZERO  # Store the offset between mouse and card position

@onready var drop_target = $"../DropTarget"
@onready var discard_pile = $"../Hand/DiscardPile"
@onready var hand = $"../Hand"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect to the drop target's card_played signal
	drop_target.card_played.connect(_on_card_played)
	
func _process(_delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = mouse_pos - drag_offset

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card = raycast_check_for_card()
			if card:
				print(card)
				card_being_dragged = card
				# Calculate and store the offset between mouse position and card position
				drag_offset = get_global_mouse_position() - card.position
		else:
			card_being_dragged = null

func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = 1
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		# Card top level node is two parents up
		return result[0].collider.get_parent().get_parent()
	return null

func _on_card_played(card):
	# First, play the card effect
	card.play_effect()
	
	# Then move it to the discard pile
	move_card_to_discard(card)

func move_card_to_discard(card):
	# Remove from hand
	hand.remove_card_from_hand(card)
	
	# Create tween for animation
	var tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT)
	
	# Animate the card to the discard pile
	var target_position = discard_pile.global_position
	tween.tween_property(card, "global_position", target_position, 0.5)
	tween.parallel().tween_property(card, "scale", Vector2(0.1,0.1), 0.5)
	tween.parallel().tween_property(card, "rotation_degrees", randf_range(-10, 10), 0.5)
	
	# After animation completes, add to discard pile
	tween.tween_callback(func():
		if card.get_parent():
			card.get_parent().remove_child(card)
			
		if discard_pile:
			if discard_pile.has_method("add_card"):
				discard_pile.add_card(card)
			else:
				discard_pile.add_child(card)
				card.position = Vector2.ZERO
	)
	
#func _on_drop_target_card_played(card):
	## First, play the card effect
	#if card.has_method("play_effect"):
		#card.play_effect()
	#
	## Then move it to the discard pile
	#move_card_to_discard(card)
