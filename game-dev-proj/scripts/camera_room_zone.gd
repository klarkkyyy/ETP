extends Area2D

func _ready() -> void:
	add_to_group("room_zone")
	body_entered.connect(_on_body_entered)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check_if_player_inside()

func _check_if_player_inside() -> void:
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("player"):
			var cam = get_tree().get_first_node_in_group("camera")
			if cam:
				cam.set_room_mode(global_position)
				cam.global_position = global_position
				print("Camera snapped to room center: ", global_position)
			return

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var cam = get_tree().get_first_node_in_group("camera")
		if cam:
			cam.set_room_mode(global_position)
