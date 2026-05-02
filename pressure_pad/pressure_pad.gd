extends Area2D

## Pressure pad — handles overlap from BOTH the player body and Echo Area2Ds.
## Add this node to the group "pressure_pad" in the Inspector.

signal pad_activated()
signal pad_deactivated()

var _player_count: int = 0
var _echo_count: int = 0
var is_pressed: bool = false


func _ready() -> void:
	add_to_group("pressure_pad")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# ── Called directly by echo.gd ─────────────────────────────────────────────

func on_echo_enter(_echo: Area2D) -> void:
	_echo_count += 1
	_evaluate()


func on_echo_exit(_echo: Area2D) -> void:
	_echo_count = max(0, _echo_count - 1)
	_evaluate()


# ── Player overlap ──────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_player_count += 1
		_evaluate()


func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player"):
		_player_count = max(0, _player_count - 1)
		_evaluate()


# ── State logic ─────────────────────────────────────────────────────────────

func _evaluate() -> void:
	var should_press = (_player_count + _echo_count) > 0
	if should_press == is_pressed:
		return
	is_pressed = should_press
	if is_pressed:
		emit_signal("pad_activated")
		_on_activated()
	else:
		emit_signal("pad_deactivated")
		_on_deactivated()


# ── Visual feedback ─────────────────────────────────────────────────────────

func _on_activated() -> void:
	if $AnimatedSprite2D.sprite_frames.has_animation("pressed"):
		$AnimatedSprite2D.play("pressed")


func _on_deactivated() -> void:
	if $AnimatedSprite2D.sprite_frames.has_animation("unpressed"):
		$AnimatedSprite2D.play("unpressed")
