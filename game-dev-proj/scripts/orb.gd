# orb.gd — the guardian's orb. Kills the player on touch, stops at walls and
# pillars (passes over one-way ledges), and is swallowed by an echo (echo.gd
# looks for the "orb" group).
extends Area2D

const MAX_TRAVEL := 520.0

var velocity: Vector2 = Vector2.ZERO
var _start_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("orb")
	body_entered.connect(_on_body_entered)
	$orb.play("boss_orb")

func launch(direction: Vector2, orb_speed: float) -> void:
	velocity = direction * orb_speed
	_start_pos = global_position

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	if global_position.distance_to(_start_pos) > MAX_TRAVEL:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not body.is_dead:
			body.die()
		queue_free()
	elif body is TileMapLayer or body is TileMap:
		queue_free()
