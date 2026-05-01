#door.gd
extends Node2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var col: CollisionShape2D = $StaticBody2D/CollisionShape2D

var is_open: bool = false
var _active_triggers: int = 0  

func trigger_open() -> void:
	_active_triggers += 1
	if _active_triggers == 1:
		open_door()

func trigger_close() -> void:
	_active_triggers = max(0, _active_triggers - 1)
	if _active_triggers == 0:
		close_door()

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


func _on_lever_pad_activated() -> void:
	trigger_open()

func _on_lever_pad_deactivated() -> void:
	trigger_close()

func _on_pressure_pad_pad_activated() -> void:
	trigger_open()

func _on_pressure_pad_pad_deactivated() -> void:
	trigger_close()
