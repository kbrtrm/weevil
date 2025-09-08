# TargetOutlineManager.gd - Centralized outline management system
extends Node
class_name TargetOutlineManager

# Singleton pattern
static var instance: TargetOutlineManager

# Outline registry - stores all active outlines
var active_outlines: Dictionary = {}
var outline_pool: Array[OutlineComponent] = []

func _ready():
	instance = self
	name = "TargetOutlineManager"

# Static method to get the singleton
static func get_instance() -> TargetOutlineManager:
	if not instance:
		instance = TargetOutlineManager.new()
		Engine.get_main_loop().current_scene.add_child(instance)
	return instance

# Add outline to a target node - COMPREHENSIVE DEBUG
func add_outline(target: Node2D, color: Color = Color.WHITE, width: float = 3.0) -> bool:
	var target_id = target.get_instance_id()
	
	print("TargetOutlineManager: add_outline called for: ", target.name, " (ID: ", target_id, ")")
	
	# CRITICAL: Remove existing outline if present
	if target_id in active_outlines:
		print("TargetOutlineManager: Target already has outline, removing first: ", target.name)
		remove_outline(target)
	
	# Find sprite in target
	var sprite = find_sprite_in_node(target)
	if not sprite:
		print("TargetOutlineManager: No sprite found in target: ", target.name)
		return false
	
	print("TargetOutlineManager: Found sprite: ", sprite.name, " of type: ", sprite.get_class())
	print("TargetOutlineManager: Sprite material before: ", sprite.material)
	
	# Check if sprite already has an outline material and force clear it
	if sprite.material and sprite.material is ShaderMaterial:
		var shader_mat = sprite.material as ShaderMaterial
		if shader_mat.shader and "outline" in str(shader_mat.shader.code).to_lower():
			print("TargetOutlineManager: WARNING - Sprite already has outline material, clearing: ", sprite.name)
			sprite.material = null
			print("TargetOutlineManager: Cleared material, now: ", sprite.material)
	
	# Get or create outline component
	var outline_component = get_pooled_outline()
	if not outline_component:
		outline_component = OutlineComponent.new()
		print("TargetOutlineManager: Created new OutlineComponent")
	else:
		print("TargetOutlineManager: Using pooled OutlineComponent")
	
	# Attach outline to sprite
	target.add_child(outline_component)
	print("TargetOutlineManager: Added OutlineComponent as child of: ", target.name)
	
	if outline_component.attach_to_sprite(sprite):
		active_outlines[target_id] = outline_component
		outline_component.show_outline(color, width)
		print("TargetOutlineManager: SUCCESS - Added outline to: ", target.name)
		print("TargetOutlineManager: Sprite material after: ", sprite.material)
		return true
	else:
		# Failed to attach, return to pool
		print("TargetOutlineManager: FAILED to attach outline")
		target.remove_child(outline_component)
		return_to_pool(outline_component)
		return false

# Remove outline from target
func remove_outline(target: Node2D):
	var target_id = target.get_instance_id()
	
	if target_id in active_outlines:
		var outline_component = active_outlines[target_id]
		outline_component.cleanup()
		target.remove_child(outline_component)
		return_to_pool(outline_component)
		active_outlines.erase(target_id)
		print("TargetOutlineManager: Removed outline from: ", target.name)

# Update outline color/width
func update_outline(target: Node2D, color: Color, width: float = 3.0):
	var target_id = target.get_instance_id()
	
	if target_id in active_outlines:
		var outline_component = active_outlines[target_id]
		outline_component.show_outline(color, width)

# Check if target has outline
func has_outline(target: Node2D) -> bool:
	return target.get_instance_id() in active_outlines

# Clear all outlines - IMPROVED with debugging
func clear_all_outlines():
	print("TargetOutlineManager: clear_all_outlines called - ", active_outlines.size(), " active outlines")
	
	var cleared_count = 0
	for target_id in active_outlines.keys():
		var target = instance_from_id(target_id) as Node2D
		if target:
			print("TargetOutlineManager: Clearing outline from: ", target.name)
			remove_outline(target)
			cleared_count += 1
		else:
			print("TargetOutlineManager: Target with ID ", target_id, " no longer exists")
			active_outlines.erase(target_id)
	
	print("TargetOutlineManager: Cleared ", cleared_count, " outlines. Remaining: ", active_outlines.size())

# Object pooling for performance
func get_pooled_outline() -> OutlineComponent:
	if outline_pool.size() > 0:
		return outline_pool.pop_back()
	return null

func return_to_pool(outline: OutlineComponent):
	if outline_pool.size() < 10:  # Max pool size
		outline_pool.append(outline)
	else:
		outline.queue_free()

# Helper function - FIXED with null checks
func find_sprite_in_node(node: Node) -> Node:
	if not node or not is_instance_valid(node):
		print("TargetOutlineManager: node is null or invalid")
		return null
		
	if (node is Sprite2D or node is AnimatedSprite2D) and node.visible:
		return node
	
	# Prefer visible sprites
	var visible_sprites = []
	var any_sprites = []
	
	for child in node.get_children():
		if not child or not is_instance_valid(child):
			continue
			
		if (child is Sprite2D or child is AnimatedSprite2D) and child.name != "Shadow":
			any_sprites.append(child)
			if child.visible:
				visible_sprites.append(child)
	
	if visible_sprites.size() > 0:
		return visible_sprites[0]
	elif any_sprites.size() > 0:
		return any_sprites[0]
	
	for child in node.get_children():
		if not child or not is_instance_valid(child):
			continue
			
		var sprite = find_sprite_in_node(child)
		if sprite and sprite.name != "Shadow":
			return sprite
	
	return null

# Convenience static methods
static func add_target_outline(target: Node2D, color: Color = Color.WHITE, width: float = 3.0) -> bool:
	return get_instance().add_outline(target, color, width)

static func remove_target_outline(target: Node2D):
	get_instance().remove_outline(target)

static func update_target_outline(target: Node2D, color: Color, width: float = 3.0):
	get_instance().update_outline(target, color, width)

static func clear_all():
	get_instance().clear_all_outlines()
