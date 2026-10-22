#level_standalone.gd
# Put on the root of a level scene that game.tscn instances (level_3/4/5/6).
# Inside the game, a level with an echo par scores its runs: arriving through
# its entrance starts one, and its exit portal waits for the level-clear
# screen (Continue goes through, Retry reloads the level). Run on its own (Run Current Scene, F6) the
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
			_hook_exit.call_deferred()
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
	elif from_id == _entry_id():
		Echoes.abort_run(name)

func _hook_exit() -> void:
	for tp in get_tree().get_nodes_in_group("teleport"):
		if tp.this_id == _exit_id() and is_ancestor_of(tp):
			tp.hold_until = _on_exit_used

## The exit portal was used: show the level-clear screen and hold the portal.
func _on_exit_used(tp: Node) -> bool:
	var result := Echoes.end_run(name)
	if result.is_empty():
		return false  # not a scored run (came in some other way): just go
	LevelClear.open(result, _continue_through.bind(tp), retry)
	return true

func _continue_through(tp: Node) -> void:
	tp.go()
	# progress is saved at the next level's door
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player:
		GameManager.set_checkpoint(player.global_position)
	SaveManager.save()

func _start_node() -> Node2D:
	if start_in_game != "":
		return get_tree().current_scene.get_node(start_in_game)
	return get_node(start)

## Reloads this level fresh (gates, crates, traps, enemies) and puts Ren back
## at its start with the run's echoes, deaths and time at zero.
func retry() -> void:
	var fresh: Node2D = load(scene_file_path).instantiate()
	var parent := get_parent()
	var index := get_index()
	var level_name := name
	name = level_name + "_old"  # frees the name for the fresh copy
	fresh.name = level_name
	fresh.transform = transform
	parent.add_child(fresh)
	parent.move_child(fresh, index)
	queue_free()
	fresh._restart.call_deferred()

func _restart() -> void:
	var start_pos := _start_node().global_position
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if player:
		player.global_position = start_pos
		player.velocity = Vector2.ZERO
	Echoes.begin_run(name, echo_par)
	GameManager.set_checkpoint(start_pos)
	SaveManager.save()

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
