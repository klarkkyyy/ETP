#menu_style.gd
# Shared look for the in-game panels (level clear, pause): a dark framed box,
# BoldPixels text and flat buttons that light up when focused, so they work
# with the keyboard as well as the mouse.
class_name MenuStyle

const FONT = preload("res://assets/fonts/BoldPixels.ttf")
const TEXT = Color(0.92, 0.92, 0.96)
const DIM = Color(0.62, 0.62, 0.7)
const GOLD = Color(1.0, 0.85, 0.35)
const ACCENT = Color(0.4, 0.8, 1.0)  # echo slot 1 blue

static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.08, 0.92)
	style.border_color = Color(0.4, 0.8, 1.0, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(24)
	p.add_theme_stylebox_override("panel", style)
	return p

static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.05))
	l.add_theme_constant_override("outline_size", 4)
	return l

static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(200, 40)
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", TEXT)
	b.add_theme_color_override("font_focus_color", TEXT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.0 if state == "normal" else 0.08)
		style.set_corner_radius_all(6)
		style.set_border_width_all(0 if state == "normal" else 2)
		style.border_color = ACCENT
		b.add_theme_stylebox_override(state, style)
	return b

## A full-screen layer that keeps running while the game is paused.
static func overlay(layer: int) -> CanvasLayer:
	var c := CanvasLayer.new()
	c.layer = layer
	c.process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	return c

## Centres `node` on the screen inside `layer`.
static func centre(layer: CanvasLayer, node: Control) -> void:
	var box := CenterContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_child(node)
	layer.add_child(box)

static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]
