#level_standalone.gd
# Put on the root of a level scene that game.tscn instances (level_3/4/5/6).
# Inside the game it does nothing. Run on its own (Run Current Scene, F6) the
# level has no player or camera, so it loads the real game world instead and
# drops the player at the level's start, with the checkpoint set there, the
# echo slots a player would have by now, and the camera following them.
extends Node2D

const GAME := "res://levels/game.tscn"

## The level's start, relative to this level's root (e.g. "Start/PortalIn").
@export var start: NodePath
## Or a node path in game.tscn, for levels whose start lives outside the level.
@export var start_in_game: String = ""
@export var unlock_echoes: int = 3

func _ready() -> void:
	if get_tree().current_scene != self:
		return
	# this copy is only a stand-in until the game loads; keep it still and unseen
	process_mode = Node.PROCESS_MODE_DISABLED
	visible = false
	var boot := Boot.new()
	boot.level_name = name
	boot.start = start
	boot.start_in_game = start_in_game
	boot.unlock_echoes = unlock_echoes
	get_tree().root.add_child.call_deferred(boot)
	get_tree().change_scene_to_file.call_deferred(GAME)

## Lives on the tree root, so it survives the scene change and finishes the job.
class Boot extends Node:
	var level_name: String
	var start: NodePath
	var start_in_game: String
	var unlock_echoes: int

	func _ready() -> void:
		var tree := get_tree()
		var game: Node = null
		while game == null or game.name == level_name:
			await tree.process_frame
			game = tree.current_scene
		# let the player and camera set themselves up first
		await tree.physics_frame
		await tree.physics_frame
		await tree.process_frame
		var target: Node2D
		if start_in_game != "":
			target = game.get_node(start_in_game)
		else:
			target = game.get_node(level_name).get_node(start)
		for slot in range(1, unlock_echoes + 1):
			GameManager.unlock_echo(slot)
		var player := tree.get_first_node_in_group("player") as Node2D
		player.global_position = target.global_position
		player.velocity = Vector2.ZERO
		GameManager.set_checkpoint(target.global_position)
		var cam := tree.get_first_node_in_group("camera") as Camera2D
		if cam:
			cam.set_follow_mode()
			cam.global_position = player.global_position + cam.follow_offset
			cam.set("_target_pos", cam.global_position)
			cam.reset_smoothing()
		print("Started ", level_name, " on its own at ", target.get_path())
		queue_free()
