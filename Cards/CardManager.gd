extends Node2D
const CARD_SIZE = Vector2(90, 124)
const CARD_OFFSET = CARD_SIZE/2
var cards = []
var card_being_dragged
var drag_offset = Vector2.ZERO  # Store the offset between mouse and card position

@onready var drop_target = $"../DropTarget"
@onready var discard_pile = $"../Hand/DiscardPile"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cards = get_children()
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
	# Remove card from its current parent
	var current_parent = card.get_parent()
	if current_parent:
		current_parent.remove_child(card)
	
	# Add card to the discard pile
	discard_pile.add_card(card)
