# dialogue_box.gd
# Celeste-style dialogue box: speaker name tab, typewriter text, voice blips,
# blinking "continue" arrow. Reusable in cutscenes and in levels.
#
#   var box := DialogueBox.new()
#   add_child(box)
#   await box.say("???", "Open your eyes.")
#   await box.run([{"who": "Ren", "text": "Hello?"}, ...])
class_name DialogueBox
extends CanvasLayer

signal line_finished

const FONT := preload("res://assets/fonts/BoldPixels.ttf")
const CHARS_PER_SEC := 45.0
const ADVANCE_ACTIONS := ["jump", "interact", "ui_accept"]

# Per-speaker look: name colour + blip pitch. Unknown speakers use "default".
var speakers := {
	"default": {"color": Color(0.85, 0.85, 0.85), "pitch": 1.0},
}

## Draw the box at the top of the screen instead of the bottom.
var at_top := false:
	set(v):
		at_top = v
		if is_node_ready():
			_place()

var _panel: PanelContainer
var _name_tab: PanelContainer
var _name_label: Label
var _text: Label
var _arrow: Label
var _typing := false
var _waiting := false
var _char_time := 0.0
var _blip: AudioStreamPlayer
var _blip_pitch := 1.0
var _blip_counter := 0
var _pause := 0.0


func _init() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_build_ui()
	_place()
	_build_blip()
	hide_box()


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_panel.anchor_left = 0.08
	_panel.anchor_right = 0.92
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -190
	_panel.offset_bottom = -32
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.92)
	style.border_color = Color(0.78, 0.74, 0.62)
	style.set_border_width_all(3)
	style.set_corner_radius_all(4)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 26
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_panel)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_text.add_theme_font_override("font", FONT)
	_text.add_theme_font_size_override("font_size", 28)
	_text.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_panel.add_child(_text)

	_name_tab = PanelContainer.new()
	_name_tab.anchor_left = 0.08
	_name_tab.anchor_top = 1.0
	_name_tab.anchor_bottom = 1.0
	_name_tab.offset_left = 24
	_name_tab.offset_top = -212
	_name_tab.offset_bottom = -174
	var tab_style := style.duplicate() as StyleBoxFlat
	tab_style.bg_color = Color(0.1, 0.09, 0.16, 1.0)
	tab_style.content_margin_top = 4
	tab_style.content_margin_bottom = 4
	tab_style.content_margin_left = 16
	tab_style.content_margin_right = 16
	_name_tab.add_theme_stylebox_override("panel", tab_style)
	root.add_child(_name_tab)

	_name_label = Label.new()
	_name_label.add_theme_font_override("font", FONT)
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_tab.add_child(_name_label)

	_arrow = Label.new()
	_arrow.text = "v"
	_arrow.anchor_left = 0.92
	_arrow.anchor_right = 0.92
	_arrow.anchor_top = 1.0
	_arrow.anchor_bottom = 1.0
	_arrow.offset_left = -52
	_arrow.offset_top = -66
	_arrow.add_theme_font_override("font", FONT)
	_arrow.add_theme_font_size_override("font_size", 28)
	_arrow.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62))
	root.add_child(_arrow)


func _place() -> void:
	# Box spans 158 px; the name tab sits on its top edge, the arrow in its
	# bottom-right corner. Anchored to the bottom or the top of the screen.
	var edge := 0.0 if at_top else 1.0
	var box_top := 92.0 if at_top else -190.0
	for c in [_panel, _name_tab, _arrow]:
		c.anchor_top = edge
		c.anchor_bottom = edge
	_panel.offset_top = box_top
	_panel.offset_bottom = box_top + 158
	_name_tab.offset_top = box_top - 22
	_name_tab.offset_bottom = box_top + 16
	_arrow.offset_top = box_top + 124


func _build_blip() -> void:
	# Short square-wave "voice" blip, generated once.
	var rate := 22050
	var samples := int(rate * 0.035)
	var data := PackedByteArray()
	data.resize(samples)
	for i in samples:
		var env := 1.0 - float(i) / samples
		var v := 1.0 if (i / 18) % 2 == 0 else -1.0
		data[i] = int(clamp(v * env * 40.0, -127, 127)) & 0xFF
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = rate
	wav.data = data
	_blip = AudioStreamPlayer.new()
	_blip.stream = wav
	_blip.volume_db = -14.0
	add_child(_blip)


func show_box() -> void:
	_panel.show()


func hide_box() -> void:
	_panel.hide()
	_name_tab.hide()
	_arrow.hide()


## Shows one line and waits until the player advances past it.
func say(who: String, text: String) -> void:
	var look: Dictionary = speakers.get(who, speakers["default"])
	_name_tab.visible = who != ""
	_name_label.text = who
	_name_label.add_theme_color_override("font_color", look["color"])
	_blip_pitch = look["pitch"]
	_text.text = text
	_text.visible_characters = 0
	_char_time = 0.0
	_blip_counter = 0
	_pause = 0.0
	_arrow.hide()
	show_box()
	_typing = true
	_waiting = false
	await line_finished


## Runs a list of {"who": ..., "text": ...} lines, then hides the box.
func run(lines: Array) -> void:
	for line in lines:
		await say(line.get("who", ""), line["text"])
	hide_box()


func _process(delta: float) -> void:
	if (_typing or _waiting) and _advance_pressed():
		if _typing:
			_finish_typing()
			return
		_waiting = false
		_arrow.hide()
		line_finished.emit()
		return
	if _typing:
		if _pause > 0.0:
			_pause -= delta
			return
		_char_time += delta * CHARS_PER_SEC
		var total := _text.get_total_character_count()
		while _char_time >= 1.0 and _text.visible_characters < total:
			_char_time -= 1.0
			_text.visible_characters += 1
			var c := _text.text[_text.visible_characters - 1]
			_blip_counter += 1
			if c != " " and _blip_counter % 3 == 1:
				_blip.pitch_scale = _blip_pitch * randf_range(0.92, 1.08)
				_blip.play()
			# Brief pause after punctuation, like Celeste.
			if c in [".", "!", "?"]:
				_pause = 0.22
				break
			if c == ",":
				_pause = 0.1
				break
		if _text.visible_characters >= total:
			_finish_typing()
	elif _waiting:
		_arrow.visible = fmod(Time.get_ticks_msec() / 400.0, 2.0) < 1.3


func _finish_typing() -> void:
	_text.visible_characters = -1
	_typing = false
	_waiting = true


func _advance_pressed() -> bool:
	for action in ADVANCE_ACTIONS:
		if Input.is_action_just_pressed(action):
			return true
	return false
