# touch_controls.gd (autoload "TouchControls")
# On-screen controls for phones. Bottom left: left / right arrows (slide a
# thumb between them). Bottom right: jump, with an Interact button beside it
# that only shows while Ren stands at a lever or teleport, and "reset all
# echoes" (R) above. Top right: pause (Esc); the phone's back button does the
# same. The echo icons top left (echoes.gd's HUD) are tapped directly: tap to
# record, tap again to finish, tap while its echo is out to wipe it.
# Every button is its own TouchScreenButton, so several thumbs work at once
# (hold right + tap jump).
# The buttons hide whenever the player can't move: dialogue, cutscenes,
# pause and level-clear screens, menus. While a dialogue box or the opening
# story shows, a tap anywhere advances it (as Enter does).
# Shows on phones / touchscreens. To try it on PC: run with `-- --touch`, or
# turn on Project Settings > Input Devices > Pointing > Emulate Touch From
# Mouse (the mouse then acts as one finger).
extends CanvasLayer

const FONT = preload("res://assets/fonts/BoldPixels.ttf")
const INTRO = "res://story/story_intro.tscn"
## Groups whose nodes set `_player_nearby` and react to "interact".
const INTERACT_GROUPS = ["lever", "teleport", "teleport_scene"]

var enabled: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() \
		or OS.get_cmdline_user_args().has("--touch") \
		or ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)

var _root: Node2D
var _left: TouchScreenButton
var _right: TouchScreenButton
var _jump: TouchScreenButton
var _interact: TouchScreenButton
var _reset: TouchScreenButton
var _pause: TouchScreenButton


func _ready() -> void:
	layer = 35  # over the echo HUD (30), under boss HUD (40), dialogue (50), pause (56)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false  # the back button pauses instead
	if not enabled:
		return
	_root = Node2D.new()
	add_child(_root)
	_left = _make_button("left", 56, ButtonFace.Glyph.LEFT, Vector2(160, 230))
	_right = _make_button("right", 56, ButtonFace.Glyph.RIGHT, Vector2(150, 230))
	_left.passby_press = true
	_right.passby_press = true
	_jump = _make_button("jump", 62, ButtonFace.Glyph.JUMP)
	_interact = _make_button("interact", 48, ButtonFace.Glyph.TEXT, Vector2.ZERO, "Interact")
	_reset = _make_button("clear_echoes", 32, ButtonFace.Glyph.RESET)
	_pause = _make_button("pause", 26, ButtonFace.Glyph.PAUSE)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_root.visible = false


func _make_button(action: String, radius: float, glyph: int, hit_rect := Vector2.ZERO, text := "") -> TouchScreenButton:
	var b := TouchScreenButton.new()
	b.action = action
	b.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
	if hit_rect == Vector2.ZERO:
		var circle := CircleShape2D.new()
		circle.radius = radius * 1.25  # a bit bigger than it looks: thumbs miss
		b.shape = circle
	else:
		var rect := RectangleShape2D.new()
		rect.size = hit_rect
		b.shape = rect
	b.shape_centered = true
	b.shape_visible = false
	var face := ButtonFace.new()
	face.radius = radius
	face.glyph = glyph
	face.text = text
	b.add_child(face)
	_root.add_child(b)
	return b


func _layout() -> void:
	var s := get_viewport().get_visible_rect().size
	_left.position = Vector2(92, s.y - 96)
	_right.position = Vector2(244, s.y - 96)
	_jump.position = Vector2(s.x - 96, s.y - 100)
	_interact.position = Vector2(s.x - 250, s.y - 78)
	_reset.position = Vector2(s.x - 80, s.y - 250)
	_pause.position = Vector2(s.x - 42, 42)


func _process(_delta: float) -> void:
	if not enabled:
		return
	var show := _can_play()
	if _root.visible != show:
		_root.visible = show
		if not show:
			for action in ["left", "right", "jump", "interact"]:
				Input.action_release(action)
	if show:
		_interact.visible = _near_interactable()


