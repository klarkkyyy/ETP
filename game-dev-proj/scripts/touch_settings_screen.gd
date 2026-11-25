#touch_settings_screen.gd
# The phone "Controls" screen, opened from the main menu and the pause menu
# (only where TouchControls is on): arrows or stick for moving, button size,
# button opacity, "Edit layout" (drag the buttons around, see
# TouchControls.begin_edit) and a reset. The buttons themselves show behind
# the panel the whole time, so every change can be seen right away.
# Back / Esc / the phone's back button closes it.
class_name TouchSettingsScreen
extends CanvasLayer

signal closed

var _panel: Control
var _dim: ColorRect
var _size_slider: HSlider
var _size_label: Label
var _opacity_slider: HSlider
var _opacity_label: Label
var _arrows: Button
var _stick: Button
var _back: Button


func _ready() -> void:
	layer = 58  # over the pause menu (56), under the previewed buttons (60)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.6)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)

	var panel := MenuStyle.panel()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(MenuStyle.label("CONTROLS", 30))

	# movement style
	col.add_child(MenuStyle.label("Movement", 18, MenuStyle.DIM))
	var styles := HBoxContainer.new()
	styles.alignment = BoxContainer.ALIGNMENT_CENTER
	styles.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	_arrows = _toggle("Arrows", group)
	_stick = _toggle("Stick", group)
	_arrows.pressed.connect(func(): TouchControls.set_move_style(TouchControls.MOVE_ARROWS))
	_stick.pressed.connect(func(): TouchControls.set_move_style(TouchControls.MOVE_STICK))
	styles.add_child(_arrows)
	styles.add_child(_stick)
	col.add_child(styles)

	# size and opacity
	var size_row := _slider_row("Button size", TouchControls.SIZE_RANGE)
	_size_slider = size_row[0]
	_size_label = size_row[1]
	col.add_child(size_row[2])
	var opacity_row := _slider_row("Opacity", TouchControls.OPACITY_RANGE)
	_opacity_slider = opacity_row[0]
	_opacity_label = opacity_row[1]
	col.add_child(opacity_row[2])
	_size_slider.value_changed.connect(func(v):
		TouchControls.set_button_size(v / 100.0)
		_size_label.text = "%d%%" % v)
	_opacity_slider.value_changed.connect(func(v):
		TouchControls.set_opacity(v / 100.0)
		_opacity_label.text = "%d%%" % v)

	var edit := MenuStyle.button("Edit layout")
	edit.pressed.connect(_edit_layout)
	col.add_child(edit)
	var reset := MenuStyle.button("Reset to default")
	reset.pressed.connect(func():
		TouchControls.reset_layout()
		_refresh())
	col.add_child(reset)
	_back = MenuStyle.button("Back")
	_back.pressed.connect(close)
	col.add_child(_back)

	_panel = CenterContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(panel)
	add_child(_panel)
	_refresh()
	TouchControls.set_preview(true)
	_back.grab_focus()


func _toggle(text: String, group: ButtonGroup) -> Button:
	var b := MenuStyle.button(text)
	b.custom_minimum_size = Vector2(130, 40)
	b.toggle_mode = true
	b.button_group = group
	# the chosen one stays lit
	b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("focus").duplicate())
	b.add_theme_color_override("font_pressed_color", MenuStyle.ACCENT)
	return b


## [slider, value label, row]
func _slider_row(title: String, range_: Vector2) -> Array:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var name_label := MenuStyle.label(title, 18)
	name_label.custom_minimum_size = Vector2(130, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)
	var slider := HSlider.new()
	slider.min_value = range_.x * 100
	slider.max_value = range_.y * 100
	slider.step = 5
	slider.custom_minimum_size = Vector2(260, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# a thick track and a big grabber, for thumbs
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1, 1, 1, 0.15)
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate()
	fill.bg_color = Color(MenuStyle.ACCENT, 0.7)
	slider.add_theme_stylebox_override("slider", track)
	slider.add_theme_stylebox_override("grabber_area", fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	var knob := _knob_texture()
	slider.add_theme_icon_override("grabber", knob)
	slider.add_theme_icon_override("grabber_highlight", knob)
	row.add_child(slider)
	var value_label := MenuStyle.label("", 18, MenuStyle.ACCENT)
	value_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(value_label)
	return [slider, value_label, row]


func _knob_texture() -> Texture2D:
	var img := Image.create(28, 28, false, Image.FORMAT_RGBA8)
	for y in 28:
		for x in 28:
			var d := Vector2(x - 13.5, y - 13.5).length()
			if d <= 13.0:
				img.set_pixel(x, y, Color(0.92, 0.92, 0.96) if d <= 10.5 else MenuStyle.ACCENT)
	return ImageTexture.create_from_image(img)


func _refresh() -> void:
	_size_slider.set_value_no_signal(roundf(TouchControls.button_size * 100))
	_size_label.text = "%d%%" % _size_slider.value
	_opacity_slider.set_value_no_signal(roundf(TouchControls.opacity * 100))
	_opacity_label.text = "%d%%" % _opacity_slider.value
	(_stick if TouchControls.move_style == TouchControls.MOVE_STICK else _arrows).button_pressed = true


func _edit_layout() -> void:
	_panel.hide()
	_dim.hide()
	TouchControls.begin_edit(func():
		_panel.show()
		_dim.show()
		_back.grab_focus())


func close() -> void:
	if TouchControls.is_editing():
		TouchControls.end_edit()
	TouchControls.set_preview(false)
	closed.emit()
	queue_free()


## Also when freed along with the pause menu.
func _exit_tree() -> void:
	if TouchControls.is_editing():
		TouchControls.end_edit()
	TouchControls.set_preview(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if TouchControls.is_editing():
			TouchControls.end_edit()
		else:
			close()
		get_viewport().set_input_as_handled()
