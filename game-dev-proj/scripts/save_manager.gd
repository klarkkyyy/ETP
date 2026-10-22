#save_manager.gd (autoload "SaveManager")
# One save file, user://save.json. It is written at every new lantern
# (checkpoint), on a level clear and when the boss falls, and holds what the
# player has earned: the last lantern, echo slots, story beats seen, the boss,
# echo stars and level records (fewest echoes, fastest time, fewest
# deaths), the levels reached (for the level select) and the
# level run in progress (echoes, deaths, time). Resume loads the game at that
# lantern, and the level select starts any reached level from its beginning;
# either way the levels start fresh, the same as a respawn. Everything is in this one file so it can be synced to
# the cloud later without touching the rest of the game.
# Only sessions started from the main menu save, so running a level on its own
# (F6) never overwrites the player's save.
extends Node

const SAVE_PATH = "user://save.json"
const GAME = "res://levels/game.tscn"
const INTRO = "res://story/story_intro.tscn"
const MENU = "res://MENU/main_menu.tscn"
const VERSION = 1

## True when this session saves (started from the main menu).
var active := false
## Level ids (LevelList) Ren has reached: the level select lets him start these.
var unlocked: Dictionary = {}
var _pending: Dictionary = {}  # save being loaded by Continue


func _ready() -> void:
	GameManager.checkpoint_changed.connect(_on_checkpoint)
	get_tree().node_added.connect(_on_node_added)


## A new lantern: the level it's in counts as reached, then save.
func _on_checkpoint(pos: Vector2) -> void:
	var game := get_tree().current_scene
	if game and game.name == "game":
		for lantern in game.find_children("*", "Area2D", true, false):
			if lantern is SavePoint and lantern.global_position.distance_to(pos) < 1.0:
				var id := LevelList.id_for(lantern)
				if not LevelList.entry(id).is_empty():
					unlocked[id] = true
				break
	save()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func load_data() -> Dictionary:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


func save() -> void:
	if not active or not GameManager.has_checkpoint:
		return
	var data := _snapshot()
	# write a temp file and swap it in, so a crash mid-write can't corrupt the save
	var tmp := SAVE_PATH + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Could not write the save: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(SAVE_PATH))


## Everything the save holds, as it stands now.
func _snapshot() -> Dictionary:
	var echoes := []
	for slot in GameManager.echo_unlocks:
		if GameManager.echo_unlocks[slot]:
			echoes.append(slot)
	var cp := GameManager.checkpoint_position
	var data := {
		"version": VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"checkpoint": [cp.x, cp.y],
		"echoes": echoes,
		"story_seen": StoryDirector.seen.keys(),
		"boss_defeated": GameManager.boss_defeated,
		"level_best": GameManager.level_best,
		"level_stars": GameManager.level_stars,
		"level_time": GameManager.level_time,
		"level_deaths": GameManager.level_deaths,
		"run": Echoes.get_run_state(),
		"levels_unlocked": unlocked.keys(),
	}
	return data


## NEW GAME: wipes the save and plays the opening story.
func new_game() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_reset_session()
	active = true
	get_tree().change_scene_to_file(INTRO)


## Resume: loads the game at the saved lantern.
func continue_game() -> void:
	var data := load_data()
	if data.is_empty() or not data.has("checkpoint"):
		return
	_load(data)


## Level select: starts the reached level `id` from its beginning.
func start_level(id: String) -> void:
	var data := load_data()
	if data.is_empty() or not (id in data.get("levels_unlocked", [])):
		return
	data["start_level"] = id
	data["run"] = {}
	_load(data)


## Retry for levels 1-3, which live in game.tscn and can't be reloaded on
## their own: reloads the game world with what Ren has now and starts level
## `id` from its beginning. Works in F6 runs too, without making them save.
func restart_level(id: String) -> void:
	var was_active := active
	# a copy: the snapshot shares GameManager's dictionaries, which _load clears
	var data := _snapshot().duplicate(true)
	data["start_level"] = id
	data["run"] = {}
	_load(data)
	active = was_active


