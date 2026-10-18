extends Area2D
# Spear fired by the boss arena's launchers (ArrowTrap.gd). Hurts the boss,
# stops at walls and pillars, flies over one-way ledges.

const MAX_TRAVEL := 900.0

var speed: float = 360.0
@export var damage: float = 15.0
var direction: Vector2 = Vector2.RIGHT
var source: Node = null  # the launcher, told when this spear lands a hit
var _start_pos: Vector2

func _ready() -> void:
	$AnimatedSprite2D.play("default")
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.flip_h = direction.x < 0
	_start_pos = global_position

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if global_position.distance_to(_start_pos) > MAX_TRAVEL:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("boss"):
		if body.has_method("take_damage") and body.take_damage(damage):
			if is_instance_valid(source) and source.has_method("spend"):
				source.spend()
		queue_free()
	elif body is TileMapLayer or body is TileMap:
		queue_free()
