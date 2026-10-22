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

@export_group("Echo par")
## Clear the level with this many echoes or fewer for a star. -1: no star.
@export var echo_par: int = -1
## Arriving here starts the scored run ("" = teleport_lN_in, from the level's name).
@export var entry_teleport: String = ""
## Leaving through this teleport clears the level ("" = teleport_lN_out).
@export var exit_teleport: String = ""

func _ready() -> void:
	if get_tree().current_scene != self:
		if echo_par >= 0:
			GameManager.player_teleported.connect(_on_player_teleported)
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

func _level_number() -> String:
	return name.get_slice("_", 1)

func _entry_id() -> String:
	return entry_teleport if entry_teleport != "" else "teleport_l%s_in" % _level_number()

func _exit_id() -> String:
	return exit_teleport if exit_teleport != "" else "teleport_l%s_out" % _level_number()

func _on_player_teleported(from_id: String, to_id: String) -> void:
	if to_id == _entry_id():
		Echoes.begin_run(name, echo_par)
	elif from_id == _exit_id():
		Echoes.end_run(name)
	elif from_id == _entry_id():
		Echoes.abort_run(name)

## Starts the scored run when the level is played on its own (F6).
func begin_echo_run() -> void:
	if echo_par >= 0:
		Echoes.begin_run(name, echo_par)

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
		var level := game.get_node_or_null(NodePath(level_name))
		if level and level.has_method("begin_echo_run"):
			level.begin_echo_run()
		var cam := tree.get_first_node_in_group("camera") as Camera2D
		if cam:
			cam.set_follow_mode()
			cam.global_position = player.global_position + cam.follow_offset
			cam.set("_target_pos", cam.global_position)
			cam.reset_smoothing()
		print("Started ", level_name, " on its own at ", target.get_path())
		queue_free()
