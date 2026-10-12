#enemy_clear_trigger.gd
# Opens doors once every listed drop_enemy has died.
# Add it to a plain Node, list the enemies and the doors (door.tscn or anything
# with trigger_open()) in the Inspector.
extends Node

signal all_cleared()

@export var enemies: Array[NodePath] = []
@export var doors: Array[NodePath] = []

var _alive: int = 0

func _ready() -> void:
	for path in enemies:
		var enemy := get_node_or_null(path)
		if enemy and enemy.has_signal("died"):
			_alive += 1
			enemy.died.connect(_on_enemy_died, CONNECT_ONE_SHOT)

func _on_enemy_died(_enemy: Node2D) -> void:
	_alive -= 1
	if _alive > 0:
		return
	emit_signal("all_cleared")
	for path in doors:
		var door := get_node_or_null(path)
		if door and door.has_method("trigger_open"):
			door.trigger_open()
