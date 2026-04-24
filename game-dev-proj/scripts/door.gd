extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $StaticBody2D/CollisionShape2D

var is_open: bool = false


# ── Called by pad_activated / pad_deactivated signals ─────────────────────

func _on_pressure_pad_pad_activated() -> void:
	open_door()

func _on_pressure_pad_pad_deactivated() -> void:
	close_door()


# ── Door logic ─────────────────────────────────────────────────────────────

func open_door() -> void:
	if is_open:
		return
	is_open = true
	col.set_deferred("disabled", true)
	anim.play("opening")
	await anim.animation_finished
	anim.play("open")


func close_door() -> void:
	if not is_open:
		return
	is_open = false
	col.set_deferred("disabled", false)
	anim.play("closing")
	await anim.animation_finished
	anim.play("closed")
