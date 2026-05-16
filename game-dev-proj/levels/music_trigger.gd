extends Area2D

@export var track_path: String = "res://audio/bgm/level1.ogg"
@export var fade: bool = true
@export var one_shot: bool = true  # play once or every time player enters

var _triggered: bool = false

func _ready() -> void:
	MusicManager.play(track_path)
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if one_shot and _triggered:
		return
	_triggered = true
	MusicManager.play(track_path, fade)
