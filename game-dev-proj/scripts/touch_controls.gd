# touch_controls.gd (autoload "TouchControls")
# On-screen controls for phones. Movement is either two arrows (slide a thumb
# between them) or a floating stick (left / right only), the player's choice.
# Jump, with an Interact button that only shows while Ren stands at a lever
# or teleport, "reset all echoes" (R), and pause (Esc); the phone's back
# button pauses too. The echo icons top left (echoes.gd's HUD) are tapped
# directly: tap to record, tap again to finish, tap while its echo is out to
# wipe it.
# Every button / the stick follows its own finger, so several thumbs work at
# once (hold right + tap jump).
# The buttons hide whenever the player can't move: dialogue, cutscenes,
# pause and level-clear screens, menus. While a dialogue box or the opening
# story shows, a tap anywhere advances it (as Enter does).
# Player settings (size, opacity, arrows / stick, where each button sits) are
# kept in user://touch_controls.cfg; touch_settings_screen.gd edits them, and
# begin_edit() lets the player drag the buttons around.
# Shows on phones / touchscreens. To try it on PC: run with `-- --touch`, or
# turn on Project Settings > Input Devices > Pointing > Emulate Touch From
# Mouse (the mouse then acts as one finger).
extends CanvasLayer

const FONT = preload("res://assets/fonts/BoldPixels.ttf")
const INTRO = "res://story/story_intro.tscn"
const SETTINGS_PATH = "user://touch_controls.cfg"
## Groups whose nodes set `_player_nearby` and react to "interact".
const INTERACT_GROUPS = ["lever", "teleport", "teleport_scene"]
const LAYER_PLAY = 35     # over the echo HUD (30), under boss HUD (40), dialogue (50), pause (56)
const LAYER_PREVIEW = 60  # over the pause menu and the settings screen (58)
const SIZE_RANGE = Vector2(0.6, 1.6)
const OPACITY_RANGE = Vector2(0.2, 1.0)
const MOVE_ARROWS = "arrows"
const MOVE_STICK = "stick"

var enabled: bool = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() \
		or OS.get_cmdline_user_args().has("--touch") \
		or ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse", false)

# ── player settings ──
var button_size := 1.0
var opacity := 0.85
var move_style := MOVE_ARROWS
var _positions := {}  # control name -> Vector2 as a fraction of the screen; missing = default

var _root: Node2D
var _controls := {}  # name -> Node2D (TouchScreenButton, or the MoveStick)
var _actions := {}   # TouchScreenButton name -> its action, so preview can mute them
var _preview := false
var _editing := false
var _edit_layer: CanvasLayer
var _edit_bar: Control
var _on_edit_done: Callable
var _drag_index := -1
var _drag_name := ""
var _drag_offset := Vector2.ZERO


func _ready() -> void:
	layer = LAYER_PLAY
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().quit_on_go_back = false  # the back button pauses instead
	if not enabled:
		return
	get_tree().node_added.connect(TouchHints.adapt)   # key hints -> touch wording
	_load_settings()
	_root = Node2D.new()
	add_child(_root)
	var left := _make_button("left", 56, ButtonFace.Glyph.LEFT, Vector2(150, 200))
	var right := _make_button("right", 56, ButtonFace.Glyph.RIGHT, Vector2(150, 200))
	left.passby_press = true
	right.passby_press = true
	_make_button("jump", 62, ButtonFace.Glyph.JUMP)
	_make_button("interact", 48, ButtonFace.Glyph.TEXT, Vector2.ZERO, "Interact")
	_make_button("clear_echoes", 32, ButtonFace.Glyph.RESET)
	_make_button("pause", 26, ButtonFace.Glyph.PAUSE)
	var stick := MoveStick.new()
	_root.add_child(stick)
	_controls["stick"] = stick
	get_viewport().size_changed.connect(_apply)
	_apply()
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
	_controls[action] = b
	_actions[action] = action
	return b


# ── layout ────────────────────────────────────────────────────────────────────
## Where each control sits before the player moves it, for a screen of size s.
func _default_position(control: String, s: Vector2) -> Vector2:
	match control:
		"left": return Vector2(92, s.y - 96)
		"right": return Vector2(244, s.y - 96)
		"stick": return Vector2(160, s.y - 120)
		"jump": return Vector2(s.x - 96, s.y - 100)
		"interact": return Vector2(s.x - 250, s.y - 78)
		"clear_echoes": return Vector2(s.x - 80, s.y - 250)
		"pause": return Vector2(s.x - 42, 42)
	return s / 2

func _screen() -> Vector2:
	return get_viewport().get_visible_rect().size

