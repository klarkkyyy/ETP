#rising_flood.gd
# Water that floods a shaft once start() is called (e.g. from a lever's
# pad_activated) and drowns the player when it reaches them. Place the node
# with its origin at the top-left of where the surface starts; it rises at
# rise_speed until the surface reaches `top`.
# When the player dies it drains back to reset_gap below their respawn point
# (never lower than where it started) and waits `grace` seconds before rising
# again, so every attempt at the climb gets the same head start. A respawn
# out of the water's reach drains it until the player comes back.
extends Node2D

const SFX_START = "res://audio/sfx/stone_door.mp3"
const WATER_TEX = "res://assets/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/UPDATES/UPDATE ver 1.1/still_water_tile.png"

@export var width: float = 256.0
@export var top: float = -512.0          # surface stops here, relative to this node
@export var rise_speed: float = 24.0     # px/s
@export var reset_gap: float = 176.0     # surface after a respawn: this far below the player
@export var grace: float = 2.0           # seconds before it rises again after a respawn
@export var depth: float = 1200.0        # how far the water body reaches below the surface
@export var story_event: String = ""     # StoryDirector.event() to play when it starts

var surface: float = 0.0                 # current surface y, relative to this node
var rising := false
var _started := false
var _wait := 0.0
var _player: Node2D = null
var _player_was_dead := false
var _away := false                       # drained until the player is back in the water's reach
var _surf: Sprite2D
var _body: ColorRect

func _ready() -> void:
	z_index = -12  # behind the level's walls, in front of its backdrop and decor
	_body = ColorRect.new()
	_body.color = Color(0.12, 0.42, 0.4, 0.62)
	_body.size = Vector2(width, depth)
	add_child(_body)
	_surf = Sprite2D.new()
	_surf.texture = load(WATER_TEX)
	_surf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_surf.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_surf.region_enabled = true
	_surf.region_rect = Rect2(0, 0, width, 12)
	_surf.centered = false
	_surf.modulate = Color(0.45, 0.85, 0.8, 0.9)
	add_child(_surf)
	visible = false
	_place()

## Opens the floodgate. Safe to call more than once.
func start() -> void:
	if _started:
		return
	_started = true
	rising = true
	visible = true
	SoundManager.play(SFX_START)
	if story_event != "" and StoryDirector.has_method("event"):
		StoryDirector.event(story_event)

func _physics_process(delta: float) -> void:
	if not _started:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dead: bool = _player.get("is_dead")
	if dead and not _player_was_dead:
		rising = false
	elif not dead and _player_was_dead:
		_on_respawned()
	_player_was_dead = dead
	if dead:
		return
	var p := to_local(_player.global_position)
	if _away:
		if p.x < 0.0 or p.x > width or p.y < top:
			return
		_away = false
		_wait = grace
	if _wait > 0.0:
		_wait -= delta
		if _wait <= 0.0:
			rising = true
	if rising and surface > top:
		surface = max(top, surface - rise_speed * delta)
		_place()
	if p.x >= 0.0 and p.x <= width and p.y > surface + 2.0:
		_player.die()

func _process(_delta: float) -> void:
	if visible:
		# drift the surface texture so the water looks alive
		_surf.region_rect.position.x = fmod(Time.get_ticks_msec() * 0.012, 32.0)

func _on_respawned() -> void:
	var at := to_local(_player.global_position)
	rising = false
	if at.x < 0.0 or at.x > width or at.y < top:
		# respawned somewhere the water can't reach: drain and wait for them to come back
		surface = 0.0
		_place()
		_wait = 0.0
		_away = true
		return
	surface = clamp(at.y + reset_gap, top, 0.0)
	_place()
	_wait = grace

func _place() -> void:
	_surf.position = Vector2(0, surface - 4)
	_body.position = Vector2(0, surface + 6)
