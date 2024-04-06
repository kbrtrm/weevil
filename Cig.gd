extends CharacterBody2D

@onready var stats = $Stats
@onready var playerDetectionZone = $PlayerDetectionZone
@onready var combatInitiationZone = $CombatInitiationZone
@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
const EnemyDeathEffect = preload("res://EnemyDeathEffect.tscn")
@onready var softCollision = $SoftCollision
@onready var wanderController = $WanderController
@onready var animationPlayer = $AnimationPlayer

@export var MAX_SPEED = 120
@export var ACCEL = 12
@export var FRICTION = 12
@export var WANDER_TARGET_RANGE = 4

enum {
	IDLE,
	WANDER,
	CHASE
}

var state = WANDER

func _ready():
	state = pick_random_state([IDLE, WANDER])

func _physics_process(_delta):
	velocity = velocity.move_toward(Vector2.ZERO, FRICTION)
	move_and_slide()
	
	match state:
		IDLE:
			velocity.move_toward(Vector2.ZERO, 12)
			seek_player()
			
			if wanderController.get_time_left() == 0:
				state = pick_random_state([IDLE, WANDER])
				wanderController.start_wander_timer(randi_range(1,3))
		
		WANDER:
			seek_player()
			
			if wanderController.get_time_left() == 0:
				state = pick_random_state([IDLE, WANDER])
				wanderController.start_wander_timer(randi_range(1,3))

			var direction = global_position.direction_to(wanderController.target_position)
			velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL)
			
			if global_position.distance_to(wanderController.target_position) <= WANDER_TARGET_RANGE:
				state = pick_random_state([IDLE, WANDER])
				wanderController.start_wander_timer(randi_range(1,3))
			
			sprite.flip_h = velocity.x > 0
		
		CHASE:
			var player = playerDetectionZone.player
			if player != null:
				var direction = global_position.direction_to(player.global_position)
				velocity = velocity.move_toward(direction * MAX_SPEED, ACCEL)
			sprite.flip_h = velocity.x > 0		
				
	if softCollision.is_colliding():
		velocity = velocity.move_toward(softCollision.get_push_vector() * MAX_SPEED, ACCEL)
	move_and_slide()
			
func seek_player():
	if playerDetectionZone.can_see_player():
		state = CHASE
		
func pick_random_state(state_list):
	state_list.shuffle()
	return state_list.pop_front()

func _on_hurtbox_area_entered(area):
	stats.health -= area.damage
	var knockback_vector = area.knockback_vector
	velocity = area.knockback_vector * 100
	hurtbox.create_hit_effect()
	hurtbox.start_invincibility(0.4)

func _on_stats_no_health():
	queue_free()
	var enemyDeathEffect = EnemyDeathEffect.instantiate()
	get_parent().add_child(enemyDeathEffect)
	enemyDeathEffect.global_position = global_position

func _on_hurtbox_invincibility_started():
	animationPlayer.play("Start")

func _on_hurtbox_invincibility_ended():
	animationPlayer.play("Stop")
