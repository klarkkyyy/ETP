#camera_room_zone.gd
# Level 1/2 rooms: when the player walks in, the camera glides to this room's
# centre and holds there (camera_follow_zone.gd switches it back to following).
# The last zone entered wins. camera.gd calls update_all() every physics tick;
# "in" goes by the player's centre, and they count as still in until it is
# STICKY px out, so a jump along a room edge doesn't swing the camera back
# and forth between two rooms.
class_name CameraRoomZone
extends Area2D

const STICKY = 4.0

static var _all: Array = []

var _inside := false

func _ready() -> void:
	add_to_group("room_zone")
	_all.append(self)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_if_player_inside()

func _exit_tree() -> void:
	_all.erase(self)

func _contains(point: Vector2, margin: float) -> bool:
	for child in get_children():
		if child is CollisionShape2D and child.shape and not child.disabled:
			if (child.global_transform * child.shape.get_rect()).grow(margin).has_point(point):
				return true
	return false

static func update_all(cam: Camera2D, player: Node2D) -> void:
	var c := player.global_position
	for z in _all:
		var inside: bool = z._contains(c, STICKY if z._inside else 0.0)
		if inside and not z._inside:
			z._enter(cam)
		z._inside = inside

func _enter(cam: Camera2D) -> void:
	cam.set_room_mode(global_position)

## Spawning inside this room: put the camera straight on it.
func _check_if_player_inside() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cam = get_tree().get_first_node_in_group("camera")
	if player and cam and _contains(player.global_position, 0.0):
		_inside = true
		_enter(cam)
		cam.global_position = global_position
		cam.reset_smoothing()
