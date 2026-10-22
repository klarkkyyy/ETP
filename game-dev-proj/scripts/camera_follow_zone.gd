#camera_follow_zone.gd
# Walking into this zone switches the camera back to following the player
# (see camera_room_zone.gd, which this shares its enter rules with).
extends CameraRoomZone

func _enter(cam: Camera2D) -> void:
	cam.set_follow_mode()

func _check_if_player_inside() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var cam = get_tree().get_first_node_in_group("camera")
	if player and cam and _contains(player.global_position, 0.0):
		_inside = true
		_enter(cam)
