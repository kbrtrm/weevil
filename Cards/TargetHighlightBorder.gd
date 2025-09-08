# TargetHighlightBorder.gd - Border-based outline
extends Node2D
class_name TargetHighlightBorder

var target_sprite: Sprite2D
var border_node: NinePatchRect

func setup_target(sprite: Sprite2D):
	print("TargetHighlightBorder: setup_target called for sprite: ", sprite.name)
	target_sprite = sprite
	if target_sprite:
		# Create a NinePatchRect for clean borders
		border_node = NinePatchRect.new()
		border_node.patch_margin_left = 2
		border_node.patch_margin_right = 2
		border_node.patch_margin_top = 2
		border_node.patch_margin_bottom = 2
		
		# Create a simple white texture for the border
		var border_texture = ImageTexture.new()
		var image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		border_texture.set_image(image)
		border_node.texture = border_texture
		
		# Position and size to match sprite
		update_border_position()
		
		# Add to sprite's parent
		target_sprite.get_parent().add_child(border_node)
		border_node.z_index = target_sprite.z_index - 1
		border_node.visible = false  # Start hidden
		
		print("TargetHighlightBorder: Border created successfully")

func update_border_position():
	if target_sprite and border_node and target_sprite.texture:
		var sprite_size = target_sprite.texture.get_size() * target_sprite.scale
		border_node.size = sprite_size + Vector2(6, 6)  # 3px border on each side
		border_node.position = target_sprite.position - border_node.size / 2

func show_outline(color: Color = Color.WHITE, width: float = 3.0):
	print("TargetHighlightBorder: show_outline called - color: ", color)
	if border_node:
		border_node.modulate = color
		border_node.visible = true
		update_border_position()  # Ensure position is correct
		print("TargetHighlightBorder: Border made visible")

func hide_outline():
	if border_node:
		border_node.visible = false

func cleanup():
	if border_node:
		border_node.queue_free()
	target_sprite = null
	border_node = null
