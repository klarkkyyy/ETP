extends Area2D

## Add this node to the group "teleport" in the Inspector.
## Set destination_id to match the teleport you want to arrive at.
## Set this_id to uniquely identify this teleport.

@export var this_id: String = "teleport_a"
@export var destination_id: String = "teleport_b"
@export var is_locked: bool = false  # lock until puzzle is solved etc.

signal teleport_used(destination_id: String, player: Node)

var _player_nearby: bool = false

func _ready() -> void:
	add_to_group("teleport")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("Teleport ready: ", this_id, " → ", destination_id)

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		if is_locked:
			print("Teleport ", this_id, " is locked")
			return
		print("Teleport used: ", this_id, " → ", destination_id)
		_do_teleport()

func _do_teleport() -> void:
	# Find destination teleport in the scene
	var all_teleports = get_tree().get_nodes_in_group("teleport")
	for tp in all_teleports:
		if tp.this_id == destination_id:
			emit_signal("teleport_used", destination_id, _get_player())
			tp.receive_player(_get_player())
			return
	print("ERROR: No teleport found with id: ", destination_id)

func receive_player(player: Node) -> void:
	# Called by the origin teleport to place the player here
	if player:
		player.global_position = global_position
		print("Player arrived at: ", this_id)

func _get_player() -> Node:
	return get_tree().get_first_node_in_group("player")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true
		print("Player near teleport: ", this_id)

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false
