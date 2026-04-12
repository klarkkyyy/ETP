extends Node2D


func _ready():
	$w.frame = 0
	$space.frame = 0
	$up.frame = 0
	$w.play("w")
	$space.play("space")
	$w.play("up")
