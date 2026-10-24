#stranger.gd
# The amber stranger: an echo that is Ren exactly, face and all (the guides
# are faceless and all slightly off; this one isn't), in the voice's colour,
# that Ren keeps glimpsing. It gives off its own light, so in the dark it's
# the one thing he can see from afar. It never speaks and never lets him
# reach it: when he gets close it turns to look at him, then breaks up and is
# gone. (It is the Warden, Ren's own echo from an earlier climb; see
# guide_beats.gd. Don't explain it.)
# Each sighting plays once per run (StoryDirector.seen), and each one should
# show a little more than the last. Keep it appearing through the game. There
# is only ever one of it: a sighting with `after` waits until that one has
# gone, and one Ren gets past without coming close fades away on its own.
#   HOLD_PAD  standing on the pressure pad under it, holding its door open.
#             When it goes, the camera looks over at the door as it slams.
#   WATCH     appears when Ren enters `trigger`, walks to `walk_to_x` (if
#             set) and waits there for him.
#   DEMO      waits at the foot of something Ren will have to get past
#             until he comes into view (`watch_radius`), then does it once,
#             start to finish, while he watches: `moves` are inputs played
#             through Ren's own movement (echo.gd's phantom), so what it
#             shows is exactly what works. Then it looks back at him and goes.
# Place it over the floor it should stand (or start) on; it drops onto it.
extends Node2D

enum Act { HOLD_PAD, WATCH, DEMO }

const EchoScene = preload("res://echo/echo.tscn")

@export var act: Act = Act.WATCH
## Ren this close: it notices him, looks at him, and goes.
@export var notice_radius: float = 120.0
## WATCH: where Ren has to be (world coordinates) for it to appear.
@export var trigger: Rect2
## WATCH: walks here (world x) once it has appeared (0 = stays put).
@export var walk_to_x: float = 0.0
@export var face_right: bool = true
## HOLD_PAD: the door the camera looks at when the pad lets go.
@export var door: NodePath
## DEMO: Ren this close, it starts.
@export var watch_radius: float = 190.0
## DEMO: what it does, in frames (1/60 s). "R30" holds right for 30
## frames, "L12" left, "W20" waits; "J" presses jump on the next frame.
## e.g. "R10 J R40 W60": runs, jumps, lands, stands a second, starts over.
@export var moves: String = ""
## Waits, unseen, until the stranger of this name has gone ("" = no wait).
@export var after: String = ""
## Ren this far past it (to the right) without having come close: it just fades.
@export var passed_by: float = 220.0

const COLOR = Color(0.95, 0.75, 0.4)   # the voice's name colour
const WALK_SPEED = 100.0               # Ren's
const STARE_TIME = 1.1
const BREAK_TIME = 0.55
const LIGHT_SIZE = 1.1                 # its glow, as a scale of the 256 px light texture
const SFX_GONE = "res://audio/sfx/woosh_r.mp3"
const SHADER := """
shader_type canvas_item;
render_mode unshaded;   // its own light: the dark doesn't touch it
uniform vec4 tint : source_color = vec4(1.0);
uniform float glitch = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	// Ren's own sprite, eyes and all, recoloured in amber: dark parts deep
	// amber, light parts bright
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 col = mix(tint.rgb * 0.45, tint.rgb * 1.25, smoothstep(0.0, 0.7, lum));
	float scan = 0.94 + 0.06 * sin(FRAGCOORD.y * 0.9 + TIME * 6.0);
	// breaking up: rows of it drop out, a different few every frame
	float row = floor(FRAGCOORD.y / 3.0);
	float noise = fract(sin(row * 12.9898 + floor(TIME * 24.0) * 78.233) * 43758.5453);
	float keep = 1.0 - step(1.0 - glitch * 0.85, noise);
	COLOR = vec4(col * scan, c.a * tint.a * keep);
}
"""

var _sprite: AnimatedSprite2D     # what it looks like (the phantom's own sprite in a DEMO)
var _figure: Node2D               # what moves: this node, or the DEMO's phantom echo
var _phantom: Area2D
var _light: PointLight2D
var _mat: ShaderMaterial
var _hold: Area2D          # what the pad counts while it stands there
var _pads: Array = []
var _state := "waiting"    # (after ->) waiting -> here -> walking -> here -> leaving; a DEMO: ready -> showing -> leaving
var _flicker := 0.0
var _home: Vector2

