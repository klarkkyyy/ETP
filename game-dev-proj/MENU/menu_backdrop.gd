#menu_backdrop.gd
# The title screen's living background, on the "background" CanvasLayer: the
# tutorial's night garden (sky, moon, pine treelines) in layers that drift
# sideways at their own pace, mist between them, fireflies, a breathing glow on
# the moon, and now and then a faint echo of Ren running through the forest.
# Everything is built here in code, in screen pixels.
extends CanvasLayer

const GARDEN := "res://assets/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Tilesets/garden/"
const PLAYER := "res://player/player.tscn"
const SCREEN := Vector2(1152, 648)
const MOON := Vector2(1012, 110)       # the moon in the sky art, on screen
const ECHO_FEET := 560.0               # the echo runs among the trees, between the mid and near treelines
const ECHO_SIZE := 3.0
const ECHO_EVERY := Vector2(7.0, 12.0) # seconds between echo runs (random in range)

# [texture, scale, top of the art on screen, drift px/s, tint]: back to front.
# Further treelines are paler (closer to the sky) and slower.
const TREELINES := [
	["bg_02_garden.png", 2.6, 318.0, 4.0, Color(0.92, 0.88, 1.0)],
	["bg_01_garden.png", 3.2, 352.0, 10.0, Color(0.78, 0.72, 0.86)],
	["bg_01_garden.png", 4.6, 340.0, 24.0, Color(0.16, 0.12, 0.2)],
]

var _strips: Array[Sprite2D] = []
var _speeds: Array[float] = []
var _mist: Sprite2D
var _moon_glow: Sprite2D
var _echo_frames: SpriteFrames
var _t := 0.0
var _next_echo := 1.5


func _ready() -> void:
	for c in get_children():   # the old single sky picture
		c.queue_free()
	var sky := _sprite(load(GARDEN + "bg_00_garden.png"), SCREEN.y / 160.0)
	sky.region_rect.size.x = SCREEN.x / sky.scale.x + 1
	_moon_glow = _glow(MOON, 150.0, Color(0.85, 0.75, 1.0, 0.18))
	for i in TREELINES.size():
		var line: Array = TREELINES[i]
		var s := _sprite(load(GARDEN + line[0]), line[1])
		s.position.y = line[2]
		s.modulate = line[4]
		_strips.append(s)
		_speeds.append(line[3])
		if i == 0:
			_mist = _make_mist(395.0)
	_fireflies()
	var player_scene := load(PLAYER) as PackedScene
	var probe := player_scene.instantiate()
	_echo_frames = (probe.get_node("animations") as AnimatedSprite2D).sprite_frames
	probe.free()


func _process(delta: float) -> void:
	_t += delta
	for i in _strips.size():
		_strips[i].region_rect.position.x = fmod(_t * _speeds[i] / _strips[i].scale.x, _strips[i].texture.get_width())
	_mist.region_rect.position.x = fmod(_t * 7.0, 256.0)
	_moon_glow.modulate.a = 0.75 + 0.25 * sin(_t * 0.9)
	_next_echo -= delta
	if _next_echo <= 0.0:
		_next_echo = randf_range(ECHO_EVERY.x, ECHO_EVERY.y)
		_run_echo()


## A strip of `tex` repeated sideways across the screen at `size`x, top-left at the origin.
func _sprite(tex: Texture2D, size: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, SCREEN.x / size + tex.get_width(), tex.get_height())
	s.scale = Vector2(size, size)
	add_child(s)
	return s


## A soft additive glow of `radius` px around `at`.
func _glow(at: Vector2, radius: float, color: Color) -> Sprite2D:
	var g := Gradient.new()
	g.set_color(0, color)
	g.set_color(1, Color(color, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	var s := Sprite2D.new()
	s.texture = tex
	s.position = at
	s.scale = Vector2.ONE * radius * 2.0 / 128.0
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = m
	add_child(s)
	return s


## A drifting band of pale mist centred on y `mid`.
func _make_mist(mid: float) -> Sprite2D:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.seed = 3
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0.5))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 32
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = ramp
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.region_rect = Rect2(0, 0, SCREEN.x / 4.0 + 256, 32)
	s.scale = Vector2(4, 3)
	s.position = Vector2(0, mid - 48)
	s.modulate = Color(0.85, 0.78, 1.0, 0.5)
	var sh := Shader.new()   # fade toward the band's top and bottom edges
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tCOLOR = texture(TEXTURE, UV) * COLOR;\n\tCOLOR.a *= sin(UV.y * PI);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	s.material = m
	add_child(s)
	return s


## Fireflies wandering low over the near trees, blinking on and off.
func _fireflies() -> void:
	var f := CPUParticles2D.new()
	f.position = Vector2(SCREEN.x * 0.5, 540)
	f.amount = 28
	f.lifetime = 7.0
	f.preprocess = 7.0
	f.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	f.emission_rect_extents = Vector2(SCREEN.x * 0.55, 90)
	f.direction = Vector2(1, -0.3)
	f.spread = 180.0
	f.gravity = Vector2(0, -2)
	f.initial_velocity_min = 4.0
	f.initial_velocity_max = 14.0
	f.angular_velocity_min = 0.0
	f.scale_amount_min = 2.0
	f.scale_amount_max = 3.0
	var blink := Gradient.new()
	var on := Color(1.0, 0.92, 0.55)
	blink.set_color(0, Color(on, 0.0))
	blink.add_point(0.2, on)
	blink.add_point(0.35, Color(on, 0.15))
	blink.add_point(0.55, on)
	blink.set_color(blink.get_point_count() - 1, Color(on, 0.0))
	f.color_ramp = blink
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	f.material = m
	add_child(f)
	var halo := f.duplicate() as CPUParticles2D   # a soft halo around a few of them
	halo.amount = 6
	halo.scale_amount_min = 7.0
	halo.scale_amount_max = 10.0
	halo.modulate = Color(1, 1, 1, 0.12)
	add_child(halo)


## A faint cyan echo of Ren runs through the forest, behind the near
## treeline, trailing two fainter copies.
func _run_echo() -> void:
	var rightward := randf() < 0.6
	var from := -60.0 if rightward else SCREEN.x + 60.0
	var to := SCREEN.x + 60.0 if rightward else -60.0
	var duration := absf(to - from) / 260.0
	for k in 3:
		var ghost := AnimatedSprite2D.new()
		ghost.sprite_frames = _echo_frames
		ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ghost.play("run")
		ghost.flip_h = not rightward
		ghost.position = Vector2(from, ECHO_FEET - 8 * ECHO_SIZE)
		ghost.scale = Vector2.ONE * ECHO_SIZE
		ghost.modulate = Color(0.45, 0.95, 1.0, 0.5 / (k + 1))
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ghost.material = m
		add_child(ghost)
		move_child(ghost, _strips[-1].get_index())   # behind the near treeline
		var tw := ghost.create_tween()
		tw.tween_interval(k * 0.06)
		tw.tween_property(ghost, "position:x", to, duration)
		tw.tween_callback(ghost.queue_free)
