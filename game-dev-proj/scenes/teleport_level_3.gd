extends Area2D

@export var this_id: String = "teleport_level3_entry"
@export var destination_scene: String = "res://Level_3/level_3.tscn"
@export var destination_id: String = "teleport_level3_entry"
@export var is_locked: bool = false

const SFX_TELEPORT = "res://audio/sfx/teleport.mp3"

var _player_nearby: bool = false

func _ready() -> void:
	add_to_group("teleport_scene")  
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("Scene Teleport ready: ", this_id, " → ", destination_scene)

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		if is_locked:
			print("Teleport ", this_id, " is locked")
			return
		_do_teleport()

func _do_teleport() -> void:
	#SoundManager.play(SFX_TELEPORT)
	GameManager.pending_teleport_id = destination_id
	MusicManager.stop()
	GameManager.change_scene(destination_scene)

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		print("Player near scene teleport: ", this_id)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
