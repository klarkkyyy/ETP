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
# Per level: the fewest echoes it was cleared with, whether it earned a star
# (cleared at or under its echo goal), its fastest clear and the fewest deaths
# in a clear. Saved by SaveManager.
var level_best: Dictionary = {}    # level name -> fewest echoes used
var level_stars: Dictionary = {}   # level name -> true
var level_time: Dictionary = {}    # level name -> fastest clear, in seconds
var level_deaths: Dictionary = {}  # level name -> fewest deaths in a clear
var boss_defeated: bool = false

# ── Secrets ──────────────────────────────────────────────────────────────────
# Hidden rooms with a chest (scripts/secret_chest.gd), a few levels apart.
# Saved by SaveManager; `secret_found` is the hook for store achievements.
signal secret_found(id: String)
const SECRETS := ["l5_ossuary", "l8_cracked_ceiling", "l10_under_grate"]
var secrets: Dictionary = {}       # secret id -> true

## Marks a secret found; returns false if it already was.
func find_secret(id: String) -> bool:
	if secrets.has(id):
		return false
	secrets[id] = true
	secret_found.emit(id)
	return true

## Records a clear; returns the level's records after it, and whether this
## clear set a new fastest time.
func record_level_clear(level: String, used: int, star: bool, time: float, deaths: int) -> Dictionary:
	var new_time: bool = level_time.has(level) and time < level_time[level]
	level_best[level] = mini(level_best.get(level, used), used)
	level_time[level] = minf(level_time.get(level, time), time)
	level_deaths[level] = mini(level_deaths.get(level, deaths), deaths)
	if star:
		level_stars[level] = true
	return {"best": level_best[level], "best_time": level_time[level],
		"best_deaths": level_deaths[level], "new_time": new_time}

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
	level_time.clear()
	level_deaths.clear()
	secrets.clear()
	boss_defeated = false
