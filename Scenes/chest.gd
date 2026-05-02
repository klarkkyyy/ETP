extends Area2D


# Called when the node enters the scene tree for the first time.
func _on_body_entered(body: Node2D) -> void:
	print("Got the chest!")
	queue_free()
