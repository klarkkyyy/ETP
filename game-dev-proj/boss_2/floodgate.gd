# floodgate.gd — the last floodgate. An all_pads_trigger calls activate_trap()
# once every valve lever is pulled: the gate lifts and a torrent pours across
# the chamber from `from_x` toward `to_x` (px, relative to this node, between
# `top` and `bottom`), washing the Overseer away. It passes under Ren's ledge
# and never hurts him. The exit portal opens once the eye is gone.
extends Node2D

const WATER_TEX = "res://assets/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/UPDATES/UPDATE ver 1.1/still_water_tile.png"
const SFX_OPEN = "res://audio/sfx/stone_door.mp3"

@export var overseer: NodePath
@export var gate: NodePath
@export var from_x: float = 0.0
@export var to_x: float = -800.0
@export var top: float = 0.0
@export var bottom: float = 64.0
@export var duration: float = 1.4

var _done := false

func activate_trap() -> void:
	if _done:
		return
	_done = true
	var g := get_node_or_null(gate)
	if g and g.has_method("trigger_open"):
		g.trigger_open()
	SoundManager.play(SFX_OPEN, 0.0, 0.7)
	var cam := get_tree().get_first_node_in_group("camera")
	if cam and cam.has_method("shake"):
		cam.shake(0.8, 3.0)
	var body := ColorRect.new()
	body.color = Color(0.12, 0.42, 0.4, 0.75)
	body.position = Vector2(from_x, top + 6)
	body.size = Vector2(0, bottom - top - 6)
	body.z_index = 9
	add_child(body)
	var surf := Sprite2D.new()
	surf.texture = load(WATER_TEX)
	surf.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	surf.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	surf.region_enabled = true
	surf.centered = false
	surf.modulate = Color(0.45, 0.85, 0.8, 0.95)
	surf.position = Vector2(from_x, top - 4)
	surf.region_rect = Rect2(0, 0, 0, 12)
	surf.z_index = 9
	add_child(surf)
	var span := to_x - from_x
	var tw := create_tween().set_parallel()
	tw.tween_method(func(w: float) -> void:
		var left := minf(from_x, from_x + w)
		body.position.x = left
		body.size.x = absf(w)
		surf.position.x = left
		surf.region_rect.size.x = absf(w), 0.0, span, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await get_tree().create_timer(duration * 0.6).timeout
	var eye := get_node_or_null(overseer)
	if eye and eye.has_method("flush"):
		eye.flush()
	await tw.finished
	await get_tree().create_timer(2.5).timeout
	# the flood settles into a still pool
	var fade := create_tween().set_parallel()
	fade.tween_property(body, "color:a", 0.55, 1.5)
	fade.tween_property(surf, "modulate:a", 0.8, 1.5)
