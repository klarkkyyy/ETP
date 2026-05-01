extends Area2D

func _ready() -> void:

	var cam = get_tree().get_first_node_in_group("camera")
	if not cam:
		return
	if not cam.has_method("register_room"):
		return
	var shape = $CollisionShape2D.shape
	if not shape is RectangleShape2D:
		return
	var rect = Rect2(
		global_position - shape.size / 2,
		shape.size
	)
	cam.register_room(rect)
