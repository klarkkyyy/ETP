extends Area2D

@export var this_id: String = "teleport_level3_entry"

func _ready() -> void:
	add_to_group("teleport_scene")
	if GameManager.pending_teleport_id == this_id:
		# wait one frame for camera and player to fully initialize
		await get_tree().process_frame
		var player = get_tree().get_first_node_in_group("player")
		if player:
			player.global_position = global_position
		GameManager.pending_teleport_id = ""
		print("Player arrived at: ", this_id)
