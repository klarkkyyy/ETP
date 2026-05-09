extends CharacterBody2D

@export var speed: float = 60.0
@export var gravity: float = 900.0
@export var idle_time: float = 2.0
@export var walk_time: float = 3.0
@export var max_health: float = 100.0

var current_health: float = 100.0
enum {IDLE, MOVING, HIT} 
var current_state = MOVING
var direction: int = 1 
var is_dead: bool = false 

# This variable will now do the job of the StateTimer node
var manual_timer: float = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var wall_detector = $WallDetector
@onready var ledge_detector = $LedgeDetector
@onready var health_bar = $BossHealthBar 

func _ready():
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	wall_detector.add_exception(self)
	ledge_detector.add_exception(self)
	manual_timer = walk_time # Start with the walk cycle

func take_damage(amount: float):
	if is_dead or current_state == HIT: 
		return 
	
	current_health -= amount
	if health_bar:
		health_bar.value = current_health
		
	print("Boss Hit! Current Health: ", current_health)
	
	if current_health <= 0:
		die()
	else:
		_trigger_hit_state()

func _trigger_hit_state():
	current_state = HIT
	velocity = Vector2.ZERO 
	sprite.play("Boss_Hit")
	# Stun the boss for exactly 0.5 seconds
	manual_timer = 0.5 

func _physics_process(delta: float) -> void:
	if is_dead: return

	if not is_on_floor():
		velocity.y += gravity * delta
	
	# --- MANUAL TIMER COUNTDOWN ---
	if manual_timer > 0:
		manual_timer -= delta
		if manual_timer <= 0:
			_choose_state()

	# Movement Logic
	if current_state == MOVING:
		if wall_detector.is_colliding() or not ledge_detector.is_colliding():
			_flip()
		velocity.x = direction * speed
	else:
		# Stay still during IDLE or HIT
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
	_handle_animations()

func _choose_state():
	if is_dead: return
	
	# If we just finished being HIT or IDLE, go back to MOVING
	if current_state == HIT or current_state == IDLE:
		current_state = MOVING
		manual_timer = walk_time
	else:
		# If we were MOVING, take a break
		current_state = IDLE
		manual_timer = idle_time

func _handle_animations():
	if is_dead: return
	
	if current_state == HIT:
		return 
	elif current_state == IDLE:
		sprite.play("Idle")
	else:
		if direction == 1:
			sprite.play("Moving Right")
		else:
			sprite.play("Moving_Left")

func _flip():
	direction *= -1
	wall_detector.target_position.x = abs(wall_detector.target_position.x) * direction
	ledge_detector.position.x = abs(ledge_detector.position.x) * direction
	sprite.flip_h = (direction == -1)

func die():
	if is_dead: return # Prevent this from running twice
	is_dead = true
	
	print("Boss has been defeated!")
	
	velocity = Vector2.ZERO
	sprite.play("Dead") # Ensure your animation name is "Die" or "Dead"
	
	# Disable collisions so the player/traps don't hit a corpse
	collision_layer = 0
	collision_mask = 0
	
	if health_bar:
		health_bar.hide()

	# Wait for the animation to finish before disappearing
	# We create a one-time timer that lasts 1.5 seconds (adjust this to your animation length)
	await get_tree().create_timer(1.5).timeout
	
	# This removes the boss from the scene entirely
	queue_free()
