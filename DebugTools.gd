# DebugTools.gd
extends Node

func _ready():
	print("DebugTools: Debug tools initialized")

func _input(event):
	if event is InputEventKey and event.pressed:
		# Reset enemies with F10 or Command/Control+0
		if event.keycode == KEY_F10 or (event.keycode == KEY_0 and (event.is_command_or_control_pressed())):
			reset_all_defeated_enemies()
		
		# Print enemies with F11 or Command/Control+9
		elif event.keycode == KEY_F11 or (event.keycode == KEY_9 and (event.is_command_or_control_pressed())):
			print_defeated_enemies()

func reset_all_defeated_enemies():
	print("DebugTools: Resetting all defeated enemies...")
	
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		
		# Clear the defeated_enemies dictionary
		global.defeated_enemies.clear()
		
		# Save to persist the change
		if global.has_method("save_game_state"):
			global.save_game_state()
			
		print("DebugTools: Defeated enemies reset successfully!")
		
		# Reload the current scene to refresh enemies
		get_tree().reload_current_scene()
	else:
		print("DebugTools: Cannot find Global node!")

func print_defeated_enemies():
	print("DebugTools: Current defeated enemies:")
	
	if has_node("/root/Global"):
		var global = get_node("/root/Global")
		
		if global.defeated_enemies.size() > 0:
			for scene in global.defeated_enemies:
				print("  Scene: " + scene)
				print("  Enemies: " + str(global.defeated_enemies[scene]))
		else:
			print("  No defeated enemies found!")
	else:
		print("DebugTools: Cannot find Global node!")
