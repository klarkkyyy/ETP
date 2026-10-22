#title_layer.gd
extends CanvasLayer

@onready var title_container = $Node2D
var tween: Tween

func _ready():
	await get_tree().process_frame
	#title_container.modulate.a = 0
	## Push offscreen to the right initially
	#title_container.position.x = get_viewport().get_visible_rect().size.x + 100
	## Set your desired vertical position here (tweak 200 to taste)
	#title_container.position.y = 200

func play_intro():
	print("play_intro() called!")
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_parallel(false)

	var screen_width = get_viewport().get_visible_rect().size.x

	var center_x = (screen_width / 2.0) - 100.0
	var target_y = 125.0

	title_container.position.x = screen_width + 100
	title_container.position.y = target_y
	title_container.modulate.a = 0.0

	tween.tween_property(title_container, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property(title_container, "position:x", center_x, 6) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	tween.tween_interval(2.0)

	tween.tween_property(title_container, "position:x", -600.0, 3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tween.parallel().tween_property(title_container, "modulate:a", 0.0, 8)

	# Keep guide echoes quiet and Ren still until the title has slid off
	# screen, so dialogue doesn't cover it and he can't walk past the first
	# lantern before Old Tomas gets to talk about it.
	StoryDirector.hold_guides = true
	_set_player_locked(true)
	tween.parallel().tween_callback(_on_title_done).set_delay(3.0)

func _on_title_done() -> void:
	StoryDirector.hold_guides = false
	_set_player_locked(false)
	StoryDirector.guide_now("save_point")

func _set_player_locked(locked: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.controls_locked = locked
