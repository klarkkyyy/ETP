#secret_wall.gd
# A piece of wall that's really a door: drawn with the level's own wall tiles
# (a TileMapLayer child) over a StaticBody2D child, it sinks and fades away
# while something holds it open (trigger_open/trigger_close, like door.gd, so
# a pressure pad's signals can drive it) and comes back when let go. It also
# stays open while Ren is in the room behind it (`inside`), so he's never shut
# in; once he's back out it closes, and it always starts closed.
extends Node2D

## How far it sinks when open, px.
@export var drop: float = 48.0
## The room behind it and its doorway, in the parent's coordinates: open while Ren is in here.
@export var inside: Rect2

const SFX_OPEN = "res://audio/sfx/stone_door.mp3"
const SFX_CLOSE = "res://audio/sfx/stone_door_close.mp3"
const SLIDE_TIME = 0.6

var _triggers := 0
var _open := false
var _home: Vector2
var _tween: Tween
var _ren_inside := false
var _player: Node2D
@onready var _shape: CollisionShape2D = $Body/CollisionShape2D

func _ready() -> void:
	_home = position
	_update(true)

func _physics_process(_delta: float) -> void:
	if inside.size == Vector2.ZERO:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var now := inside.has_point(get_parent().to_local(_player.global_position))
	if now != _ren_inside:
		_ren_inside = now
		_update()

func trigger_open() -> void:
	_triggers += 1
	_update()

func trigger_close() -> void:
	_triggers = maxi(0, _triggers - 1)
	_update()

func _update(instant := false) -> void:
	var open := _triggers > 0 or _ren_inside
	if open == _open and not instant:
		return
	_open = open
	if _tween:
		_tween.kill()
	if open:
		_shape.set_deferred("disabled", true)
	if instant:
		position = _home + Vector2(0, drop if open else 0.0)
		modulate.a = 0.0 if open else 1.0
		_shape.set_deferred("disabled", open)
		return
	SoundManager.play(SFX_OPEN if open else SFX_CLOSE, -8)
	_tween = create_tween().set_parallel()
	_tween.tween_property(self, "position", _home + Vector2(0, drop if open else 0.0), SLIDE_TIME)
	_tween.tween_property(self, "modulate:a", 0.0 if open else 1.0, SLIDE_TIME)
	if not open:
		_tween.chain().tween_callback(func(): _shape.disabled = false)
