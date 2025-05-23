extends Control

var _is_paused: bool = false:
	set = set_paused
	
@onready var inventory: Inventory = preload("res://Inventory/PlayerInventory.tres")
@onready var slots: Array = $MarginContainer/MenuContainer/MainPanel/MarginContainer/MarginContainer/TabContainer/Items/GridContainer.get_children()

func _ready():
	update()

func update():
	for i in range(min(inventory.items.size(), slots.size())):
		slots[i].update(inventory.items[i])

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_is_paused =! _is_paused
	
func set_paused(value:bool) -> void:
	_is_paused = value
	get_tree().paused = _is_paused
	visible = _is_paused

func _on_button_resume_pressed() -> void:
	_is_paused = false


func _on_settings_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	get_tree().quit()
