extends Node

var checkpoint_position: Vector2 = Vector2.ZERO
var has_checkpoint: bool = false
var level_spawn: Vector2 = Vector2.ZERO 
var pending_teleport_id: String = ""
signal echo_unlocked(slot: int)

func set_checkpoint(pos: Vector2) -> void:
	checkpoint_position = pos
	has_checkpoint = true

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
