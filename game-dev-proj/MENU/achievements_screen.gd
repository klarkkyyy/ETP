#achievements_screen.gd
# The main menu's trophy button opens this: every achievement in a scrolling
# list, with its trophy in its rarity's colour once unlocked (grey before), its
# name, what it asks and its rarity. Hidden ones (the secrets) show "???" and
# a hint until found. Keyboard: up/down moves through the list, Esc closes.
extends CanvasLayer

signal closed

const ROW_WIDTH := 640.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := MenuStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	head.add_child(TrophyIcon.new(36, MenuStyle.GOLD))
	head.add_child(MenuStyle.label("ACHIEVEMENTS", 32))
	col.add_child(head)
	var count := Achievements.unlocked_count()
	col.add_child(MenuStyle.label("%d / %d unlocked" % [count, Achievements.LIST.size()], 18, MenuStyle.DIM))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(ROW_WIDTH + 24, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	col.add_child(scroll)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	var rows: Array = []
	for a in Achievements.LIST:
		var row := _row(a)
		list.add_child(row)
		rows.append(row)

	var back := MenuStyle.button("Back")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	col.add_child(back)
	# up/down runs through the rows and on to Back
	for i in rows.size():
		var r: Control = rows[i]
		r.focus_neighbor_top = r.get_path_to(rows[i - 1] if i > 0 else back)
		r.focus_neighbor_bottom = r.get_path_to(rows[i + 1] if i < rows.size() - 1 else back)
	back.focus_neighbor_top = back.get_path_to(rows[-1])
	back.focus_neighbor_bottom = back.get_path_to(rows[0])
	MenuStyle.centre(self, panel)
	rows[0].grab_focus()


## One achievement: trophy, name and description, rarity tag.
func _row(a: Dictionary) -> PanelContainer:
	var got := Achievements.is_unlocked(a["id"])
	var secret: bool = a.get("hidden", false) and not got
	var c: Color = Achievements.RARITY_COLORS[a["rarity"]]
	var row := PanelContainer.new()
	row.custom_minimum_size.x = ROW_WIDTH
	row.focus_mode = Control.FOCUS_ALL
	for state in ["panel", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.06 if got else 0.02)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(8)
		if state == "focus":
			style.bg_color = Color(1, 1, 1, 0.1)
			style.set_border_width_all(2)
			style.border_color = MenuStyle.ACCENT
		row.add_theme_stylebox_override(state, style)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(line)
	line.add_child(TrophyIcon.new(36, c if got else Color(0.3, 0.3, 0.36)))
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 0)
	line.add_child(words)
	var title := MenuStyle.label("???" if secret else a["title"], 20, MenuStyle.TEXT if got else MenuStyle.DIM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	words.add_child(title)
	var text := MenuStyle.label(a.get("hint", "") if secret else a["text"], 14, MenuStyle.DIM if got else Color(0.48, 0.48, 0.55))
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(text)
	var tag := MenuStyle.label(Achievements.RARITY_NAMES[a["rarity"]], 14, c if got else c.darkened(0.45))
	tag.custom_minimum_size.x = 96
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(tag)
	return row


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
