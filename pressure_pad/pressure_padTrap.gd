extends Area2D

signal pad_activated()
signal pad_deactivated()

var _player_count: int = 0
var _echo_count: int = 0
var is_pressed: bool = false

@export var trap_to_activate: Node2D

func _ready() -> void:
	add_to_group("pressure_pad")
	# Connect signals via code
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

# ── Echo Overlap (Called by echo.gd) ───────────────────────────────────────
func on_echo_enter(_echo: Area2D) -> void:
	_echo_count += 1
	_evaluate()

func on_echo_exit(_echo: Area2D) -> void:
	_echo_count = max(0, _echo_count - 1)
	_evaluate()

# ── Player Overlap ──────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") or body.name == "player":
		_player_count += 1
		_evaluate()

func _on_body_exited(body: Node) -> void:
	if body.is_in_group("player") or body.name == "player":
		_player_count = max(0, _player_count - 1)
		_evaluate()

# ── State logic ─────────────────────────────────────────────────────────────
# ── Inside pressure_pad.gd ──────────────────────────────────────────────────

func _evaluate() -> void:
	var should_press = (_player_count + _echo_count) > 0
	if should_press == is_pressed:
		return
	
	is_pressed = should_press
	
	if is_pressed:
		print("STEP 1: Pad Pressed!")
		emit_signal("pad_activated")
		_on_activated()
		
		if trap_to_activate:
			print("STEP 2: Activating Trap...")
			trap_to_activate.activate_trap()
	else:
		print("STEP 1: Pad Released!")
		emit_signal("pad_deactivated")
		_on_deactivated()
		
		# DEACTIVATE THE TRAP HERE
		if trap_to_activate:
			print("STEP 2: Deactivating Trap...")
			trap_to_activate.deactivate_trap()
# ── Visual feedback ─────────────────────────────────────────────────────────
func _on_activated() -> void:
	if $AnimatedSprite2D.sprite_frames.has_animation("pressed"):
		$AnimatedSprite2D.play("pressed")

func _on_deactivated() -> void:
	if $AnimatedSprite2D.sprite_frames.has_animation("unpressed"):
		$AnimatedSprite2D.play("unpressed")
