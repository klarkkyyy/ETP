# eye_bolt.gd — the Overseer's bolt. Kills Ren on touch; walls and echoes stop
# it (the echo survives: it's a shield, unlike against the boss 1 orbs).
extends Area2D

const MAX_TRAVEL := 480.0

var velocity := Vector2.ZERO
var tint := Color(1.0, 0.45, 0.35)
var _start := Vector2.ZERO
var _age := 0.0

func _ready() -> void:
	add_to_group("eye_bolt")
	z_index = 9
	collision_layer = 0
	collision_mask = 1 | 2 | 4  # world, player, echoes
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 3.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)

func launch(dir: Vector2, speed: float) -> void:
	velocity = dir * speed
	_start = global_position

func _physics_process(delta: float) -> void:
	_age += delta
	global_position += velocity * delta
	queue_redraw()
	if global_position.distance_to(_start) > MAX_TRAVEL:
		queue_free()

func _draw() -> void:
	var pulse := 0.8 + 0.2 * sin(_age * 20.0)
	draw_circle(Vector2.ZERO, 5.0 * pulse, Color(tint, 0.35))
	draw_circle(Vector2.ZERO, 3.0, tint)
	draw_circle(Vector2.ZERO, 1.4, Color(1.0, 0.9, 0.8))

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if not body.is_dead:
			body.die()
	queue_free()
