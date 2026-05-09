extends CharacterBody2D

@export var speed: float = 60.0
@export var gravity: float = 900.0
@export var idle_time: float = 2.0
@export var walk_time: float = 3.0

enum {IDLE, MOVING}
var current_state = MOVING
var direction: int = 1 
var is_dead: bool = false 

@onready var sprite = $AnimatedSprite2D
@onready var wall_detector = $WallDetector
@onready var ledge_detector = $LedgeDetector
@onready var state_timer = $StateTimer # <--- Check this name!

func _ready():
	wall_detector.add_exception(self)
	ledge_detector.add_exception(self)

func _physics_process(delta: float) -> void:
	if is_dead: return

	if not is_on_floor():
		velocity.y += gravity * delta
	
	if current_state == MOVING:
		if wall_detector.is_colliding() or not ledge_detector.is_colliding():
			_flip()
		velocity.x = direction * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()
	_handle_animations()

	# If timer is valid and stopped, switch states
	if state_timer and state_timer.is_stopped():
		_choose_state()

func _choose_state():
	if state_timer == null: return
	
	if current_state == IDLE:
		current_state = MOVING
		state_timer.wait_time = walk_time
	else:
		current_state = IDLE
		state_timer.wait_time = idle_time
	
	state_timer.start()

func _flip():
	# 1. Debug Logs (Keep these to see hits in the console)
	if wall_detector.is_colliding():
		print("Flipped because of WALL: ", wall_detector.get_collider().name)
	elif not ledge_detector.is_colliding():
		print("Flipped because of LEDGE")
		
	# 2. Change Direction
	direction *= -1
	
	# 3. Update WallDetector
	# We use abs() to ensure the detector always looks in the direction of travel
	wall_detector.target_position.x = abs(wall_detector.target_position.x) * direction
	
	# 4. Update LedgeDetector Position
	# This moves the WHOLE ray to the left or right side of the boss
	ledge_detector.position.x = abs(ledge_detector.position.x) * direction
	
	# 5. Flip Visuals
	sprite.flip_h = (direction == -1)
	sprite.flip_h = (direction == -1)

func _handle_animations():
	if is_dead: return
		
	if current_state == IDLE:
		sprite.play("Idle")
	else:
		# Use whatever movement animation you have set up
		if direction == 1:
			sprite.play("Moving Right")
		else:
			sprite.play("Moving_Left")
