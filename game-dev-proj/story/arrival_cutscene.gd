# arrival_cutscene.gd
# Bridges the opening story into game.tscn: the screen opens like waking eyes,
# Ren falls out of the sky and lands hard, says a few words to no one, then
# the letterbox slides away and control is handed over.
# Added to game.tscn by StoryDirector when the intro sets `arrival_pending`.
extends Node

const SFX_WOOSH := "res://audio/sfx/woosh.mp3"
const SFX_LAND := "res://audio/sfx/land.wav"
const DUST := preload("res://effects/after_jump_dust.tscn")

const FALL_HEIGHT := 240.0
const START_ZOOM_MUL := 1.25
# World px the view is lowered so the ground clears the letterbox: more while
# zoomed in, less once the zoom has eased out.
const VIEW_DROP_START := 40.0
const VIEW_DROP := 14.0
const BAR_HEIGHT := 72.0

# Ren alone: the voice doesn't answer him here.
const LINES := [
	{"who": "Ren", "text": "Ugh... that's going to leave a mark."},
	{"who": "Ren", "text": "No cuts. No blood. Where's the street?"},
	{"who": "Ren", "text": "...Hello? Are you still there?"},
]

var _layer: CanvasLayer
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _flash: ColorRect
var _player: Node2D
var _camera: Camera2D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_run()


func _build() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40  # under the dialogue box (50), over the game
	add_child(_layer)
	_top_bar = _bar(true)
	_bottom_bar = _bar(false)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_flash)


func _bar(top: bool) -> ColorRect:
	var bar := ColorRect.new()
	bar.color = Color.BLACK
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.anchor_right = 1.0
	if top:
		bar.offset_bottom = BAR_HEIGHT
	else:
		bar.anchor_top = 1.0
		bar.anchor_bottom = 1.0
		bar.offset_top = -BAR_HEIGHT
	_layer.add_child(bar)
	return bar


func _run() -> void:
	var cover: ColorRect = StoryDirector.cover
	StoryDirector.hold_guides = true
	_player = get_tree().get_first_node_in_group("player")
	_camera = get_tree().get_first_node_in_group("camera")

	# Hold the player out of play: wait for the spawn routine, then freeze.
	_player.visible = false
	while _player.is_dead:
		await get_tree().process_frame
	_player.set_physics_process(false)
	_player.set_process_input(false)
	var land_pos := _floor_below(_player.global_position)
	_player.global_position = land_pos

	# Camera starts close in and slowly breathes out.
	var base_zoom := _camera.zoom
	_camera.zoom = base_zoom * START_ZOOM_MUL
	_camera.offset.y = VIEW_DROP_START
	_camera.reset_smoothing()
	var cam_t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	cam_t.tween_property(_camera, "zoom", base_zoom, 5.5)
	cam_t.tween_property(_camera, "offset:y", VIEW_DROP, 5.5)

	# Eyes opening: crack open, blink shut, then open for real.
	await _wait(0.6)
	var t := create_tween()
	t.tween_property(cover, "color:a", 0.55, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(cover, "color:a", 0.95, 0.25)
	t.tween_interval(0.2)
	t.tween_property(cover, "color:a", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	cover.hide()
	await _wait(0.5)

	# The fall: a glowing streak from above. The camera holds on the landing
	# spot instead of chasing him up there.
	_camera.hold = true
	_player.global_position = land_pos + Vector2(0, -FALL_HEIGHT)
	_player.visible = true
	_player.modulate = Color(1.8, 2.0, 2.6)
	_player.anim.play("jump_down")
	SoundManager.play(SFX_WOOSH, -4.0, 0.8)
	t = create_tween()
	t.tween_property(_player, "global_position", land_pos, 0.75) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished

	# Impact.
	_camera.hold = false
	SoundManager.play(SFX_LAND, 4.0, 0.6)
	_player.spawn_effect(DUST)
	_player.anim.play("before_or_after_jump")
	_player.anim.pause()
	_flash.color.a = 0.7
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
	_shake(0.45, 5.0)
	create_tween().tween_property(_player, "modulate", Color.WHITE, 1.2)
	await _wait(1.6)

	# Wake-up exchange (pauses the world while it plays). Ren is low on
	# screen, so the box goes up top.
	StoryDirector.box.at_top = true
	await StoryDirector.play("arrival", LINES)
	StoryDirector.box.at_top = false

	# On his feet; hand over control.
	_player.anim.play("idle")
	await _wait(0.3)
	t = create_tween().set_parallel()
	t.tween_property(_top_bar, "offset_top", -BAR_HEIGHT, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_top_bar, "offset_bottom", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bottom_bar, "offset_top", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_bottom_bar, "offset_bottom", BAR_HEIGHT, 0.9).set_trans(Tween.TRANS_SINE)
	t.tween_property(_camera, "offset:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)
	_player.set_physics_process(true)
	_player.set_process_input(true)
	StoryDirector.hold_guides = false
	await t.finished
	queue_free()


## Where the player would stand on the floor under `from`. The spawn point
## is above the ground (he normally just drops onto it).
func _floor_below(from: Vector2) -> Vector2:
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 600), _player.collision_mask, [_player.get_rid()])
	var hit := _player.get_world_2d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return from
	# Distance from the player's origin to the bottom of its hitbox.
	var feet := 0.0
	for child in _player.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			feet = child.position.y + child.shape.size.y / 2.0
			break
		if child is CollisionShape2D and child.shape is CapsuleShape2D:
			feet = child.position.y + child.shape.height / 2.0
			break
	return Vector2(from.x, hit.position.y - feet)


func _shake(duration: float, strength: float) -> void:
	var t := create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		t.tween_property(_camera, "offset", Vector2(0, VIEW_DROP) + off, 0.03)
	t.tween_property(_camera, "offset", Vector2(0, VIEW_DROP), 0.03)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
