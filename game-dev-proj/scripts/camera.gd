#camera.gd
extends Camera2D


@export var follow_player: bool = true  
@export var snap_speed: float = 5.0     
@export var follow_speed: float = 8.0   
@export var follow_offset: Vector2 = Vector2(0, -60)

var rooms: Array[Rect2] = []
var current_room: Rect2
var _target_pos: Vector2
var player: Node2D = null

const FOLLOW_OFFSET = Vector2(0, -67) 

func _ready() -> void:
	add_to_group("camera")
	player = get_tree().get_first_node_in_group("player")
	if player:
		print("Camera found player: ", player.name)
		_target_pos = player.global_position
		global_position = _target_pos
	else:
		print("ERROR: Camera could not find player — is player in group 'player'?")

func _process(delta: float) -> void:
	if not player:
		return

	if follow_player:
		_target_pos = player.global_position + follow_offset
		global_position = global_position.lerp(_target_pos, follow_speed * delta)
	else:
		if not current_room.has_point(player.global_position):
			_find_new_room()
		global_position = global_position.lerp(_target_pos, snap_speed * delta)

func _find_new_room() -> void:
	for room in rooms:
		if room.has_point(player.global_position):
			current_room = room
			_target_pos = room.get_center()
			print("Camera switched to room: ", current_room)
			return

	# Find the leftmost room edge
	var leftmost_x: float = INF
	for room in rooms:
		if room.position.x < leftmost_x:
			leftmost_x = room.position.x

	# If player is left of all rooms, revert to follow
	if player.global_position.x < leftmost_x:
		print("Player left all rooms — switching back to follow mode")
		follow_player = true
		return

	# Otherwise snap to closest
	var closest_room: Rect2
	var closest_dist: float = INF
	for room in rooms:
		var dist = player.global_position.distance_to(room.get_center())
		if dist < closest_dist:
			closest_dist = dist
			closest_room = room
	current_room = closest_room
	_target_pos = closest_room.get_center()
	print("Camera snapped to closest room: ", current_room)

func register_room(rect: Rect2) -> void:
	rooms.append(rect)
	print("Room registered #", rooms.size(), ": ", rect, " | left edge X: ", rect.position.x, " | right edge X: ", rect.position.x + rect.size.x)
	if rooms.size() == 1:
		current_room = rect
		_target_pos = rect.get_center()

func switch_to_room_mode() -> void:
	print("switch_to_room_mode called — registered rooms: ", rooms.size())
	follow_player = false
	# Don't call _find_new_room here — let _process handle it
	# Just set target to nearest room center immediately
	var closest_room: Rect2
	var closest_dist: float = INF
	for room in rooms:
		var dist = player.global_position.distance_to(room.get_center())
		if dist < closest_dist:
			closest_dist = dist
			closest_room = room
	current_room = closest_room
	_target_pos = closest_room.get_center()
	print("Camera locked to closest room: ", current_room)
