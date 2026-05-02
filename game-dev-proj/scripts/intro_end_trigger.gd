extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("Intro end trigger ready at: ", global_position)

func _on_body_entered(body: Node) -> void:
	print("Intro trigger — body entered: ", body.name)
	if body.is_in_group("player"):
		print("Player hit intro trigger — switching to room mode")
		var cam = get_tree().get_first_node_in_group("camera")
		if cam:
			print("Camera found: ", cam.name)
			cam.switch_to_room_mode()
		else:
			print("ERROR: Camera not found in group 'camera'")
