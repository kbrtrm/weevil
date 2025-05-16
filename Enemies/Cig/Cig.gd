extends CharacterBody2D

@onready var stats = $Stats
@onready var playerDetectionZone = $PlayerDetectionZone
@onready var combatInitiationZone = $CombatInitiationZone
@onready var sprite = $AnimatedSprite2D
@onready var hurtbox = $Hurtbox
const EnemyDeathEffect = preload("res://Enemies/EnemyDeathEffect.tscn")
@onready var softCollision = $SoftCollision
@onready var wanderController = $WanderController
@onready var animationPlayer = $AnimationPlayer

# Add battle scene reference
@export var battle_scene: PackedScene = preload("res://Cards/test.tscn")

# Enemy data for battle
@export var enemy_data: Dictionary = {
	"name": "Ciggy", 
	"max_health": 22,
	"base_damage": 5
}

# Flag to prevent multiple battle initiations
var battle_initiated = false

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
	
	# Add to enemies group for tracking
	add_to_group("enemies")
	
	# Connect the combat initiation signal
	# If CombatInitiationZone is an Area2D, connect its body_entered signal
	if combatInitiationZone is Area2D:
		if !combatInitiationZone.body_entered.is_connected(_on_combat_initiation_zone_body_entered):
			combatInitiationZone.body_entered.connect(_on_combat_initiation_zone_body_entered)

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
	
# Add this function to handle combat initiation
func _on_combat_initiation_zone_body_entered(body):
	# Check if it's the player and battle isn't already triggered
	if body.is_in_group("player") and !battle_initiated and !Global.returning_from_battle:
		print("Combat initiated with player!")
		start_battle()
		
# Function to start the battle
func start_battle():
	battle_initiated = true
	
	# Stop movement
	state = IDLE
	velocity = Vector2.ZERO
	
	# Save game state
	Global.save_overworld_state()
	
	# Store enemy data
	Global.current_battle_enemies = [enemy_data]
	
	# Store enemy instance ID for potential removal after battle
	Global.enemy_instance_id = get_instance_id()
	Global.enemy_position = global_position
	
	# Optional: Play pre-battle animation
	animationPlayer.play("Start") 
	await animationPlayer.animation_finished
	
	# Change to battle scene
	print("Changing to battle scene...")
	get_tree().change_scene_to_packed(battle_scene)

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
