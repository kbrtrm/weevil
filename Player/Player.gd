extends CharacterBody2D

#const PlayerHurtSound = preload("res://Player/PlayerHurtSound.tscn")

@export var MAX_SPEED = 88
@export var ACCEL = 10
@export var ROLL_SPEED = 160
@export var FRICTION = 8
@export var inventory: Inventory

enum {
	MOVE,
	ROLL,
	ATTACK,
	JUMP
}

var state = MOVE
var roll_vector = Vector2.DOWN
var stats = PlayerStats

@onready var animationPlayer = $AnimationPlayer
@onready var animationJump = $AnimationJump
@onready var animtree = $AnimationTree
@onready var animstate = animtree.get("parameters/playback")
@onready var swordhitbox = $HitboxPivot/SwordHitbox
@onready var hurtbox = $Hurtbox
@onready var blinkAnimation = $BlinkAnimation
@onready var movementParticles = $MovementParticles
@onready var audioPlayer = $AudioStreamPlayer
@onready var footstepSound = $FootstepSound
@onready var actionable_finder = $Direction/ActionableFinder
@onready var sprite = $Sprite2D

func _ready():
	# Make sure we're in the player group for easier finding
	if not is_in_group("player"):
		add_to_group("player")
		print("Player: Added to 'player' group")
	
	# Debug collision settings
	print("Player collision layer: " + str(collision_layer))
	print("Player is on layer 2: " + str((collision_layer & 2) != 0))
	
	# Connect signals
	stats.no_health.connect(queue_free)
	animtree.active = true
	swordhitbox.knockback_vector = roll_vector
	
	# Load properties from Global if available
	load_properties_from_global()
	
	# IMPORTANT: Wait a short moment before checking spawn points
	# This ensures other nodes like spawn points are initialized first
	await get_tree().create_timer(0.1).timeout
	
	# Check if we need to position at a spawn point
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		print("Player._ready: Global.next_spawn_point = '" + global.next_spawn_point + "'")
		
		if global.next_spawn_point != "":
			print("Player._ready: Calling handle_player_spawn()")
			global.handle_player_spawn()

func _process(_delta):
	# Skip processing if game is paused
	if Global.game_paused:
		return
		
	match state:
		MOVE:
			move_state()
			
		ROLL:
			roll_state()
			
		ATTACK:
			attack_state()
			
		JUMP:
			jump_state()

func check_for_spawn():
	# Give everything time to load
	await get_tree().process_frame
	
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		print("Player: Checking global.next_spawn_point: '" + global.next_spawn_point + "'")
		
		if global.next_spawn_point != "":
			print("Player: Found spawn point to use: '" + global.next_spawn_point + "'")
			
			# Look up the spawn point
			var spawn_points = get_tree().get_nodes_in_group("spawn_points")
			print("Player: Found " + str(spawn_points.size()) + " spawn points")
			
			for spawn in spawn_points:
				print("Player: Checking spawn point '" + spawn.spawn_point_name + "'")
				
				if spawn.spawn_point_name == global.next_spawn_point:
					print("Player: Moving to spawn point position: " + str(spawn.global_position))
					global_position = spawn.global_position + spawn.adjust_position
					print("Player: New position: " + str(global_position))
					
					## Set player facing direction if applicable
					#if spawn.spawn_direction != Vector2.ZERO:
						#facing_direction = spawn.spawn_direction
					
					# Clear the spawn point name so it's not used again
					global.next_spawn_point = ""
					return
			
			print("Player: ERROR - Couldn't find spawn point named '" + global.next_spawn_point + "'")			
			
func _unhandled_input(_event: InputEvent):
	if Input.is_action_just_pressed("ui_accept"):
		var actionables = actionable_finder.get_overlapping_areas()
		if actionables.size() > 0:
			actionables[0].action()
			return
	
	
func move_state():
	var input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	input_vector = input_vector.normalized()
	
	movementParticles.emitting = false
	
	if input_vector != Vector2.ZERO:
		movementParticles.emitting = true
		roll_vector = input_vector
		swordhitbox.knockback_vector = input_vector
		animtree.set("parameters/Idle/blend_position", input_vector)
		animtree.set("parameters/Run/blend_position", input_vector)	
		animtree.set("parameters/Attack/blend_position", input_vector)	
		animtree.set("parameters/Roll/blend_position", input_vector)	
		animstate.travel("Run")
		velocity = velocity.move_toward(input_vector * MAX_SPEED, ACCEL)
	else:
		animstate.travel("Idle")
		velocity = velocity.move_toward(Vector2.ZERO, FRICTION)

	move()
	
	if Input.is_action_just_pressed("roll"):
		state = ROLL
	
	if Input.is_action_just_pressed("attack"):
		state = ATTACK
		
	if Input.is_action_just_pressed("jump"):
		state = JUMP
		
func roll_state():
	#control movement during roll
#	var input_vector = Vector2.ZERO
#	input_vector.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
#	input_vector.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
#	input_vector = input_vector.normalized()
	movementParticles.emitting = true
	velocity = roll_vector * ROLL_SPEED
#	velocity = velocity.move_toward(input_vector * ROLL_SPEED, ACCEL)
	animstate.travel("Roll")
	move()
	
func attack_state():
	velocity = Vector2.ZERO
	animstate.travel("Attack")
	
func move():
	move_and_slide()
	
func jump_state():
	animationJump.play("jump")
	state = MOVE
	
func roll_animation_finished():
	state = MOVE
	
func attack_animation_finished():
	state = MOVE

func _on_hurtbox_area_entered(area):
	stats.health -= area.damage
	hurtbox.start_invincibility(0.6)
	hurtbox.create_hit_effect()
#	var playerHurtSound = PlayerHurtSound.instantiate()
#	get_tree().current_scene.add_child(playerHurtSound)
	
func _on_hurtbox_invincibility_started():
	blinkAnimation.play("Start")

func _on_hurtbox_invincibility_ended():
	blinkAnimation.play("Stop")
	
# Function to store all important properties in the Global singleton
func store_properties_to_global():
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		
		# Create or update the player_properties dictionary in Global
		if not "player_properties" in global:
			global.player_properties = {}
		
		# Store all relevant properties
		global.player_properties = {
			"MAX_SPEED": MAX_SPEED,
			"ACCEL": ACCEL,
			"FRICTION": FRICTION,
			"ROLL_SPEED": ROLL_SPEED,
			"state": state,
			# Add other properties as needed
		}
		
		print("Player: Stored properties to Global")
		
# Function to load properties from Global
func load_properties_from_global():
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		
		# Check if the global properties exist
		if "player_properties" in global and global.player_properties != null:
			# Load each property
			if "MAX_SPEED" in global.player_properties:
				MAX_SPEED = global.player_properties.MAX_SPEED
				
			if "ACCEL" in global.player_properties:
				ACCEL = global.player_properties.ACCEL
				
			if "FRICTION" in global.player_properties:
				FRICTION = global.player_properties.FRICTION
				print("Player: Loaded FRICTION = " + str(FRICTION))
				
			if "ROLL_SPEED" in global.player_properties:
				ROLL_SPEED = global.player_properties.ROLL_SPEED
				
			if "state" in global.player_properties:
				state = global.player_properties.state
			
			print("Player: Loaded properties from Global")

# Add this to Player.gd to help debug spawn issues
func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		# This happens when the player is about to be deleted
		print("Player: Being deleted - this is normal during scene changes")
