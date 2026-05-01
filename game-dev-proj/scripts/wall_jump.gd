#wall_jump.gd
extends AnimatedSprite2D

func _ready():
	play("default")
	await animation_finished
	queue_free()
