# warning.gd — a hint that stays hidden until flash() is called (when the eye
# bursts a floodgate), then blinks for a few seconds and fades away.
extends Node2D

@export var duration: float = 3.0

func _ready() -> void:
	visible = false

func flash() -> void:
	visible = true
	modulate = Color(1.0, 0.45, 0.4, 1.0)
	var tw := create_tween()
	for i in 4:
		tw.tween_property(self, "modulate:a", 0.35, 0.18)
		tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.tween_interval(maxf(0.0, duration - 1.44))
	tw.tween_property(self, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: visible = false)
