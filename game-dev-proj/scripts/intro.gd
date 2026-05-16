extends Node2D
@onready var game: Node2D = $"."
@onready var spawn_point: Marker2D = $start/SpawnPoint

func _ready() -> void:
	GameManager.has_checkpoint = false
	GameManager.level_spawn = spawn_point.global_position


func _on_arrow_trap_body_entered(body: Node2D) -> void:
	pass # Replace with function body.
