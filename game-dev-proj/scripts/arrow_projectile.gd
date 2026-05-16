extends Area2D

var speed: float = 300.0
@export var damage: float = 25.0
var direction: Vector2 = Vector2.RIGHT

func launch(dir: Vector2) -> void:
	direction = dir

func _ready() -> void:
	$AnimatedSprite2D.play("default")
	body_entered.connect(_on_body_entered)
	$AnimatedSprite2D.flip_h = direction.x < 0

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body is TileMapLayer or body.name == "tile_sets":
		return
	if body.is_in_group("boss") and body.has_method("take_damage"):
		body.take_damage(damage)
		print("Arrow hit boss for: ", damage)
	queue_free()
