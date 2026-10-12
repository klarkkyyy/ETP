#boss_exit_portal.gd
# A teleport (see teleport.gd) that stays hidden and locked until the boss is
# dead, then fades in. Point `boss` at the boss node; once that node is gone or
# reports is_dead, the portal opens for good.
extends "res://scripts/teleport.gd"

const SFX_APPEAR = "res://audio/sfx/teleport.wav"

@export var boss: NodePath

var _open := false
var _base_scale := Vector2.ONE

func _ready() -> void:
	super._ready()
	_base_scale = scale
	is_locked = true
	visible = false

func _process(_delta: float) -> void:
	if _open:
		return
	var b := get_node_or_null(boss)
	if b == null or b.get("is_dead"):
		_reveal()

func _reveal() -> void:
	_open = true
	is_locked = false
	visible = true
	modulate.a = 0.0
	scale = _base_scale * 0.4
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 1.2)
	tw.tween_property(self, "scale", _base_scale, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	SoundManager.play(SFX_APPEAR, -6)
