extends Area2D

var velocity: Vector2 = Vector2.ZERO
var damage: float = 15.0
var _active: bool = false
var _travel_limit: float = 400.0
var _start_pos: Vector2 = Vector2.ZERO
var _current_target: Node2D = null

func _ready() -> void:
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)

func launch(direction: Vector2, orb_speed: float, orb_damage: float) -> void:
	velocity   = direction * orb_speed
	damage     = orb_damage
	_active    = true
	_start_pos = global_position
	visible    = true
	$CollisionShape2D.set_deferred("disabled", false)
	$orb.play("boss_orb")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if not _active:
		return
	global_position += velocity * delta
	if global_position.distance_to(_start_pos) > _travel_limit:
		_despawn()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_despawn()

func _despawn() -> void:
	_active = false
	visible = false
	$CollisionShape2D.set_deferred("disabled", true)
	$orb.stop()
	queue_free()
