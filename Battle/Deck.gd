extends Control

var deck := [
	{
		"name": "Pebble",
		"description": "Deal 6 damage",
		"cost": 1,
		"type": "ATK",
		"value": 6
	},
	{
		"name": "Pebble",
		"description": "Deal 6 damage",
		"cost": 1,
		"type": "ATK",
		"value": 6
	},
	{
		"name": "Pebble",
		"description": "Deal 6 damage",
		"cost": 1,
		"type": "ATK",
		"value": 6
	},
	{
		"name": "Pebble",
		"description": "Deal 6 damage",
		"cost": 1,
		"type": "ATK",
		"value": 6
	},
	{
		"name": "Pebble",
		"description": "Deal 6 damage",
		"cost": 1,
		"type": "ATK",
		"value": 6
	},
	{
		"name": "Seed",
		"description": "Gain 5 block",
		"cost": 1,
		"type": "BLK",
		"value": 5
	},
	{
		"name": "Seed",
		"description": "Gain 5 block",
		"cost": 1,
		"type": "BLK",
		"value": 5
	},
	{
		"name": "Seed",
		"description": "Gain 5 block",
		"cost": 1,
		"type": "BLK",
		"value": 5
	},
	{
		"name": "Seed",
		"description": "Gain 5 block",
		"cost": 1,
		"type": "BLK",
		"value": 5
	},
	{
		"name": "Seed",
		"description": "Gain 5 block",
		"cost": 1,
		"type": "BLK",
		"value": 5
	},
	{
		"name": "Leaf",
		"description": "Draw 1 card",
		"cost": 0,
		"type": "BLK",
		"value": 1
	},
	{
		"name": "Leaf",
		"description": "Draw 1 card",
		"cost": 0,
		"type": "DRW",
		"value": 1
	},
]



@onready var grid = $ScrollContainer/MarginContainer2/MarginContainer/GridContainer
const Card = preload("res://Battle/Card.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for c in deck:
		var card2add = Card.instantiate()
		card2add.cardName = c.name
		card2add.cardDesc = c.description
		card2add.cardCost = c.cost
		grid.add_child(card2add)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
