extends Control
class_name DraggableCard

signal card_dropped_on_zone(card, zone)
signal card_returned_to_hand(card)

# Card data
var card_id: String = ""
var card_name: String = ""
var cost: int = 0
var attack: int = 0
var health: int = 0
var type: String = ""
var is_playable: bool = false

# Drag state
var is_dragging: bool = false
var drag_offset: Vector2
var original_position: Vector2
var original_parent: Node
var original_z_index: int

# Visual feedback
@onready var highlight = $Highlight if has_node("Highlight") else null
@onready var drag_preview = $DragPreview if has_node("DragPreview") else null

# Drop zones this card can be dropped on
var valid_drop_zones: Array[Area2D] = []

func _ready():
	# Enable mouse input
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	# Connect signals
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func load_data(data: Dictionary):
	"""Load card data from CardDatabase"""
	card_id = data.get("id", "")
	card_name = data.get("name", "")
	cost = data.get("cost", 0)
	attack = data.get("attack", 0)
	health = data.get("health", 0)
	type = data.get("type", "")
	
	# Update visual elements if they exist
	if has_node("CardName"):
		$CardName.text = card_name
	if has_node("CostLabel"):
		$CostLabel.text = str(cost)
	if has_node("AttackLabel"):
		$AttackLabel.text = str(attack)
	if has_node("HealthLabel"):
		$HealthLabel.text = str(health)

func set_playable(playable: bool):
	"""Set whether this card can be played"""
	is_playable = playable
	modulate = Color.WHITE if playable else Color(0.7, 0.7, 0.7)

func get_cost() -> int:
	return cost

func set_highlight(enabled: bool):
	"""Show/hide card highlight"""
	if highlight:
		highlight.visible = enabled

func _on_gui_input(event: InputEvent):
	if not is_playable:
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				start_drag(event.global_position)
			else:
				end_drag()
	
	elif event is InputEventMouseMotion and is_dragging:
		update_drag(event.global_position)

func start_drag(mouse_pos: Vector2):
	"""Start dragging the card"""
	if is_dragging:
		return
		
	is_dragging = true
	print("DraggableCard: Starting drag for card: ", card_name)
	
	# Store original state
	original_position = global_position
	original_parent = get_parent()
	original_z_index = z_index
	
	# Calculate drag offset
	drag_offset = mouse_pos - global_position
	
	# Move to top level for rendering
	var root = get_tree().current_scene
	original_parent.remove_child(self)
	root.add_child(self)
	
	# Set high z-index so card appears on top
	z_index = 1000
	
	# Scale up slightly for visual feedback
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.1)
	
	# Get all valid drop zones
	find_valid_drop_zones()
	
	# Highlight valid drop zones
	highlight_drop_zones(true)
	
	# NEW: Start target highlighting
	print("DraggableCard: Looking for targeting manager...")
	var targeting_manager = get_tree().get_first_node_in_group("targeting_manager")
	if targeting_manager and is_instance_valid(targeting_manager):
		print("DraggableCard: Found targeting manager, starting targeting for: ", card_name)
		targeting_manager.start_targeting(self)
	else:
		print("DraggableCard: NO TARGETING MANAGER FOUND or invalid!")
		# Let's see what groups exist
		var all_nodes = get_tree().get_nodes_in_group("targeting_manager")
		print("DraggableCard: Nodes in targeting_manager group: ", all_nodes.size())
		for node in all_nodes:
			print("  - ", node.name, " valid: ", is_instance_valid(node))

func update_drag(mouse_pos: Vector2):
	"""Update card position while dragging"""
	if not is_dragging:
		return
		
	global_position = mouse_pos - drag_offset
	
	# Check if we're over a valid drop zone
	check_drop_zone_hover()

func end_drag():
	"""End dragging and check for valid drop"""
	if not is_dragging:
		return
		
	is_dragging = false
	print("DraggableCard: Ending drag for card: ", card_name)
	
	# NEW: Stop target highlighting
	print("DraggableCard: Looking for targeting manager to stop targeting...")
	var targeting_manager = get_tree().get_first_node_in_group("targeting_manager")
	if targeting_manager and is_instance_valid(targeting_manager):
		print("DraggableCard: Stopping targeting")
		targeting_manager.stop_targeting()
	else:
		print("DraggableCard: No valid targeting manager found for stop_targeting")	
	# Remove drop zone highlights
	highlight_drop_zones(false)
	
	# Check if we're over a valid drop zone
	var drop_zone = get_drop_zone_under_mouse()
	
	if drop_zone:
		# Valid drop - emit signal
		emit_signal("card_dropped_on_zone", self, drop_zone)
	else:
		# Invalid drop - return to hand
		return_to_hand()

func return_to_hand():
	"""Return card to its original position in hand"""
	# Move back to original parent
	get_parent().remove_child(self)
	original_parent.add_child(self)
	
	# Restore original z-index
	z_index = original_z_index
	
	# Animate back to original position
	var tween = create_tween()
	tween.parallel().tween_property(self, "global_position", original_position, 0.3).set
