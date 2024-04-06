extends Node

signal no_health
signal health_changed(value)
signal max_health_changed(value)

@export var max_health = 4: 
	get: 
		return max_health
	set(value): 
		max_health = value
		self.health = min(health, max_health)
		emit_signal("max_health_changed", value)
	
var health = max_health:
	get: 
		return health
	set(value): 
		health = value
		emit_signal("health_changed", value)
		if health <= 0:
			emit_signal("no_health")

func _ready():
	self.health = max_health 
