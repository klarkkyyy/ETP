#level_select.gd
# CONTINUE's screen: a grid of level tiles (a screenshot with the level's
# name under it), old flash-game style. Reached levels can be started from
# their beginning; the rest are locked. Levels with an echo goal show their
# star, and cleared levels their fastest time and fewest deaths. "Resume from last lantern" picks up exactly where the save left off.
# The tiles come in pages of two rows; Prev/Next turn them.
extends CanvasLayer

signal closed

const TILE = Vector2(176, 99)  # thumbnail size, 16:9
const COLUMNS = 4
const ROWS = 2
const PER_PAGE = COLUMNS * ROWS

var _first: Control
var _grid: GridContainer
var _page := 0
var _page_label: Label
var _prev: Button
var _next: Button
var _data: Dictionary
var _unlocked: Array


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

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 10)
	col.add_child(_grid)
	_data = SaveManager.load_data()
	_unlocked = _data.get("levels_unlocked", [])

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 16)
	_prev = MenuStyle.button("< Prev")
	_prev.pressed.connect(_turn.bind(-1))
	_next = MenuStyle.button("Next >")
	_next.pressed.connect(_turn.bind(1))
	_page_label = MenuStyle.label("", 18, MenuStyle.DIM)
	nav.add_child(_prev)
	nav.add_child(_page_label)
	nav.add_child(_next)
	nav.visible = _page_count() > 1
	col.add_child(nav)
	# open on the page with the furthest level reached
	for i in LevelList.LEVELS.size():
		if LevelList.LEVELS[i]["id"] in _unlocked:
			_page = i / PER_PAGE
	_show_page()

	var back := MenuStyle.button("Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	col.add_child(back)
	MenuStyle.centre(self, panel)
	_first.grab_focus()


func _page_count() -> int:
	return ceili(LevelList.LEVELS.size() / float(PER_PAGE))

func _turn(step: int) -> void:
	_page = clampi(_page + step, 0, _page_count() - 1)
	_show_page()
	# keep focus on the button that was pressed, or the other one at the last page
	var b := _next if step > 0 else _prev
	if b.disabled:
		b = _prev if step > 0 else _next
	b.grab_focus()

func _show_page() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var levels: Array = LevelList.LEVELS.slice(_page * PER_PAGE, (_page + 1) * PER_PAGE)
	for e in levels:
		_grid.add_child(_tile(e, e["id"] in _unlocked, _data))
	# empty slots keep a short last page the same size, so the buttons don't move
	for i in PER_PAGE - levels.size():
		var gap := Control.new()
		gap.custom_minimum_size = TILE + Vector2(12, 60)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_child(gap)
	_page_label.text = "Page %d / %d" % [_page + 1, _page_count()]
	_prev.disabled = _page == 0
	_next.disabled = _page >= _page_count() - 1


## `data` is the save: the star and records come from it (the menu has no game loaded).
func _tile(e: Dictionary, open: bool, data: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE + Vector2(12, 60)
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
	var run := LevelList.run_name(e["id"])
	if e.has("goal"):
		var star := Star.new()
		star.earned = data.get("level_stars", {}).get(run, false)
		row.add_child(star)
	box.add_child(row)
	# the level's records: fastest clear and fewest deaths
	var times: Dictionary = data.get("level_time", {})
	var record := "-"
	if times.has(run):
		record = "%s   %d deaths" % [MenuStyle.format_time(times[run]),
			int(data.get("level_deaths", {}).get(run, 0))]
	box.add_child(MenuStyle.label(record, 14, MenuStyle.DIM))
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