func _ready() -> void:
	if StoryDirector.seen.has(_seen_key()):
		queue_free()
		return
	visible = false
	await get_tree().physics_frame
	await get_tree().physics_frame
	_mat = ShaderMaterial.new()
	_mat.shader = Shader.new()
	_mat.shader.code = SHADER
	_mat.set_shader_parameter("tint", Color(COLOR.r, COLOR.g, COLOR.b, 0.85))
	_land()
	if act == Act.DEMO:
		_build_phantom()
	else:
		_build()
	_light = glow_light(COLOR, LIGHT_SIZE, 0.9)
	_figure.add_child(_light)
	_home = global_position
	if _phantom:
		_phantom.set_physics_process(false)
	if after != "" and not StoryDirector.seen.has("stranger:" + after):
		_figure.visible = false
		_state = "after"
		return
	_begin()

## Its turn: shows itself (a WATCH waits for Ren to come into `trigger`).
func _begin() -> void:
	if act != Act.WATCH:
		_show()
	else:
		_state = "waiting"
	if act == Act.DEMO:
		_state = "ready"
		_sprite.play("idle")
		_sprite.flip_h = not face_right
	if act == Act.HOLD_PAD:
		_press_pads()

func _seen_key() -> String:
	return "stranger:" + name

## A soft round light (for the stranger, and Ren in the dark: darkness.gd).
static func glow_light(color: Color, size: float, energy: float) -> PointLight2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var light := PointLight2D.new()
	light.texture = tex
	light.color = color
	light.energy = energy
	light.texture_scale = size
	return light

func _build() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var src: AnimatedSprite2D = player.get_node("animations")
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = src.sprite_frames
	_sprite.position = src.position
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.flip_h = not face_right
	_sprite.material = _mat
	_sprite.play("idle")
	add_child(_sprite)
	z_index = (player as CanvasItem).z_index - 1
	_figure = self

## DEMO: an echo of `moves`, starting here, that nothing can touch.
func _build_phantom() -> void:
	_phantom = EchoScene.instantiate()
	get_parent().add_child(_phantom)
	_phantom.setup(frames_from(moves, global_position), false)
	_phantom.make_phantom(_mat)
	_phantom.global_position = global_position
	_phantom.z_index = (get_tree().get_first_node_in_group("player") as CanvasItem).z_index - 1
	_sprite = _phantom.anim
	_figure = _phantom

## Echo frames (echo.gd) for a `moves` string, starting at `start`, standing.
static func frames_from(spec: String, start: Vector2) -> Array:
	var frames: Array = []
	var jump_next := false
	for token in spec.split(" ", false):
		if token == "J":
			jump_next = true
			continue
		var move := 0.0
		match token[0]:
			"R": move = 1.0
			"L": move = -1.0
			"W": move = 0.0
			_: continue
		for i in int(token.substr(1)):
			frames.append({"move": move, "jump": jump_next})
			jump_next = false
	if frames.is_empty():
		frames.append({"move": 0.0, "jump": false})
	frames[0]["pos"] = start
	frames[0]["start"] = {"on_floor": true, "was_on_floor": true}
	return frames

## Stands on the floor under where it was placed, as Ren would.
func _land() -> void:
	var from := global_position
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 400), 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	if hit:
		global_position.y = hit.position.y - 8.0   # Ren's origin sits 8 px above his feet

func _show() -> void:
	visible = true
	_figure.modulate.a = 0.0
	_figure.visible = true
	create_tween().tween_property(_figure, "modulate:a", 1.0, 0.6)
	_state = "here"

func _press_pads() -> void:
	_hold = Area2D.new()
	_hold.monitoring = false
	_hold.monitorable = false
	add_child(_hold)
	for pad in get_tree().get_nodes_in_group("pressure_pad"):
		if (pad as Node2D).global_position.distance_to(global_position) < 24.0:
			pad.on_echo_enter(_hold)
			_pads.append(pad)

func _release_pads() -> void:
	for pad in _pads:
		if is_instance_valid(pad):
			pad.on_echo_exit(_hold)
	_pads.clear()

