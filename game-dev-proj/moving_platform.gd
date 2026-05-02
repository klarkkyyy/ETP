extends AnimatableBody2D

enum MoveType { HORIZONTAL, VERTICAL }

@export var move_type: MoveType = MoveType.HORIZONTAL
@export var distance: float = 120.0       # how far it travels each direction
@export var speed: float = 60.0           # pixels per second
@export var wait_time: float = 0.5        # pause at each end
@export var start_offset: float = 10.0

var _start_pos: Vector2
var _direction: int = 1
var _waiting: bool = false
var _wait_timer: float = 0.0

func _ready():
	_start_pos = position + Vector2(50.0, 0.0)

func _physics_process(delta: float) -> void:
	if _waiting:
		_wait_timer -= delta
		if _wait_timer <= 0.0:
			_waiting = false
			_direction *= -1
		return

	var axis := Vector2.RIGHT if move_type == MoveType.HORIZONTAL else Vector2.DOWN
	var target_offset := _direction * distance
	var target_pos := _start_pos + axis * target_offset

	var move_vec := (target_pos - position).normalized() * speed * delta
	
	if position.distance_to(target_pos) <= speed * delta:
		position = target_pos
		_waiting = true
		_wait_timer = wait_time
	else:
		position += move_vec