## Puts every control in place at the current size / opacity / style.
func _apply() -> void:
	if _root == null:
		return
	var s := _screen()
	for control in _controls:
		var node: Node2D = _controls[control]
		node.position = _positions[control] * s if _positions.has(control) else _default_position(control, s)
		node.scale = Vector2.ONE * button_size
		var margin := _reach(control) / 1.2 + 4.0  # keep big buttons fully on screen
		node.position = node.position.clamp(Vector2(margin, margin), s - Vector2(margin, margin))
	_root.modulate.a = opacity
	var stick := move_style == MOVE_STICK
	_controls["left"].visible = not stick
	_controls["right"].visible = not stick
	_controls["stick"].visible = stick
	if stick:
		Input.action_release("left")
		Input.action_release("right")


# ── settings ──────────────────────────────────────────────────────────────────
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	button_size = clampf(cfg.get_value("touch", "size", button_size), SIZE_RANGE.x, SIZE_RANGE.y)
	opacity = clampf(cfg.get_value("touch", "opacity", opacity), OPACITY_RANGE.x, OPACITY_RANGE.y)
	move_style = MOVE_STICK if cfg.get_value("touch", "move_style", move_style) == MOVE_STICK else MOVE_ARROWS
	var saved = cfg.get_value("touch", "positions", {})
	if saved is Dictionary:
		for control in saved:
			if saved[control] is Vector2:
				_positions[control] = saved[control]

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("touch", "size", button_size)
	cfg.set_value("touch", "opacity", opacity)
	cfg.set_value("touch", "move_style", move_style)
	cfg.set_value("touch", "positions", _positions)
	cfg.save(SETTINGS_PATH)

func set_button_size(value: float) -> void:
	button_size = clampf(value, SIZE_RANGE.x, SIZE_RANGE.y)
	_apply()
	_save_settings()

func set_opacity(value: float) -> void:
	opacity = clampf(value, OPACITY_RANGE.x, OPACITY_RANGE.y)
	_apply()
	_save_settings()

func set_move_style(style: String) -> void:
	move_style = style
	_apply()
	_save_settings()

## Back to the default layout, size and opacity (keeps arrows / stick).
func reset_layout() -> void:
	_positions.clear()
	button_size = 1.0
	opacity = 0.85
	_apply()
	_save_settings()


# ── preview and layout editing ────────────────────────────────────────────────
## The settings screen shows every control, inert, over everything, so size
## and opacity changes can be seen as they happen.
func set_preview(on: bool) -> void:
	if not enabled:
		return
	_preview = on
	layer = LAYER_PREVIEW if on else LAYER_PLAY
	for control in _actions:
		(_controls[control] as TouchScreenButton).action = "" if on else _actions[control]
	_controls["stick"].set("inert", on)
	if on:
		_controls["interact"].visible = true
	_root.visible = on or _can_play()

## Drag mode: the player moves the controls with a finger; Done or the back
## button ends it and `on_done` is called.
func begin_edit(on_done: Callable) -> void:
	_on_edit_done = on_done
	_editing = true
	set_preview(true)
	_edit_layer = CanvasLayer.new()
	_edit_layer.layer = LAYER_PREVIEW - 1
	_edit_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_edit_layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edit_layer.add_child(dim)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(MenuStyle.label("Drag the buttons where you want them", 20))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var reset := MenuStyle.button("Reset positions")
	reset.pressed.connect(func():
		_positions.clear()
		_apply()
		_save_settings())
	var done := MenuStyle.button("Done")
	done.pressed.connect(end_edit)
	row.add_child(reset)
	row.add_child(done)
	col.add_child(row)
	_edit_bar = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.85)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	_edit_bar.add_theme_stylebox_override("panel", style)
	_edit_bar.add_child(col)
	_edit_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_edit_bar.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var top := MarginContainer.new()
	top.set_anchors_preset(Control.PRESET_FULL_RECT)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_theme_constant_override("margin_top", 140)
	top.add_child(_edit_bar)
	_edit_layer.add_child(top)

func end_edit() -> void:
	if not _editing:
		return
	_editing = false
	_drag_index = -1
	if is_instance_valid(_edit_layer):
		_edit_layer.queue_free()
	_save_settings()
	if _on_edit_done.is_valid():
		_on_edit_done.call()

func is_editing() -> bool:
	return _editing

func _edit_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _drag_index == -1:
			if _edit_bar.get_global_rect().has_point(event.position):
				return  # Done / Reset
			var picked := _control_at(event.position)
			if picked != "":
				_drag_index = event.index
				_drag_name = picked
				_drag_offset = _controls[picked].position - event.position
				get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _drag_index:
			_drag_index = -1
			_save_settings()
	elif event is InputEventScreenDrag and event.index == _drag_index:
		var node: Node2D = _controls[_drag_name]
		var s := _screen()
		var margin := _reach(_drag_name) * 0.6
		node.position = (event.position + _drag_offset).clamp(Vector2(margin, margin), s - Vector2(margin, margin))
		_positions[_drag_name] = node.position / s
		get_viewport().set_input_as_handled()

