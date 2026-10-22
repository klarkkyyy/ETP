extends Node

var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
var level_spawn: Vector2 = Vector2.ZERO 
var pending_teleport_id: String = ""
signal echo_unlocked(slot: int)
signal checkpoint_changed(pos: Vector2)  # a new checkpoint; refills the echo budget
signal player_teleported(from_id: String, to_id: String)

func set_checkpoint(pos: Vector2) -> void:
	var changed := not has_checkpoint or pos != checkpoint_position
	checkpoint_position = pos
	has_checkpoint = true
	if changed:
		checkpoint_changed.emit(pos)

func get_respawn_position() -> Vector2:
	return checkpoint_position if has_checkpoint else level_spawn

func reset_level() -> void:
	has_checkpoint = false

func change_scene(scene_path: String) -> void:  # ← add this
	get_tree().change_scene_to_file(scene_path)
	
# ── Collectibles ─────────────────────────────────────────────────────────────
var collectibles: Dictionary = {
	"echo1": 0,
	"echo2": 0,
	"echo3": 0
}
var echo_unlocks: Dictionary = {
	1: false,  
	2: false,  
	3: false  
}

func unlock_echo(slot: int) -> void:
	if echo_unlocks.has(slot):
		echo_unlocks[slot] = true
		print("Echo slot unlocked: ", slot)
		emit_signal("echo_unlocked", slot)

func is_echo_unlocked(slot: int) -> bool:
	return echo_unlocks.get(slot, false)

# ── Echo stars ───────────────────────────────────────────────────────────────
# Per level: the fewest echoes it was cleared with, and whether it earned a star
# (cleared at or under its echo goal). Saved by SaveManager.
var level_best: Dictionary = {}   # level name -> fewest echoes used
var level_stars: Dictionary = {}  # level name -> true
var boss_defeated: bool = false

## Records a clear; returns the best (fewest) echo count for that level.
func record_level_clear(level: String, used: int, star: bool) -> int:
	level_best[level] = mini(level_best.get(level, used), used)
	if star:
		level_stars[level] = true
	return level_best[level]

func has_star(level: String) -> bool:
	return level_stars.get(level, false)

func star_count() -> int:
	return level_stars.size()

## Forgets the whole run: a new game, a Continue (before loading the save),
## or quitting to the menu.
func reset_progress() -> void:
	checkpoint_position = Vector2.ZERO
	has_checkpoint = false
	pending_teleport_id = ""
	for slot in echo_unlocks:
		echo_unlocks[slot] = false
	level_best.clear()
	level_stars.clear()
	boss_defeated = false