func _load(data: Dictionary) -> void:
	_reset_session()
	for id in data.get("levels_unlocked", []):
		unlocked[id] = true
	for slot in data.get("echoes", []):
		GameManager.unlock_echo(int(slot))
	for key in data.get("story_seen", []):
		StoryDirector.seen[key] = true
	GameManager.boss_defeated = data.get("boss_defeated", false)
	for level in data.get("level_best", {}):
		GameManager.level_best[level] = int(data["level_best"][level])
	for level in data.get("level_stars", {}):
		if data["level_stars"][level]:
			GameManager.level_stars[level] = true
	for level in data.get("level_time", {}):
		GameManager.level_time[level] = float(data["level_time"][level])
	for level in data.get("level_deaths", {}):
		GameManager.level_deaths[level] = int(data["level_deaths"][level])
	active = true
	_pending = data
	StoryDirector.cover.color.a = 1.0
	StoryDirector.cover.show()
	get_tree().change_scene_to_file(GAME)


## Back to the main menu (progress since the last lantern is not kept).
func quit_to_menu() -> void:
	get_tree().paused = false
	active = false
	_reset_session()
	get_tree().change_scene_to_file(MENU)


func _reset_session() -> void:
	StoryDirector.cancel()
	GameManager.reset_progress()
	Echoes.reset_all()
	StoryDirector.reset()
	StoryDirector.arrival_pending = false
	StoryDirector.hold_guides = false
	unlocked.clear()
	_pending = {}


func _on_node_added(node: Node) -> void:
	if node.is_in_group("boss") and node.has_signal("defeated"):
		node.defeated.connect(_on_boss_defeated)
	if not _pending.is_empty() and node.name == "game" and node.get_parent() == get_tree().root:
		_restore.call_deferred(_pending)
		_pending = {}


func _on_boss_defeated() -> void:
	GameManager.boss_defeated = true
	save()


## Loading into level `here`: guides for mechanics that already appear in an
## earlier level (or the tutorial area) count as heard, so they don't stop Ren
## to explain them again, e.g. after jumping ahead with the level select.
func _skip_earlier_guides(here: String) -> void:
	var order: Array = LevelList.LEVELS.map(func(e): return e["id"])
	var at := order.find(here)
	if at < 0:
		return
	for entry in StoryDirector._watched:
		var node = entry["node"].get_ref()
		if node == null:
			continue
		var id := LevelList.id_for(node)
		var where := order.find(id)
		if id == "tutorial" or (where >= 0 and where < at):
			StoryDirector.seen["guide:" + entry["key"]] = true


## Puts the loaded save into the fresh game scene.
func _restore(data: Dictionary) -> void:
	var tree := get_tree()
	# let the player, camera and zones set themselves up first
	await tree.physics_frame
	await tree.physics_frame
	await tree.process_frame
	var game := tree.current_scene
	for stone in tree.get_nodes_in_group("collectible"):
		if "unlocks_echo_slot" in stone and GameManager.is_echo_unlocked(stone.unlocks_echo_slot):
			stone.queue_free()
	var level: String = data.get("start_level", "")
	# a beaten boss stays beaten, unless the boss fight is the level picked
	if GameManager.boss_defeated and level != "boss":
		for boss in tree.get_nodes_in_group("boss"):
			boss.queue_free()  # its exit portal opens once it is gone
	var pos := Vector2(data["checkpoint"][0], data["checkpoint"][1])
	if level != "":
		pos = LevelList.start_position(game, level)
	var player := tree.get_first_node_in_group("player") as CharacterBody2D
	if player:
		player.global_position = pos
		player.velocity = Vector2.ZERO
	# light the lantern they saved at, quietly
	var here := level
	for lantern in game.find_children("*", "Area2D", true, false):
		if lantern is SavePoint and lantern.global_position.distance_to(pos) < 1.0:
			lantern.is_activated = true
			lantern.get_node("AnimatedSprite2D").play("active")
			if here == "":
				here = LevelList.id_for(lantern)
	_skip_earlier_guides(here)
	# before the checkpoint: setting it saves, and the save should keep the run
	Echoes.restore_run(data.get("run", {}))
	var root := game.get_node_or_null(NodePath(LevelList.entry(level).get("level", ""))) if level != "" else null
	if EarlyLevels.LEVELS.has(level):
		LevelClear.early.begin(level)  # levels 1-3 time theirs
	elif root and root.has_method("begin_echo_run"):
		root.begin_echo_run()  # levels 4-9 score the run from the start
	GameManager.set_checkpoint(pos)
	await tree.create_timer(0.3).timeout
	# runs through pauses: a guide may start talking (and pause) during the fade
	var fade := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	await fade.tween_property(StoryDirector.cover, "color:a", 0.0, 0.6).finished
	StoryDirector.cover.hide()
