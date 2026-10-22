#title_trigger.gd
# Plays the title roll the first time Ren walks through. Remembered in
# StoryDirector.seen, so it is saved and a Continue doesn't show it again.
extends Area2D

@onready var title_intro = $"../CanvasLayer2"
var triggered = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _seen_key() -> String:
	return "title:" + str(get_path())

func _on_body_entered(body):
	if body.name == "player" and not triggered and not StoryDirector.seen.has(_seen_key()):
		triggered = true
		StoryDirector.seen[_seen_key()] = true
		title_intro.play_intro()
