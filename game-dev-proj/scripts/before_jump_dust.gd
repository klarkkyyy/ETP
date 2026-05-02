#before_jump_dust.gd
extends AnimatedSprite2D

func _ready():
	play("default")
	animation_finished.connect(queue_free)
