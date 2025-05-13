extends Node2D
const CARD_SIZE = Vector2(90, 124)
const CARD_OFFSET = CARD_SIZE/2
var cards = []
var card_being_dragged
var drag_offset = Vector2.ZERO  # Store the offset between mouse and card position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	cards = get_children()
	
func _process(delta: float) -> void:
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
