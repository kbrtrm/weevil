extends Node2D

const MossEffect = preload("res://Objects/MossEffect.tscn")

func create_grass_effect():
	var grassEffect = MossEffect.instantiate()
	var world = get_tree().current_scene
	get_parent().add_child(grassEffect)
	grassEffect.global_position = global_position

func _on_hurtbox_area_entered(area):
	create_grass_effect()
	queue_free()
