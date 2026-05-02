extends Node

var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
var level_spawn: Vector2 = Vector2.ZERO  # set this when the level loads

func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true

func get_respawn_position() -> Vector2:
	return checkpoint_position if has_checkpoint else level_spawn

func reset_level() -> void:
	has_checkpoint = false
