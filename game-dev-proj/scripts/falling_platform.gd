extends Area2D

@onready var static_body: StaticBody2D = $StaticBody2D
@onready var anim: AnimatedSprite2D = $StaticBody2D/AnimatedSprite2D
@onready var col: CollisionShape2D = $StaticBody2D/CollisionShape2D

@export var open_delay: float = 1.0  # tweak this — time between landing and platform opening

var _triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	anim.play("closed")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _triggered:
		_triggered = true
		_activate()

func _activate() -> void:
	anim.play("loop")
	await get_tree().create_timer(open_delay).timeout
	# Disable collision at the moment the platform opens
	col.set_deferred("disabled", true)
	# Wait for the loop animation to finish (closing part)
	await anim.animation_finished
	col.set_deferred("disabled", false)
	_triggered = false
	anim.play("closed")
