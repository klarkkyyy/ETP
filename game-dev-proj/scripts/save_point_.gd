class_name SavePoint
extends Area2D

var is_activated: bool = false

const SFX_SAVE = "res://audio/sfx/save.mp3"

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.play("inactive")

func _on_body_entered(body: Node2D) -> void:
	if is_activated:
		return
	if body.is_in_group("player"):
		activate()

func activate() -> void:
	is_activated = true
	SoundManager.play(SFX_SAVE, -10)
	$AnimatedSprite2D.play("active")
	GameManager.set_checkpoint(global_position)
