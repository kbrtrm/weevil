extends CharacterBody2D

#const PlayerHurtSound = preload("res://Player/PlayerHurtSound.tscn")

@export var MAX_SPEED = 88
@export var ACCEL = 10
@export var ROLL_SPEED = 160
@export var FRICTION = 8

enum {
	MOVE,
	ROLL,
	ATTACK
}

var state = MOVE
var roll_vector = Vector2.DOWN
var stats = PlayerStats

@onready var animationPlayer = $AnimationPlayer
@onready var animtree = $AnimationTree
@onready var animstate = animtree.get("parameters/playback")
@onready var swordhitbox = $HitboxPivot/SwordHitbox
@onready var hurtbox = $Hurtbox
@onready var blinkAnimation = $BlinkAnimation
@onready var movementParticles = $MovementParticles
@onready var audioPlayer = $AudioStreamPlayer
@onready var footstepSound = $FootstepSound
@onready var actionable_finder = $Direction/ActionableFinder

func _ready():
	stats.no_health.connect(queue_free)
	animtree.active = true
	swordhitbox.knockback_vector = roll_vector

func _process(delta):
	match state:
		MOVE:
			move_state()
			
		ROLL:
			roll_state()
			
		ATTACK:
			attack_state()
			
			
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
