# story_intro.gd
# Opening cutscene played by "NEW GAME": the night of the accident, the fall
# into the Hollow Reach, and the Warden's bargain. Then loads the game.
# Advance: Jump / Interact / Enter.  Skip: Esc (pause).
extends Node

const NEXT_SCENE := "res://levels/game.tscn"
const FONT := preload("res://assets/fonts/BoldPixels.ttf")

const HERO := "Ren"
const WARDEN := "???"

var _bg: ColorRect
var _flash: ColorRect
var _narration: Label
var _hint: Label
var _shake_root: Control
var _box: DialogueBox
var _skipping := false
var _done := false


func _ready() -> void:
	MusicManager.stop(false)
	StoryDirector.reset()
	_build()
	_play()


func _build() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	_shake_root = Control.new()
	_shake_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_shake_root)

	_bg = ColorRect.new()
	_bg.color = Color.BLACK
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.offset_left = -40
	_bg.offset_top = -40
	_bg.offset_right = 40
	_bg.offset_bottom = 40
	_shake_root.add_child(_bg)

	_narration = Label.new()
	_narration.set_anchors_preset(Control.PRESET_FULL_RECT)
	_narration.offset_left = 120
	_narration.offset_right = -120
	_narration.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narration.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_narration.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_narration.add_theme_font_override("font", FONT)
	_narration.add_theme_font_size_override("font_size", 30)
	_narration.add_theme_color_override("font_color", Color(0.86, 0.86, 0.9))
	_narration.modulate.a = 0.0
	_shake_root.add_child(_narration)

	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)

	_hint = Label.new()
	_hint.text = "Esc - skip"
	_hint.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hint.offset_left = -150
	_hint.offset_top = 16
	_hint.add_theme_font_override("font", FONT)
	_hint.add_theme_font_size_override("font_size", 18)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	layer.add_child(_hint)

	_box = DialogueBox.new()
	_box.speakers[HERO] = {"color": Color(0.55, 0.8, 1.0), "pitch": 1.25}
	_box.speakers[WARDEN] = {"color": Color(0.95, 0.75, 0.4), "pitch": 0.7}
	_box.speakers["The Warden"] = _box.speakers[WARDEN]
	add_child(_box)


# ── Script ───────────────────────────────────────────────────────────────────

func _play() -> void:
	await _wait(1.0)

	# Earth. The last night.
	await _narrate("Tuesday.  11:47 PM.")
	await _narrate("Rain again. Same street home.\nSame song on repeat.")
	await _narrate("I kept telling myself I'd fix things tomorrow.\nCall Mom back. Finish what I started.")
	await _narrate("Tomorrow was always the plan.")

	# Headlights.
	await _headlights()
	await _wait(2.5)

	# The fall.
	await _narrate("...")
	await _narrate("Is this... what dying feels like?")
	await _wait(0.4)

	await _box.run([
		{"who": WARDEN, "text": "Not dying. Falling."},
		{"who": HERO, "text": "Who's there? I can't see anything."},
		{"who": WARDEN, "text": "Everyone torn from your world too early falls here. To the Hollow Reach."},
		{"who": WARDEN, "text": "A world built from what was left behind. Unfinished moments. Regrets. Echoes of the past."},
		{"who": HERO, "text": "No, no, no. There was a truck. I was walking home. I have to go back!"},
		{"who": HERO, "text": "My mom... I never even texted her back."},
		{"who": WARDEN, "text": "..."},
		{"who": WARDEN, "text": "There is a way home. Only one."},
		{"who": WARDEN, "text": "The Reach is a ladder of trials. Halls, vaults, the deep places, and the guardians who keep them."},
		{"who": WARDEN, "text": "Complete every one of them, and the door to your world will open."},
		{"who": HERO, "text": "And if I fail?"},
		{"who": WARDEN, "text": "Then you stay. And one day you become an echo yourself, walking the same steps forever."},
		{"who": HERO, "text": "...Great. Any advice?"},
		{"who": WARDEN, "text": "Here, your past is not gone. It lingers. It follows you."},
		{"who": WARDEN, "text": "Learn to walk beside it, and it will carry you further than you could go alone."},
		{"who": HERO, "text": "Wait, who ARE you?"},
		{"who": "The Warden", "text": "Someone who has waited a very long time for someone to finish the climb."},
		{"who": "The Warden", "text": "Now. Open your eyes."},
	])

	# Hold on black after "Open your eyes." The game fades in from here.
	await _wait(1.2)
	_finish()


# ── Beats ────────────────────────────────────────────────────────────────────

func _narrate(text: String, hold: float = -1.0) -> void:
	if _skipping:
		return
	_narration.text = text
	var t := create_tween()
	t.tween_property(_narration, "modulate:a", 1.0, 0.8)
	await t.finished
	if hold < 0.0:
		await _wait_for_advance(1.2 + text.length() * 0.035)
	else:
		await _wait(hold)
	t = create_tween()
	t.tween_property(_narration, "modulate:a", 0.0, 0.6)
	await t.finished


func _headlights() -> void:
	if _skipping:
		return
	# Light swells from the dark, then the hit.
	var t := create_tween()
	t.tween_property(_flash, "color", Color(1.0, 0.95, 0.75, 0.55), 1.6).set_ease(Tween.EASE_IN)
	await t.finished
	_narration.text = "!"
	_narration.add_theme_font_size_override("font_size", 64)
	_narration.modulate.a = 1.0
	_narration.add_theme_color_override("font_color", Color.BLACK)
	_flash.color = Color(1, 1, 1, 1)
	_shake(0.6, 18.0)
	await _wait(0.12)
	_narration.modulate.a = 0.0
	_narration.add_theme_font_size_override("font_size", 30)
	_narration.add_theme_color_override("font_color", Color(0.86, 0.86, 0.9))
	t = create_tween()
	t.tween_property(_flash, "color", Color(1, 1, 1, 0), 0.08)
	await t.finished


func _shake(duration: float, strength: float) -> void:
	var t := create_tween()
	var steps := int(duration / 0.03)
	for i in steps:
		var falloff := 1.0 - float(i) / steps
		var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * falloff
		t.tween_property(_shake_root, "position", off, 0.03)
	t.tween_property(_shake_root, "position", Vector2.ZERO, 0.03)


func _finish() -> void:
	if _done:
		return
	_done = true
	set_process(false)
	StoryDirector.arrival_pending = true
	StoryDirector.cover.color.a = 1.0
	StoryDirector.cover.show()
	get_tree().change_scene_to_file(NEXT_SCENE)


# ── Helpers ──────────────────────────────────────────────────────────────────

func _wait(seconds: float) -> void:
	if _skipping:
		return
	await get_tree().create_timer(seconds).timeout


## Waits until the player presses advance, or `auto` seconds pass.
var _advance_pressed := false

func _wait_for_advance(auto: float) -> void:
	_advance_pressed = false
	var elapsed := 0.0
	while not _advance_pressed and elapsed < auto and not _skipping:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_skipping = true
		_finish()
	elif Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
		_advance_pressed = true
