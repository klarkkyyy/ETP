extends Area2D

@onready var title_intro = $"../CanvasLayer2"
var triggered = false

func _ready():
	body_entered.connect(_on_body_entered)
	print("TitleTrigger ready. title_intro = ", title_intro)

func _on_body_entered(body):
	print("Something entered: ", body.name)
	if body.name == "player" and not triggered:
		triggered = true
		print("Calling play_intro...")
		title_intro.play_intro()
