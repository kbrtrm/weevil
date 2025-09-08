# CardTargetingManager.gd - Uses new component-based outline system
extends Node2D
class_name CardTargetingManager

var highlighted_targets: Array[Node2D] = []
var hovered_target: Node2D = null

# Get valid targets for a card based on its type and effects
func get_valid_targets_for_card(card) -> Array:
	var valid_targets = []
	
	# Get card data to analyze effects
	var card_data = CardDatabase.get_card_by_name(card.card_name)
	if not card_data:
		print("CardTargetingManager: No card data found for: ", card.card_name)
		return valid_targets
	
	var card_type = card_data.get("type", "")
	print("CardTargetingManager: Card type: ", card_type)
	
	# Simple logic based on card type
	match card_type:
		"attack":
			# Attack cards target enemies only
			var enemies = get_tree().get_nodes_in_group("enemies")
			valid_targets.append_array(enemies)
			print("CardTargetingManager: Attack card - targeting ", enemies.size(), " enemies")
		"skill":
			# Skill cards target player only  
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				valid_targets.append(players[0])
				print("CardTargetingManager: Skill card - targeting player")
		"power":
			# Power cards typically target player
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				valid_targets.append(players[0])
				print("CardTargetingManager: Power card - targeting player")
		_:
			print("CardTargetingManager: Unknown card type: ", card_type)
	
	return valid_targets

# Get targets for a specific effect
func get_targets_for_effect(effect_data) -> Array:
	var targets = []
	var target_type = effect_data.get("target", "enemy")
	
	match target_type:
		"enemy":
			var enemies = get_tree().get_nodes_in_group("enemies")
			targets.append_array(enemies)
		"player":
			var players = get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				targets.append(players[0])
		"all_enemies":
			var enemies = get_tree().get_nodes_in_group("enemies")
			targets.append_array(enemies)
		_:
			pass
	
	return targets

# Start highlighting valid targets for a card
func start_targeting(card):
	print("===== CardTargetingManager: start_targeting called for card: ", card.card_name, " =====")
	
	# CRITICAL: Clear all highlights first
	print("CardTargetingManager: Clearing all previous highlights...")
	clear_all_highlights()
	print("CardTargetingManager: Highlights cleared. Active count: ", highlighted_targets.size())
	
	var valid_targets = get_valid_targets_for_card(card)
	print("CardTargetingManager: Found ", valid_targets.size(), " valid targets for card type")
	
	for i in range(valid_targets.size()):
		var target = valid_targets[i]
		print("CardTargetingManager: Target ", i, ": ", target.name, " (", target.get_class(), ")")
		
		# Check what sprite we find
		var sprite = find_sprite_in_node(target)
		if sprite:
			print("CardTargetingManager: Found sprite: ", sprite.name, " (", sprite.get_class(), ")")
			print("CardTargetingManager: Sprite visible: ", sprite.visible)
		else:
			print("CardTargetingManager: NO SPRITE FOUND in target: ", target.name)
			continue
		
		# Try to add outline using new system with thinner, cleaner settings
		print("CardTargetingManager: Attempting to add outline...")
		if TargetOutlineManager.add_target_outline(target, Color.WHITE, 2.0):  # Reduced from 4.0 to 2.0
			highlighted_targets.append(target)
			print("CardTargetingManager: SUCCESS - Outline added to: ", target.name)
		else:
			print("CardTargetingManager: FAILED - Could not add outline to: ", target.name)
	
	print("===== End start_targeting - ", highlighted_targets.size(), " targets highlighted =====")
	print("CardTargetingManager: Final highlighted targets:")
	for target in highlighted_targets:
		print("  - ", target.name)
	print()

# Update hover highlighting
func update_hover_highlighting(mouse_position: Vector2):
	var new_hovered = get_target_at_position(mouse_position)
	
	if new_hovered != hovered_target:
		# Reset previous hover to thin white
		if hovered_target and hovered_target in highlighted_targets:
			TargetOutlineManager.update_target_outline(hovered_target, Color.WHITE, 2.0)
		
		# Set new hover with thinner red outline
		if new_hovered and new_hovered in highlighted_targets:
			TargetOutlineManager.update_target_outline(new_hovered, Color.RED, 2.5)  # Slightly thicker for hover
		
		hovered_target = new_hovered

# Get target at position (simplified)
func get_target_at_position(position: Vector2) -> Node2D:
	for target in highlighted_targets:
		if is_position_in_target(position, target):
			return target
	return null

# Check if position is within target bounds - FIXED for AnimatedSprite2D
func is_position_in_target(position: Vector2, target_node: Node2D) -> bool:
	# Simple sprite bounds check for both Sprite2D and AnimatedSprite2D
	var sprite = find_sprite_in_node(target_node)
	if sprite:
		var texture = null
		var sprite_scale = Vector2.ONE
		var sprite_pos = Vector2.ZERO
		
		if sprite is Sprite2D:
			texture = sprite.texture
			sprite_scale = sprite.scale
			sprite_pos = sprite.global_position
		elif sprite is AnimatedSprite2D:
			var frames = sprite.sprite_frames
			if frames and sprite.animation != "":
				texture = frames.get_frame_texture(sprite.animation, sprite.frame)
			sprite_scale = sprite.scale  
			sprite_pos = sprite.global_position
		
		if texture:
			var sprite_rect = Rect2(
				sprite_pos - texture.get_size() * sprite_scale / 2,
				texture.get_size() * sprite_scale
			)
			return sprite_rect.has_point(position)
	return false

# Find sprite in node - FIXED with null checks
func find_sprite_in_node(node: Node) -> Node:
	if not node or not is_instance_valid(node):
		print("CardTargetingManager: node is null or invalid")
		return null
		
	# Check if the node itself is a sprite (either type)
	if (node is Sprite2D or node is AnimatedSprite2D) and node.visible:
		return node
	
	# Check direct children first - prefer VISIBLE sprites
	var visible_sprites = []
	var any_sprites = []
	
	for child in node.get_children():
		if not child or not is_instance_valid(child):
			continue
			
		if (child is Sprite2D or child is AnimatedSprite2D) and child.name != "Shadow":
			any_sprites.append(child)
			if child.visible:
				visible_sprites.append(child)
	
	# Return visible sprite if found, otherwise any sprite
	if visible_sprites.size() > 0:
		return visible_sprites[0]
	elif any_sprites.size() > 0:
		return any_sprites[0]
	
	# Check nested children
	for child in node.get_children():
		if not child or not is_instance_valid(child):
			continue
			
		var sprite = find_sprite_in_node(child)
		if sprite and sprite.name != "Shadow":
			return sprite
	
	return null

# Clear all highlights - IMPROVED cleanup
func clear_all_highlights():
	print("CardTargetingManager: clear_all_highlights called")
	
	# Clear using the outline manager
	TargetOutlineManager.clear_all()
	print("CardTargetingManager: Called TargetOutlineManager.clear_all()")
	
	# Clear our local tracking
	highlighted_targets.clear()
	hovered_target = null
	
	print("CardTargetingManager: Local tracking cleared. Highlighted count: ", highlighted_targets.size())

# Stop targeting
func stop_targeting():
	clear_all_highlights()
