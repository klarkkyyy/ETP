#spike_trap.gd
# A spiked weight hanging from the ceiling. activate_trap() makes it shake for
# warn_time, then drop under gravity until its spikes hit the ground, stay there
# for linger_time, and winch back up. While falling or down, it kills any
# drop_enemy under it (kill_by_spikes()) and the player. Echoes are unharmed.
#
# Trigger it like the other traps: set a pressure pad's linked_trap (or an
# echo_button's target_trap) to this node, or call activate_trap() from a signal.
# Pressure pads can be pressed by echoes, so an echo can drop it too.
extends Node2D

signal warning()
signal dropped()
signal landed()
signal rearmed()

const SFX_WARN = "res://audio/sfx/lever_on.mp3"
const SFX_DROP = "res://audio/sfx/woosh.mp3"
const SFX_LAND = "res://audio/sfx/stone_door_close.mp3"

@export var warn_time: float = 0.35        # shake before it drops
@export var fall_gravity: float = 900.0    # px/s^2; lower = slower, more telegraphed fall
@export var linger_time: float = 0.3       # seconds the spikes stay down (still deadly)
@export var rise_speed: float = 150.0      # px/s back up to the ceiling
@export var cooldown: float = 0.4          # after it's back up, before it can fire again
@export var fall_distance: float = 0.0     # how far the spike tips drop; 0 = find the floor below
@export var repeat_while_held: bool = false  # keep cycling while its pad stays pressed

enum State { READY, WARNING, FALLING, LANDED, RISING, COOLDOWN }

@onready var weight: Node2D = $Weight
@onready var hitbox: Area2D = $Weight/Hitbox
@onready var chain: Line2D = $Chain

var state: State = State.READY
var _rest_y: float
var _drop_y: float
var _velocity: float = 0.0
var _timer: float = 0.0
var _held: bool = false
var _queued: bool = false
var _disabled: bool = false

func _ready() -> void:
	_rest_y = weight.position.y
	_drop_y = _rest_y + fall_distance
	hitbox.monitoring = false
	_update_chain()
	if fall_distance <= 0.0:
		_find_floor.call_deferred()

## How far the spike tips sit below the weight's origin.
func _tip_offset() -> float:
	return 16.0

func _find_floor() -> void:
	await get_tree().physics_frame
	var tip := weight.global_position + Vector2(0, _tip_offset())
	var query := PhysicsRayQueryParameters2D.create(tip, tip + Vector2(0, 2000), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if hit:
		_drop_y = _rest_y + (hit.position.y - tip.y) / global_scale.y
	else:
		_drop_y = _rest_y + 160.0

func activate_trap() -> void:
	_held = true
	if _disabled:
		return
	if state == State.READY:
		_start_warning()
	elif repeat_while_held:
		_queued = true

func deactivate_trap() -> void:
	_held = false
	_queued = false

## Stop the trap for good (e.g. once its enemies are dead, so a looping echo
## on its button doesn't keep dropping it on the player). A drop already in
## progress finishes and the weight stays up.
func disable_trap() -> void:
	_disabled = true
	_queued = false

func _start_warning() -> void:
	state = State.WARNING
	_timer = warn_time
	SoundManager.play(SFX_WARN, -12, 1.4)
	emit_signal("warning")

func _physics_process(delta: float) -> void:
	match state:
		State.WARNING:
			_timer -= delta
			weight.position.x = randf_range(-1.0, 1.0)
			if _timer <= 0.0:
				weight.position.x = 0.0
				state = State.FALLING
				_velocity = 0.0
				hitbox.monitoring = true
				SoundManager.play(SFX_DROP, -10, 1.2)
				emit_signal("dropped")
		State.FALLING:
			_velocity += fall_gravity * delta
			weight.position.y += _velocity * delta
			if weight.position.y >= _drop_y:
				weight.position.y = _drop_y
				state = State.LANDED
				_timer = linger_time
				SoundManager.play(SFX_LAND, -8, 1.3)
				emit_signal("landed")
			_kill_overlapping()
		State.LANDED:
			_timer -= delta
			_kill_overlapping()
			if _timer <= 0.0:
				hitbox.set_deferred("monitoring", false)
				state = State.RISING
		State.RISING:
			weight.position.y -= rise_speed * delta
			if weight.position.y <= _rest_y:
				weight.position.y = _rest_y
				state = State.COOLDOWN
				_timer = cooldown
		State.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				state = State.READY
				emit_signal("rearmed")
				if repeat_while_held and not _disabled and (_held or _queued):
					_queued = false
					_start_warning()
	_update_chain()

func _kill_overlapping() -> void:
	for area in hitbox.get_overlapping_areas():
		var enemy := area.get_parent()
		if enemy and enemy.is_in_group("drop_enemy") and enemy.has_method("kill_by_spikes"):
			enemy.kill_by_spikes()
	for body in hitbox.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("die") and not body.is_dead:
			body.die()

func _update_chain() -> void:
	chain.set_point_position(1, Vector2(0, weight.position.y - 8.0))
