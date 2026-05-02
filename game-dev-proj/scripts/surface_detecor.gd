extends Area2D

@export var surface_type: String = "grass"  # "grass", "rock", "wood"

func _ready() -> void:
	add_to_group("surface_detector")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		body.set_surface(surface_type)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		body.clear_surface(surface_type)
