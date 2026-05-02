extends Node2D

func _ready() -> void:
	GameManager.has_checkpoint = false
	GameManager.level_spawn = $SpawnPoint.global_position
