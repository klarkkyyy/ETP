#drop_enemy.gd
# An enemy that patrols back and forth and kills the player on contact.
# When hostile, it notices a player who comes into its patrol area at about
# its height and charges them, but it never leaves its patrol bounds (so it
# can't reach buttons placed outside them, and it can be lured under a trap).
# Nothing the player does can hurt it (jumping on it is just contact).
# The only way to kill it is a spike_trap landing on it: the trap calls
# kill_by_spikes() on anything in the "drop_enemy" group under its spikes.
extends Node2D

signal died(enemy: Node2D)
signal spotted_player(enemy: Node2D)

const SFX_DEATH = "res://audio/sfx/clear.mp3"
const SFX_ALERT = "res://audio/sfx/woosh_r.mp3"

@export var speed: float = 40.0            # pixels per second
@export var patrol_left: float = -64.0     # patrol bounds, as x offsets from where it's placed
@export var patrol_right: float = 64.0
@export var turn_pause: float = 0.4        # seconds it waits at each end
@export var start_direction: int = 1       # 1 = right, -1 = left
@export var sprite_faces_right: bool = true
@export var bob_height: float = 0.0        # > 0 makes it hover up and down (flyers)
@export var bob_speed: float = 3.0

@export_group("Hostility")
@export var hostile: bool = true
@export var chase_speed_multiplier: float = 1.6
@export var react_time: float = 0.3        # how long it "notices" before charging
@export var aggro_height: float = 40.0     # max vertical distance to the player to notice them
@export var aggro_margin: float = 0.0      # how far outside its patrol bounds it can notice the player

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox

var is_dead: bool = false
var _origin: Vector2
var _dir: int = 1
var _pause: float = 0.0
var _bob_t: float = 0.0
var _player: Node2D = null
var _chasing: bool = false
var _react: float = 0.0

func _ready() -> void:
	add_to_group("drop_enemy")
	_origin = position
	_dir = 1 if start_direction >= 0 else -1
	hurtbox.body_entered.connect(_on_hurtbox_body_entered)
	anim.play("move")
	_update_facing()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if bob_height > 0.0:
		_bob_t += delta * bob_speed
		position.y = _origin.y + sin(_bob_t) * bob_height
	var left := _origin.x + patrol_left
	var right := _origin.x + patrol_right

	if hostile and _can_see_player(left, right):
		if not _chasing:
			_start_chase()
		_chase(delta, left, right)
	else:
		if _chasing:
			_stop_chase()
		_patrol(delta, left, right)

	# A player standing still inside the hurtbox gets no new body_entered
	for body in hurtbox.get_overlapping_bodies():
		_on_hurtbox_body_entered(body)

func _patrol(delta: float, left: float, right: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		if _pause <= 0.0:
			_dir = -_dir
			_update_facing()
		return
	position.x += _dir * speed * delta
	if (_dir > 0 and position.x >= right) or (_dir < 0 and position.x <= left):
		position.x = clampf(position.x, left, right)
		_pause = maxf(turn_pause, 0.001)

func _can_see_player(left: float, right: float) -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return false
	if _player.get("is_dead"):
		return false
	var p: Vector2 = get_parent().to_local(_player.global_position) if get_parent() is Node2D else _player.global_position
	if p.x < left - aggro_margin or p.x > right + aggro_margin:
		return false
	return absf(p.y - position.y) <= aggro_height

func _start_chase() -> void:
	_chasing = true
	_react = react_time
	_pause = 0.0
	modulate = Color(1.7, 0.7, 0.7)
	SoundManager.play(SFX_ALERT, -14, 1.6)
	emit_signal("spotted_player", self)

func _chase(delta: float, left: float, right: float) -> void:
	var target_x := clampf(get_parent().to_local(_player.global_position).x, left, right)
	var dx := target_x - position.x
	if absf(dx) > 1.0:
		var d := 1 if dx > 0.0 else -1
		if d != _dir:
			_dir = d
			_update_facing()
	if _react > 0.0:
		_react -= delta
		modulate = modulate.lerp(Color.WHITE, 6.0 * delta)
		if _react <= 0.0:
			modulate = Color.WHITE
			if anim.sprite_frames.has_animation("chase"):
				anim.play("chase")
			else:
				anim.speed_scale = chase_speed_multiplier
		return
	var step := speed * chase_speed_multiplier * delta
	position.x += clampf(dx, -step, step)

func _stop_chase() -> void:
	_chasing = false
	_react = 0.0
	modulate = Color.WHITE
	anim.speed_scale = 1.0
	anim.play("move")

func _update_facing() -> void:
	anim.flip_h = (_dir < 0) == sprite_faces_right

func _on_hurtbox_body_entered(body: Node) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("die") and not body.is_dead:
		body.die()

## Called by spike_trap.gd. This is the only way this enemy dies.
func kill_by_spikes() -> void:
	if is_dead:
		return
	is_dead = true
	modulate = Color.WHITE
	anim.speed_scale = 1.0
	hurtbox.set_deferred("monitoring", false)
	SoundManager.play(SFX_DEATH, -6, 0.7)
	emit_signal("died", self)
	if anim.sprite_frames.has_animation("death"):
		anim.play("death")
		await anim.animation_finished
	queue_free()
