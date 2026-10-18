# ArrowTrap.gd — spear launcher in the boss arena. A pressure pad arms it
# through its `linked_trap`: it fires when pressed and keeps firing every
# `recharge_time` while the pad stays held. Shoots along `arrow_direction`,
# turned by the node's rotation (a launcher rotated 180° shoots left).
# A spear that hits the boss spends the launcher for `spent_time`.
extends Area2D

const ArrowScene = preload("res://scenes/arrow.tscn")
const SPENT_TINT := Color(0.45, 0.4, 0.55, 0.7)

@onready var sprite = $AnimatedSprite2D
@export var damage_amount: float = 20.0
@export var recharge_time: float = 2.0
@export var spent_time: float = 10.0
@export var arrow_direction: Vector2 = Vector2.RIGHT

var _armed: bool = false
var _cooldown: float = 0.0

func activate_trap():
	_armed = true
	_try_fire()

func deactivate_trap():
	_armed = false

func is_ready() -> bool:
	return _cooldown <= 0.0

## Called by its spear when it hits the boss.
func spend():
	_cooldown = maxf(_cooldown, spent_time)
	sprite.modulate = SPENT_TINT

func _physics_process(delta: float):
	if _cooldown <= 0.0:
		return
	_cooldown -= delta
	if _cooldown <= 0.0:
		sprite.modulate = Color.WHITE
		_try_fire()

func _try_fire():
	if not _armed or _cooldown > 0.0:
		return
	_cooldown = recharge_time
	sprite.modulate.a = 0.5  # dim while recharging
	sprite.stop()
	sprite.play("default")
	var dir := arrow_direction.rotated(global_rotation).normalized()
	var arrow = ArrowScene.instantiate()
	arrow.direction = dir
	arrow.damage = damage_amount
	arrow.source = self
	arrow.position = get_parent().to_local(global_position + dir * 8.0)
	# Often called from a pad's body_entered, mid physics step.
	get_parent().add_child.call_deferred(arrow)
