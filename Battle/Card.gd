extends Control

@export var cardName = ""
@export var cardDesc = ""
@export var SlotL : bool = false
@export var SlotC : bool = false
@export var SlotR : bool = false

var drag_preview: Control

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var nameLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer2/NameLabel
	var descLabel = $Panel/MarginContainer/VBoxContainer/HBoxContainer3/DescLabel
	var slotLRect = $Panel/MarginContainer/VBoxContainer/Slots/SlotL
	var slotCRect = $Panel/MarginContainer/VBoxContainer/Slots/SlotC
	var slotRRect = $Panel/MarginContainer/VBoxContainer/Slots/SlotR
	
	nameLabel.text = cardName
	descLabel.text = cardDesc
	if SlotL: 
		slotLRect.color = Color.DARK_ORCHID
	if SlotC: 
		slotCRect.color = Color.DARK_ORCHID
	if SlotR: 
		slotRRect.color = Color.DARK_ORCHID

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _get_drag_data(at_position: Vector2) -> Variant:
	drag_preview = self.duplicate()
	$Panel.visible = false
	set_drag_preview(drag_preview)
	drag_preview.size = Vector2(80,112)
	var selected_card_data = {}
	selected_card_data.cardName = cardName
	print(selected_card_data)
	return selected_card_data
	
func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return true
	
func _drop_data(at_position: Vector2, data: Variant) -> void:
	$Panel.visible = true
	print("dropped")