func _process(delta: float) -> void:
	if _light:
		# a slow, uneven breathing, like something not quite steady
		_flicker += delta
		_light.energy = 0.8 + 0.12 * sin(_flicker * 2.3) + 0.06 * sin(_flicker * 7.1)

func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null or _figure == null:
		return
	if _state in ["here", "walking", "after", "ready"] and player.global_position.x > _home.x + passed_by 			and absf(player.global_position.y - _home.y) < 200.0:
		_fade_out()
		return
	match _state:
		"after":
			if StoryDirector.seen.has("stranger:" + after):
				_begin()
		"ready":
			if _figure.global_position.distance_to(player.global_position) < watch_radius:
				_state = "showing"
				_phantom.played.connect(func(): _leave(player), CONNECT_ONE_SHOT)
				_phantom.set_physics_process(true)
		"waiting":
			if trigger.has_point(player.global_position):
				_show()
				if walk_to_x != 0.0:
					_state = "walking"
		"walking":
			var dir := signf(walk_to_x - global_position.x)
			global_position.x = move_toward(global_position.x, walk_to_x, WALK_SPEED * delta)
			_sprite.flip_h = dir < 0.0
			_sprite.play("run")
			if is_equal_approx(global_position.x, walk_to_x):
				_sprite.play("idle")
				_state = "here"
			elif _noticed(player):
				_leave(player)
		"here":
			if _noticed(player):
				_leave(player)

func _noticed(player: Node2D) -> bool:
	return _figure.global_position.distance_to(player.global_position) < notice_radius \
		and not player.get("is_dead")

## Ren went by without coming close: it just isn't there any more.
func _fade_out() -> void:
	_state = "leaving"
	set_process(false)
	var t := create_tween()
	t.tween_property(_figure, "modulate:a", 0.0, 0.8)
	t.parallel().tween_property(_light, "energy", 0.0, 0.8)
	await t.finished
	StoryDirector.seen[_seen_key()] = true   # gone now: the next sighting may show
	_release_pads()
	if is_instance_valid(_phantom):
		_phantom.queue_free()
	queue_free()

## Turns to look at Ren, holds it (a DEMO stops dead, even in mid-air), then
## breaks up and is gone.
func _leave(player: Node2D) -> void:
	_state = "leaving"
	if _phantom:
		_phantom.set_physics_process(false)
	_sprite.play("idle")
	_sprite.flip_h = player.global_position.x < _figure.global_position.x
	await get_tree().create_timer(STARE_TIME).timeout
	SoundManager.play(SFX_GONE, -10.0, 0.7)
	var t := create_tween()
	t.tween_method(func(g): _mat.set_shader_parameter("glitch", g), 0.0, 1.0, BREAK_TIME)
	t.parallel().tween_property(_figure, "modulate:a", 0.0, BREAK_TIME).set_ease(Tween.EASE_IN)
	t.parallel().tween_property(_light, "energy", 0.0, BREAK_TIME)
	set_process(false)
	await t.finished
	StoryDirector.seen[_seen_key()] = true   # gone now: the next sighting may show
	if act == Act.HOLD_PAD and not door.is_empty():
		await _look_at_door()
	_release_pads()
	if is_instance_valid(_phantom):
		_phantom.queue_free()
	queue_free()

## The camera goes over to the door, the pad lets go so it shuts on screen,
## and the camera goes back to Ren.
func _look_at_door() -> void:
	var cam := get_tree().get_first_node_in_group("camera") as Camera2D
	var target := get_node_or_null(door) as Node2D
	var player := get_tree().get_first_node_in_group("player")
	if cam == null or target == null or player == null:
		return
	StoryDirector.hold_guides = true
	player.controls_locked = true
	cam.hold = true
	var back: Vector2 = cam.global_position
	var look := target.global_position + Vector2(-40, -20)
	var t := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(cam, "global_position", look, 0.7)
	t.tween_callback(_release_pads)
	t.tween_interval(1.1)
	t.tween_property(cam, "global_position", back, 0.6)
	await t.finished
	cam.hold = false
	player.controls_locked = false
	StoryDirector.hold_guides = false
