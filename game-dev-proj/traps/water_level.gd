#water_level.gd
# A pool whose surface moves between two heights, `low` (drained) and `high`
# (full), both relative to this node. raise() and lower() send it toward one
# or the other at `speed`; connect a pressure pad's or lever's pad_activated /
# pad_deactivated to them, so an echo standing on a valve can hold a channel
# drained (or a tank full) while Ren gets on with it. Like the rising flood it
# drowns the player it covers, and crates (scripts/box.gd) in it float on the
# surface, so filling a tank lifts a crate, and whoever stands on it.
extends Node2D

const WATER_TEX = "res://assets/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/UPDATES/UPDATE ver 1.1/still_water_tile.png"
const SFX_FLOW = "res://audio/sfx/stone_door.mp3"

@export var width: float = 256.0
@export var low: float = 0.0             # surface when drained (relative y; larger is lower)
@export var high: float = -128.0         # surface when full
@export var speed: float = 40.0          # px/s
@export var start_full: bool = true
@export var depth: float = 1200.0        # how far the water body reaches below the surface
@export var drown_margin_left: float = 0.0  # px at the left edge that don't drown (a ledge overhanging the water)

var surface: float
var _target: float
var _player: Node2D = null
var _surf: Sprite2D
var _body: ColorRect

func _ready() -> void:
	z_index = -12  # behind the level's walls, in front of its backdrop and decor
	_body = ColorRect.new()
	_body.color = Color(0.1, 0.36, 0.34, 0.62)
	_body.size = Vector2(width, depth)
	add_child(_body)
	_surf = Sprite2D.new()
	_surf.texture = load(WATER_TEX)
	_surf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_surf.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_surf.region_enabled = true
	_surf.region_rect = Rect2(0, 0, width, 12)
	_surf.centered = false
	_surf.modulate = Color(0.42, 0.8, 0.76, 0.9)
	add_child(_surf)
	surface = high if start_full else low
	_target = surface
	_place()

## Fill toward `high`.
func raise() -> void:
	_go(high)

## Drain toward `low`.
func lower() -> void:
	_go(low)

func _go(to: float) -> void:
	if is_equal_approx(_target, to):
		return
	_target = to
	SoundManager.play(SFX_FLOW, -10.0, 1.3)

func _physics_process(delta: float) -> void:
	if not is_equal_approx(surface, _target):
		surface = move_toward(surface, _target, speed * delta)
		_place()
	for crate in get_tree().get_nodes_in_group("box"):
		var c := to_local(crate.global_position)
		if c.x >= 0.0 and c.x <= width and crate.has_method("float_on"):
			crate.float_on(global_position.y + surface)
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	if _player.get("is_dead"):
		return
	var p := to_local(_player.global_position)
	if p.x >= drown_margin_left and p.x <= width and p.y > surface + 2.0:
		_player.die()

func _process(_delta: float) -> void:
	# drift the surface texture so the water looks alive
	_surf.region_rect.position.x = fmod(Time.get_ticks_msec() * 0.012, 32.0)

func _place() -> void:
	_surf.position = Vector2(0, surface - 4)
	_body.position = Vector2(0, surface + 6)