## Same idea as PauseMenu._can_open: Ren is in the game and can move.
func _can_play() -> bool:
	var tree := get_tree()
	var scene := tree.current_scene
	if scene == null or scene.name != "game" or tree.paused or LevelClear.is_open():
		return false
	var player := tree.get_first_node_in_group("player")
	if player == null or player.get("controls_locked"):
		return false
	return not _dialogue_showing()


func _dialogue_showing() -> bool:
	for box in get_tree().get_nodes_in_group("dialogue_box"):
		if box.is_showing():
			return true
	return false


func _near_interactable() -> bool:
	for group in INTERACT_GROUPS:
		for node in get_tree().get_nodes_in_group(group):
			if node.get("_player_nearby") and node.is_inside_tree():
				return true
	return false


func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventScreenTouch and event.pressed):
		return
	if _root.visible:
		var rects: Dictionary = Echoes.icon_rects()
		for slot in rects:
			if rects[slot].has_point(event.position):
				Echoes.tap_slot(slot)
				get_viewport().set_input_as_handled()
				return
	elif _dialogue_showing() or _in_intro():
		_tap_action("ui_accept")


func _in_intro() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path == INTRO


## Phone back button: pause / unpause in the game (skip in the opening
## story), "back" (ui_cancel) in the menus.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var scene := get_tree().current_scene
		var in_game := scene != null and (scene.name == "game" or _in_intro())
		_tap_action("pause" if in_game else "ui_cancel")


## Press and release an input action, as if its key was tapped.
func _tap_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(0.05, true).timeout
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)


## Draws one button: a dark disc, a light ring, and its symbol.
class ButtonFace extends Node2D:
	enum Glyph { LEFT, RIGHT, JUMP, RESET, PAUSE, TEXT }
	var radius := 50.0
	var glyph := Glyph.TEXT
	var text := ""
	var _was_pressed := false

	func _process(_delta: float) -> void:
		var pressed: bool = get_parent().is_pressed()
		if pressed != _was_pressed:
			_was_pressed = pressed
			queue_redraw()

	func _draw() -> void:
		var fill := Color(1, 1, 1, 0.28) if _was_pressed else Color(0.04, 0.04, 0.08, 0.38)
		var ink := Color(1, 1, 1, 0.85 if _was_pressed else 0.6)
		draw_circle(Vector2.ZERO, radius, fill)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, ink, 2.5, true)
		var r := radius * 0.38
		match glyph:
			Glyph.LEFT:
				draw_colored_polygon(PackedVector2Array([Vector2(-r, 0), Vector2(r * 0.7, -r), Vector2(r * 0.7, r)]), ink)
			Glyph.RIGHT:
				draw_colored_polygon(PackedVector2Array([Vector2(r, 0), Vector2(-r * 0.7, -r), Vector2(-r * 0.7, r)]), ink)
			Glyph.JUMP:
				draw_colored_polygon(PackedVector2Array([Vector2(0, -r), Vector2(r, r * 0.6), Vector2(-r, r * 0.6)]), ink)
			Glyph.RESET:
				# circular arrow + "ALL"
				draw_arc(Vector2(0, -4), r, deg_to_rad(-60), deg_to_rad(230), 24, ink, 3.0, true)
				var tip := Vector2(0, -4) + Vector2.from_angle(deg_to_rad(-60)) * r
				draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -5), tip + Vector2(6, -3), tip + Vector2(0, 8)]), ink)
				draw_string(FONT, Vector2(-radius, radius * 0.75), "ALL", HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 11, ink)
			Glyph.PAUSE:
				draw_rect(Rect2(-r * 0.8, -r, r * 0.55, r * 2), ink)
				draw_rect(Rect2(r * 0.25, -r, r * 0.55, r * 2), ink)
			Glyph.TEXT:
				draw_string(FONT, Vector2(-radius, 6), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2, 16, ink)
