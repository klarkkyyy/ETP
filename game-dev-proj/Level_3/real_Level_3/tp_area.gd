extends Node

func _ready() -> void:
	if GameManager.pending_teleport_id == "teleport_level3_entry":
		await get_tree().process_frame
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = Vector2(548.0, 164.0)  
			print("Player spawned at level 3")
		GameManager.pending_teleport_id = ""
