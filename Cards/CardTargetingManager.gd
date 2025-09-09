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
			# Attack cards target enemies only - FILTER OUT DEAD ENEMIES
			var enemies = get_tree().get_nodes_in_group("enemies")
			for enemy in enemies:
				# Only add living enemies to valid targets
				if enemy.has_method("is_alive") and enemy.is_alive():
					valid_targets.append(enemy)
				elif "health" in enemy and enemy.health > 0:
					valid_targets.append(enemy)
				elif not ("health" in enemy):  # Fallback - assume alive if no health property
					valid_targets.append(enemy)
			print("CardTargetingManager: Attack card - targeting ", valid_targets.size(), " living enemies out of ", enemies.size(), " total")
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
	
	# Check what enemies are in the scene
	var enemies_in_group = get_tree().get_nodes_in_group("enemies")
	print("DEBUG: Found ", enemies_in_group.size(), " enemies in group")
	for enemy in enemies_in_group:
		print("DEBUG: Enemy: ", enemy.name)
	
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
	# PRIORITY 1: If there's a hovered target and the position is within it, return that
	if hovered_target and is_position_in_target(position, hovered_target):
		return hovered_target
	
	# PRIORITY 2: Check other highlighted targets
	for target in highlighted_targets:
		if target != hovered_target and is_position_in_target(position, target):
			return target
	
	# PRIORITY 3: If no highlighted targets found, check all potential targets with expanded zones
	# This handles the case where targeting was stopped but we still need drop detection
	var all_possible_targets = []
	
	# Add all players and enemies as potential targets
	var players = get_tree().get_nodes_in_group("player")
	var enemies = get_tree().get_nodes_in_group("enemies")
	all_possible_targets.append_array(players)
	all_possible_targets.append_array(enemies)
	
	for target in all_possible_targets:
		if is_position_in_target(position, target):
			return target
	
	return null

# Check if position is within target bounds - EXPANDED drop areas
func is_position_in_target(position: Vector2, target_node: Node2D) -> bool:
	# Check if target is player - use top half of screen ONLY if it's a skill card being targeted
	if target_node.is_in_group("player"):
		var viewport_size = get_viewport().get_visible_rect().size
		var screen_center_y = viewport_size.y / 2
		# Only use top half for player if this player is in highlighted targets
		# This prevents conflicts with enemy targeting
		if target_node in highlighted_targets:
			return position.y < screen_center_y
		else:
			# If player not highlighted, use smaller area around player sprite
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
					var sprite_size = texture.get_size() * sprite_scale * 2.0  # 2x player sprite
					var sprite_rect = Rect2(
						sprite_pos - sprite_size / 2,
						sprite_size
					)
					return sprite_rect.has_point(position)
			return false
	
	# For enemies - use larger drop zones around sprite
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
			# Adjust drop zone size based on number of enemies to prevent overlap
			var enemies = get_tree().get_nodes_in_group("enemies")
			var multiplier = 3.0  # Default size
			
			# If there are multiple enemies, use smaller drop zones to reduce overlap
			if enemies.size() > 1:
				multiplier = 2.0  # Smaller zones for multiple enemies
			
			var expanded_size = texture.get_size() * sprite_scale * multiplier
			var sprite_rect = Rect2(
				sprite_pos - expanded_size / 2,
				expanded_size
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
