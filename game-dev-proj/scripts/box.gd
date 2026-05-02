extends CharacterBody2D

@export var push_speed: float = 80.0
@export var friction: float = 800.0

func _ready() -> void:
	add_to_group("box")
	add_to_group("moveable")

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Friction — only apply when on floor
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# Stop horizontal movement if hitting a wall
	if is_on_wall():
		velocity.x = 0.0

	move_and_slide()

func receive_push(direction: float) -> void:
	# Don't push if already against a wall
	if is_on_wall():
		return
	velocity.x = direction * push_speed
