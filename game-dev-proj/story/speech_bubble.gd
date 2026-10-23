#speech_bubble.gd
# A line of speech over someone's head that doesn't stop the game: typed out,
# held long enough to read, then faded. It follows the speaker.
#   var b := preload("res://story/speech_bubble.gd").new()
#   world.add_child(b)
#   await b.say(guide_ghost, "Can't you?", Color.CYAN)
extends Node2D

const FONT := preload("res://assets/fonts/BoldPixels.ttf")
const CHARS_PER_SEC := 40.0
const READ_TIME := 1.3          # seconds held after typing, plus per character below
const READ_PER_CHAR := 0.04
const WIDTH := 280.0            # px of text before scaling (the bubble is drawn at half size)
const FONT_SIZE := 16
const MARGIN := Vector2(10, 5)
const HEAD := Vector2(0, -20)   # above the speaker's origin

## Ends the line early (Ren walked off, the scene is going).
var cut := false

var _label: Label
var _target: Node2D

func _init() -> void:
	z_index = 60
	scale = Vector2(0.5, 0.5)   # crisp pixel font at world scale
	_label = Label.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.09, 0.88)
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = MARGIN.x
	style.content_margin_right = MARGIN.x
	style.content_margin_top = MARGIN.y
	style.content_margin_bottom = MARGIN.y
	_label.add_theme_stylebox_override("normal", style)
	_label.add_theme_font_override("font", FONT)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.96))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED   # readable in the dark
	_label.material = unshaded
	modulate.a = 0.0

func _process(_delta: float) -> void:
	if is_instance_valid(_target):
		global_position = _target.global_position + HEAD

## Shows `text` over `who` in their colour until it's been read (or cut).
func say(who: Node2D, text: String, color: Color) -> void:
	_target = who
	(_label.get_theme_stylebox("normal") as StyleBoxFlat).border_color = color
	_label.text = text
	# narrow lines stay narrow; long ones wrap at WIDTH
	var natural := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	var w := minf(natural + 4.0, WIDTH) + MARGIN.x * 2.0
	_label.size = Vector2(w, 0.0)
	var h := _label.get_line_count() * _label.get_line_height() + MARGIN.y * 2.0
	_label.size = Vector2(w, h)
	_label.position = Vector2(-w * 0.5, -h)
	_label.visible_ratio = 0.0
	_process(0.0)
	var t := create_tween()
	t.tween_property(self, "modulate:a", 1.0, 0.15)
	t.parallel().tween_property(_label, "visible_ratio", 1.0, text.length() / CHARS_PER_SEC)
	var hold := text.length() / CHARS_PER_SEC + READ_TIME + text.length() * READ_PER_CHAR
	var elapsed := 0.0
	while elapsed < hold and not cut and is_instance_valid(who):
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	t.kill()
	var out := create_tween()
	out.tween_property(self, "modulate:a", 0.0, 0.2)
	await out.finished
