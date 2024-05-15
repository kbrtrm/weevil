extends PassThruObject

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	choose_random_flip(sprite)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
