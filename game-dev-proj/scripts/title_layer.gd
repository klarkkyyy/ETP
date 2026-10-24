#title_layer.gd
# The game's title, the first time Ren walks into the castle: it fades in
# while rising a few px, holds, and fades out leaving an echo of itself (a
# faint copy that drifts outward and dissolves a little after it). Ren keeps
# moving; guide echoes wait until it's gone so nothing talks over it.
extends CanvasLayer

@onready var title_container = $Node2D
var tween: Tween

const FADE_IN = 2.2
const HOLD = 2.4
const FADE_OUT = 2.0
const RISE = 10.0   # px it rises while fading in

func play_intro():
	if tween:
		tween.kill()
	var screen_width = get_viewport().get_visible_rect().size.x
	var rest := Vector2((screen_width / 2.0) - 100.0, 125.0)
	title_container.position = rest + Vector2(0, RISE)
	title_container.modulate.a = 0.0
	title_container.scale = Vector2.ONE
	StoryDirector.hold_guides = true

	tween = create_tween()
	tween.tween_property(title_container, "modulate:a", 1.0, FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(title_container, "position", rest, FADE_IN) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_callback(_leave_echo.bind(rest))
	tween.tween_property(title_container, "modulate:a", 0.0, FADE_OUT) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_title_done)

## A faint copy of the title that swells outward from its centre and fades.
func _leave_echo(rest: Vector2) -> void:
	var echo: Node2D = title_container.duplicate()
	add_child(echo)
	move_child(echo, 0)   # behind the title
	echo.position = rest
	echo.modulate.a = 0.35
	# scale about the title's middle, not its top-left
	var middle := _middle(title_container)
	var grow := 1.08
	var t := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(echo, "scale", Vector2(grow, grow), FADE_OUT + 0.8)
	t.tween_property(echo, "position", rest - middle * (grow - 1.0), FADE_OUT + 0.8)
	t.tween_property(echo, "modulate:a", 0.0, FADE_OUT + 0.8)
	t.chain().tween_callback(echo.queue_free)

## The centre of the title's labels, relative to its node.
func _middle(node: Node2D) -> Vector2:
	var r := Rect2()
	var first := true
	for c in node.get_children():
		if c is Control:
			var cr := Rect2(c.position, c.size)
			r = cr if first else r.merge(cr)
			first = false
	return r.get_center()

func _on_title_done() -> void:
	StoryDirector.hold_guides = false
	StoryDirector.guide_now("save_point")
