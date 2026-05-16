extends CanvasLayer

var rect: ColorRect

const RECORDING_OVERLAY = Color(0.0, 0.0, 0.0, 0.35)
const FADE_IN_SPEED = 0.2
const FADE_OUT_SPEED = 0.3

@export var sfx_start: String = "res://audio/sfx/woosh.mp3"
@export var sfx_stop: String = "res://audio/sfx/woosh_r.mp3"

func _ready() -> void:
	rect = ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

func flash_start(slot: int) -> void:
	SoundManager.play(sfx_start)
	var tween = create_tween()
	tween.tween_property(rect, "color", RECORDING_OVERLAY, FADE_IN_SPEED)

func flash_stop(slot: int) -> void:
	SoundManager.play(sfx_stop)
	var tween = create_tween()
	tween.tween_property(rect, "color:a", 0.0, FADE_OUT_SPEED)
