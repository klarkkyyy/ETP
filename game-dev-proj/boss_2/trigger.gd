# trigger.gd — an Area2D that emits `triggered` the first time Ren walks into
# it. Wakes the Overseer, and lets it burst a floodgate behind Ren.
extends Area2D

signal triggered

var _done := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _done or not body.is_in_group("player"):
		return
	_done = true
	triggered.emit()
