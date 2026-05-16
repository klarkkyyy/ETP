# echo_button.gd
extends Area2D

@export var target_trap: NodePath
@export var trigger_once: bool = false

var _trap: Node = null
var _triggered: bool = false

func _ready() -> void:
	add_to_group("switch")
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if _triggered and trigger_once:
		return
	# Triggered by echo OR player standing on it
	if area.is_in_group("echo") or area.get_parent().is_in_group("player"):
		_fire()

func _fire() -> void:
	if trigger_once:
		_triggered = true
	_trap = get_node(target_trap)
	if _trap and _trap.has_method("activate_trap"):
		_trap.activate_trap()
