extends Area2D

@export var collectible_type: String = "echo1"
@export var value: int = 1  
@export var unlocks_echo_slot: int = 1
@export var sfx_path: String = "res://audio/sfx/collect.wav" 
@export var float_amplitude: float = 3.0
@export var float_speed: float = 2.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $CollisionShape2D

var _base_y: float = 0.0
var _float_timer: float = 0.0
var _collected: bool = false

func _ready() -> void:
	add_to_group("collectible")
	body_entered.connect(_on_body_entered)
	anim.play("idle")
	_base_y = position.y

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and not _collected:
		_collect()

func _collect() -> void:
	_collected = true
	col.set_deferred("disabled", true)
	SoundManager.play(sfx_path)
	anim.play("collect")
	GameManager.unlock_echo(unlocks_echo_slot)
	await anim.animation_finished
	queue_free()

func _process(delta: float) -> void:
	if _collected:
		return
	_float_timer += delta
	position.y = _base_y + sin(_float_timer * float_speed) * float_amplitude
