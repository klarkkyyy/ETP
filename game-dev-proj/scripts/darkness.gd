#darkness.gd
# The Hollow outside the castle is dark: while Ren is inside `zone` the world
# is dimmed to near black (a CanvasModulate), the sky behind it too, and he
# carries a small cold light of his own. Echoes, guides and the amber
# stranger are light themselves (unshaded) and glow in it. Going through the
# castle door, the dark lifts.
extends Node

## Where it's dark (world coordinates).
@export var zone: Rect2
@export var dark_color: Color = Color(0.06, 0.06, 0.1)
@export var sky_color: Color = Color(0.13, 0.11, 0.2)
## The sky (a TextureRect on its own CanvasLayer, so the CanvasModulate misses it).
@export var sky: NodePath
@export var ren_light_color: Color = Color(0.72, 0.82, 1.0)
@export var ren_light_size: float = 1.35
@export var ren_light_energy: float = 1.05
## Things that give off a little light of their own in the dark (the echo stone).
@export var glows: Array[NodePath] = []
@export var glow_color: Color = Color(0.7, 0.55, 1.0)

const FADE_TIME = 1.6   # seconds for the dark to come down or lift

var _dark := 1.0
var _modulate: CanvasModulate
var _light: PointLight2D
var _sky: CanvasItem
var _player: Node2D

func _ready() -> void:
	_modulate = CanvasModulate.new()
	add_child(_modulate)
	_sky = get_node_or_null(sky) as CanvasItem
	for path in glows:
		var n := get_node_or_null(path) as Node2D
		if n:
			n.add_child.call_deferred(preload("res://story/stranger.gd").glow_light(glow_color, 0.45, 0.8))
	_apply()

func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
		_light = preload("res://story/stranger.gd").glow_light(ren_light_color, ren_light_size, ren_light_energy)
		_light.position = Vector2(0, -4)
		_player.add_child(_light)
		# start where he is, no fade (a Continue inside the castle is lit)
		_dark = 1.0 if zone.has_point(_player.global_position) else 0.0
	var want := 1.0 if zone.has_point(_player.global_position) else 0.0
	_dark = move_toward(_dark, want, delta / FADE_TIME)
	_apply()

func _apply() -> void:
	var t := smoothstep(0.0, 1.0, _dark)
	_modulate.color = Color.WHITE.lerp(dark_color, t)
	_modulate.visible = t > 0.001
	if _sky:
		_sky.modulate = Color.WHITE.lerp(sky_color, t)
	if _light:
		_light.energy = ren_light_energy * t
		_light.visible = t > 0.001
