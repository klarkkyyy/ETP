#level_culler.gd
# Autoload. game.tscn holds every level at once, and each one used to run its
# traps, platforms, enemies and physics bodies all the time, wherever Ren was.
# On phones that cost dropped Level 2 onwards to a crawl. This keeps a level
# running and drawn only while Ren is in it or the camera can see it; the rest
# are paused (PROCESS_MODE_DISABLED also takes their bodies out of the physics
# world) and hidden.
#
# A level here is any top-level node of game.tscn with a "Depth" child
# (scripts/parallax_region.gd), whose `area` already marks the level's extent.
# The levels that live directly in game.tscn (tutorial, level 1, boss) have
# none and always run.
extends Node

const GAME := "res://levels/game.tscn"
## Extra room around a level's area, in px.
const MARGIN := 96.0
## Physics frames every level runs after game.tscn loads before any is paused:
## traps measure their floors with rays on their first frames (stalactites,
## spike traps), and a paused level's collision isn't there to be found.
const SETTLE_FRAMES := 90

var _game: Node
var _player: Node2D
## level name -> its area in game coordinates (levels don't move; Retry swaps
## the node but keeps the name and transform)
var _areas := {}
var _active := {}   # level node -> true while on
var _settle := 0

func _ready() -> void:
	if OS.has_environment("ETP_NO_CULL"):   # dev: compare tests with every level running
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1000   # before Ren moves, so a level he just entered has its floor
	process_priority = 1000            # after the camera, so what it sees is drawn
	GameManager.player_teleported.connect(func(_a, _b): _update.call_deferred())

func _physics_process(_delta: float) -> void:
	if _game != null and _settle > 0:
		_settle -= 1
	_update()

func _process(_delta: float) -> void:
	_update()

func _update() -> void:
	var game := get_tree().current_scene
	if game == null or game.scene_file_path != GAME:
		_game = null
		return
	if game != _game:
		_game = game
		_player = null
		_areas.clear()
		_active.clear()
		_settle = SETTLE_FRAMES
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if _settle > 0:
		return
	var view := Rect2()
	var cam := get_viewport().get_camera_2d()
	if cam:
		var size := get_viewport().get_visible_rect().size / cam.zoom
		view = Rect2(cam.get_screen_center_position() - size * 0.5, size)
	var ren := _player.global_position
	for level in game.get_children():
		var area: Variant = _area_of(level)
		if area == null:
			continue
		var on: bool = (area as Rect2).has_point(ren) or (cam != null and (area as Rect2).intersects(view))
		if _active.get(level, null) == on:
			continue
		_active[level] = on
		level.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
		(level as CanvasItem).visible = on

func _area_of(level: Node) -> Variant:
	var key := String(level.name)
	if _areas.has(key):
		return _areas[key]
	var depth := level.get_node_or_null("Depth") as Node2D
	if not (level is Node2D) or depth == null or not ("area" in depth):
		_areas[key] = null
		return null
	var a: Rect2 = depth.area
	var r := Rect2(depth.to_global(a.position), Vector2.ZERO).expand(depth.to_global(a.end))
	_areas[key] = r.grow(MARGIN)
	return _areas[key]
