#title_trigger.gd
extends Area2D

@onready var title_intro = $"../CanvasLayer2"
var triggered = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Something entered: ", body.name)
	if body.name == "player" and not triggered:
		triggered = true
		print("Calling play_intro...")
		title_intro.play_intro()
