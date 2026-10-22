#level_select.gd
# CONTINUE's screen: a grid of level tiles (a screenshot with the level's
# name under it), old flash-game style. Reached levels can be started from
# their beginning; the rest are locked. Levels with an echo goal show their
# star. "Resume from last lantern" picks up exactly where the save left off.
extends CanvasLayer

signal closed

const TILE = Vector2(176, 99)  # thumbnail size, 16:9
const COLUMNS = 5

var _first: Control


func _ready() -> void:
	layer = 10
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := MenuStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(MenuStyle.label("SELECT LEVEL", 32))

	var resume := MenuStyle.button("Resume from last lantern")
	resume.custom_minimum_size.x = 320
	resume.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume.pressed.connect(SaveManager.continue_game)
	col.add_child(resume)
	_first = resume

	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	col.add_child(grid)
	var unlocked: Array = SaveManager.load_data().get("levels_unlocked", [])
	for e in LevelList.LEVELS:
		grid.add_child(_tile(e, e["id"] in unlocked))

	var back := MenuStyle.button("Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	col.add_child(back)
	MenuStyle.centre(self, panel)
	_first.grab_focus()


func _tile(e: Dictionary, open: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE + Vector2(12, 40)
	b.disabled = not open
	b.focus_mode = Control.FOCUS_ALL if open else Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.1 if state in ["hover", "focus"] else 0.03)
		style.set_corner_radius_all(6)
		style.set_border_width_all(2 if state in ["hover", "focus", "pressed"] else 1)
		style.border_color = MenuStyle.ACCENT if state != "disabled" else Color(0.3, 0.3, 0.35)
		b.add_theme_stylebox_override(state, style)
	if open:
		b.pressed.connect(SaveManager.start_level.bind(e["id"]))

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 6
	box.offset_top = 6
	box.offset_right = -6
	box.offset_bottom = -4
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)

	var pic := TextureRect.new()
	pic.custom_minimum_size = TILE
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path := LevelList.THUMBS % e["id"]
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	if not open:
		pic.modulate = Color(0.15, 0.15, 0.18)
		var lock := MenuStyle.label("LOCKED", 18, MenuStyle.DIM)
		lock.set_anchors_preset(Control.PRESET_FULL_RECT)
		lock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pic.add_child(lock)
	box.add_child(pic)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(MenuStyle.label(e["label"], 18, MenuStyle.TEXT if open else MenuStyle.DIM))
	if e.has("goal"):
		var star := Star.new()
		star.earned = LevelList.has_star(e["id"])
		row.add_child(star)
	box.add_child(row)
	return b


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## A small five-point star: gold when earned, an outline when not.
class Star extends Control:
	var earned := false

	func _init() -> void:
		custom_minimum_size = Vector2(16, 16)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var pts := PackedVector2Array()
		for i in 10:
			var r := 7.5 if i % 2 == 0 else 3.2
			var a := -PI / 2 + i * PI / 5
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		if earned:
			draw_colored_polygon(pts, MenuStyle.GOLD)
		else:
			pts.append(pts[0])
			draw_polyline(pts, Color(0.5, 0.5, 0.55), 1.0)
