# story_trigger.gd — an Area2D that plays StoryDirector.event(`event_key`)
# the first time Ren walks into it (each beat still plays once per run).
extends Area2D

@export var event_key: String = ""

var _done := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	StoryDirector.event(event_key)
