extends Camera2D

@export var follow_speed: float = 8.0
@export var snap_speed: float = 5.0
@export var follow_offset: Vector2 = Vector2(0, -45)
@export var deadzone: Vector2 = Vector2(0, 10)  

enum CameraMode { FOLLOW, ROOM }

var mode: CameraMode = CameraMode.FOLLOW
var player: Node2D = null
var _target_pos: Vector2
var _current_room_rect: Rect2

func _ready() -> void:
	add_to_group("camera")
	player = get_tree().get_first_node_in_group("player")
	if player:
		_target_pos = player.global_position + follow_offset
		global_position = _target_pos
		print("Camera found player: ", player.name)
	else:
		print("ERROR: Camera could not find player")

func _process(delta: float) -> void:
	if not player:
		return
	match mode:
		CameraMode.FOLLOW:
			var target_with_offset = player.global_position + follow_offset
			var offset = target_with_offset - global_position
			if abs(offset.x) > deadzone.x:
				_target_pos.x = target_with_offset.x - sign(offset.x) * deadzone.x
			if abs(offset.y) > deadzone.y:
				_target_pos.y = target_with_offset.y - sign(offset.y) * deadzone.y
			global_position = global_position.lerp(_target_pos, follow_speed * delta)
		CameraMode.ROOM:
			global_position = global_position.lerp(_target_pos, snap_speed * delta)

func set_follow_mode() -> void:
	mode = CameraMode.FOLLOW

func set_room_mode(room_center: Vector2) -> void:
	mode = CameraMode.ROOM
	_target_pos = room_center

func set_limits(top: int, bottom: int, left: int, right: int) -> void:
	limit_top = top
	limit_bottom = bottom
	limit_left = left
	limit_right = right
	print("Camera limits updated")