## The visible control under `point` (closest centre wins), or "".
func _control_at(point: Vector2) -> String:
	var best := ""
	var best_dist := INF
	for control in _controls:
		var node: Node2D = _controls[control]
		if not node.visible:
			continue
		var d := node.position.distance_to(point)
		if d <= _reach(control) and d < best_dist:
			best = control
			best_dist = d
	return best

func _reach(control: String) -> float:
	var node = _controls[control]
	var r: float = node.radius if control == "stick" else node.get_child(0).radius
	return r * button_size * 1.2


# ── every frame ───────────────────────────────────────────────────────────────
func _process(_delta: float) -> void:
	if not enabled or _preview:
		return
	var show := _can_play()
	if _root.visible != show:
		_root.visible = show
		if not show:
			for action in ["left", "right", "jump", "interact"]:
				Input.action_release(action)
	if show:
		_controls["interact"].visible = _near_interactable()


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
	if not enabled:
		return
	if _editing:
		_edit_input(event)
		return
	if _preview or not (event is InputEventScreenTouch and event.pressed):
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


## Phone back button: ends layout editing; otherwise pause / unpause in the
## game (skip in the opening story), "back" (ui_cancel) in the menus.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _editing:
			end_edit()
			return
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


## Floating left / right stick: a thumb landing near it re-centres it under
## the thumb, then sliding past a small dead zone holds left or right at full
## strength (like the arrows; no half-speed walking). Up / down is ignored.
## Sliding far keeps dragging the centre along, so turning around is quick.
class MoveStick extends Node2D:
	var radius := 64.0
	var inert := false
	var _index := -1
	var _centre := Vector2.ZERO  # in the parent's space while held
	var _knob_x := 0.0
	var _dir := 0

	func _input(event: InputEvent) -> void:
		if inert or not is_visible_in_tree():
			if _index != -1:
				_let_go()
			return
		var r := radius * scale.x
		if event is InputEventScreenTouch:
			if event.pressed and _index == -1 and event.position.distance_to(position) <= r * 1.6:
				_index = event.index
				_centre = event.position
				_set_knob(0.0)
				get_viewport().set_input_as_handled()
			elif not event.pressed and event.index == _index:
				_let_go()
		elif event is InputEventScreenDrag and event.index == _index:
			var dx: float = event.position.x - _centre.x
			if absf(dx) > r:  # drag the centre along
				_centre.x = event.position.x - signf(dx) * r
				dx = signf(dx) * r
			_set_knob(dx / r)
			get_viewport().set_input_as_handled()

	func _set_knob(t: float) -> void:
		_knob_x = t
		var dir := 0
		if t > 0.25:
			dir = 1
		elif t < -0.25:
			dir = -1
		if dir != _dir:
			_dir = dir
			if dir == 1: Input.action_press("right")
			else: Input.action_release("right")
			if dir == -1: Input.action_press("left")
			else: Input.action_release("left")
		queue_redraw()

	func _let_go() -> void:
		_index = -1
		_set_knob(0.0)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_VISIBILITY_CHANGED and _index != -1 and not is_visible_in_tree():
			_let_go()

	func _draw() -> void:
		# drawn at the held centre while a thumb is on it, else at home
		var at := Vector2.ZERO
		if _index != -1:
			at = (_centre - position) / scale.x
		var held := _index != -1
		var ink := Color(1, 1, 1, 0.85 if held else 0.6)
		draw_circle(at, radius, Color(0.04, 0.04, 0.08, 0.38))
		draw_arc(at, radius, 0, TAU, 48, ink, 2.5, true)
		# a left / right track with arrow tips, so it reads as sideways only
		var tip := radius * 0.78
		draw_line(at + Vector2(-tip + 10, 0), at + Vector2(tip - 10, 0), Color(1, 1, 1, 0.25), 3.0)
		draw_colored_polygon(PackedVector2Array([at + Vector2(-tip, 0), at + Vector2(-tip + 12, -9), at + Vector2(-tip + 12, 9)]), ink)
		draw_colored_polygon(PackedVector2Array([at + Vector2(tip, 0), at + Vector2(tip - 12, -9), at + Vector2(tip - 12, 9)]), ink)
		var knob := at + Vector2(_knob_x * radius, 0)
		draw_circle(knob, radius * 0.42, Color(1, 1, 1, 0.35 if held else 0.22))
		draw_arc(knob, radius * 0.42, 0, TAU, 32, ink, 2.0, true)


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
