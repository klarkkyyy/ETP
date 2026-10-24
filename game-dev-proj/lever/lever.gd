#lever.gd
extends Area2D

signal pad_activated()
signal pad_deactivated()

## Flips back off when Ren respawns (as crates go home), so a retry starts as the first try did.
@export var reset_on_respawn: bool = false

var is_pressed: bool = false
var _player_nearby: bool = false
var _player: Node2D
var _player_was_dead := false

@onready var SFX_ON = $AudioStreamPlayer2D
@onready var SFX_OFF = $AudioStreamPlayer2D2

func _ready() -> void:
	add_to_group("lever")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	$AnimatedSprite2D.play("left_right")
	$AnimatedSprite2D.pause()
	$AnimatedSprite2D.frame = 0

func _physics_process(_delta: float) -> void:
	if not reset_on_respawn:
		set_physics_process(false)
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dead: bool = _player.get("is_dead")
	if _player_was_dead and not dead and is_pressed:
		_toggle()
	_player_was_dead = dead

func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		_toggle()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = true

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_nearby = false

func _toggle() -> void:
	is_pressed = !is_pressed
	if is_pressed:
		emit_signal("pad_activated")
		_on_activated()
	else:
		emit_signal("pad_deactivated")
		_on_deactivated()


func _on_activated() -> void:
	SFX_ON.play()
	$AnimatedSprite2D.speed_scale = 1.0
	$AnimatedSprite2D.play("left_right")

func _on_deactivated() -> void:
	SFX_OFF.play()
	$AnimatedSprite2D.speed_scale = 1.0
	$AnimatedSprite2D.play("right_left")


func on_echo_interact(_echo: Area2D) -> void:
	_toggle()

func on_echo_enter(_echo: Area2D) -> void:
	pass

func on_echo_exit(_echo: Area2D) -> void:
	pass
