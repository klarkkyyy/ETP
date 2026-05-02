extends Area2D

@export var limit_top: int = -10000000
@export var limit_bottom: int = 10000000
@export var limit_left: int = -10000000
@export var limit_right: int = 10000000

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		var cam = get_tree().get_first_node_in_group("camera")
		if cam:
			cam.set_limits(limit_top, limit_bottom, limit_left, limit_right)
			print("Camera limits set — top: ", limit_top, " bottom: ", limit_bottom)
