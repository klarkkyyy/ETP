# switch_platforms.gd — platforms that are only solid while a pressure pad is
# held. Off, they're a faint echo-blue outline you fall through; on, solid.
# The pad sits where the player can't hold it and use the platforms at once,
# so it takes an echo standing on it. When the pad is released they flicker
# for `fade_grace` seconds before vanishing, so the player can react.
extends Node2D

@export var pad: NodePath
@export var platforms: Array[NodePath] = []
@export var fade_grace: float = 0.5

const ON := Color(0.8, 0.95, 1.0, 1.0)
const OFF := Color(0.4, 0.8, 1.0, 0.25)

var _bodies: Array[Node2D] = []
var _off_timer := -1.0

func _ready() -> void:
	for p in platforms:
		var b := get_node_or_null(p) as Node2D
		if b:
			_bodies.append(b)
	var pad_node := get_node(pad)
	pad_node.pad_activated.connect(_on_pad_on)
	pad_node.pad_deactivated.connect(_on_pad_off)
	_set_solid(pad_node.is_pressed)

func _on_pad_on() -> void:
	_off_timer = -1.0
	_set_solid(true)

func _on_pad_off() -> void:
	_off_timer = fade_grace

func _process(delta: float) -> void:
	if _off_timer < 0.0:
		return
	_off_timer -= delta
	var blink := 1.0 if fmod(_off_timer, 0.16) > 0.08 else 0.35
	for b in _bodies:
		b.modulate = Color(ON, blink)
	if _off_timer <= 0.0:
		_off_timer = -1.0
		_set_solid(false)

func _set_solid(on: bool) -> void:
	for b in _bodies:
		b.modulate = ON if on else OFF
		for cs in b.find_children("*", "CollisionShape2D", true, false):
			cs.set_deferred("disabled", not on)
