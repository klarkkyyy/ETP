# trap1.gd — floor spikes in the boss arena. A pressure pad arms it through
# its `linked_trap`; while the pad is held (by the player or an echo) the spikes
# keep cycling, and a cycle that catches the boss surfaced over it hurts it.
# A trap that lands a hit is spent for `spent_time`, so the player has to use
# the others in the meantime.
extends Area2D

@onready var sprite = $AnimatedSprite2D
@export var damage_amount: float = 20.0
@export var recharge_time: float = 1.2
@export var spent_time: float = 10.0

# Animation frames where the spikes are out of the floor.
const SPIKES_UP_FROM := 1
const SPIKES_UP_TO := 4
const SPENT_TINT := Color(0.45, 0.4, 0.55, 0.7)

var _armed: bool = false
var _cycling: bool = false
var _landed: bool = false
var _cooldown: float = 0.0

func _ready():
	sprite.animation_finished.connect(_on_cycle_finished)
	_show_ready()

func activate_trap():
	_armed = true
	_try_fire()

func deactivate_trap():
	_armed = false

func is_ready() -> bool:
	return not _cycling and _cooldown <= 0.0

func _physics_process(delta: float):
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			sprite.modulate = Color.WHITE
			_try_fire()
	if not _cycling or _landed:
		return
	if sprite.frame < SPIKES_UP_FROM or sprite.frame > SPIKES_UP_TO:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("boss") and body.has_method("take_damage"):
			_landed = body.take_damage(damage_amount)

func _try_fire():
	if not _armed or not is_ready():
		return
	_cycling = true
	_landed = false
	sprite.play("default")

func _on_cycle_finished():
	_cycling = false
	_show_ready()
	if _landed:
		_cooldown = spent_time
		sprite.modulate = SPENT_TINT
	else:
		_cooldown = recharge_time
		sprite.modulate.a = 0.45  # dim while recharging

# Rest on the first frame (spike tips just showing) so the trap is visible.
func _show_ready():
	sprite.stop()
	sprite.frame = 0
