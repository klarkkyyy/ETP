# boss.gd — the guardian (Lord Wizard) between Level 5 and Level 6.
# Nothing the player does hurts it directly. It surfaces at fixed spots
# (Marker2D children of `emerge_points`), each covered by an arena trap, throws
# orbs, then sinks and moves on underground. A trap that catches it surfaced
# knocks it back down. Loop:
#   WARN (glowing ripple at the next spot) -> EMERGING -> IDLE/ATTACK volleys
#   -> HIDING -> BURROWED (ripple travels, or vanishes to another ledge) -> WARN ...
# It never surfaces where the player stands on a pad that covers the spot (it
# watches you, but not your echoes) and doesn't revisit its last two spots.
# Each marker's `pads` metadata lists the pads whose traps cover it.
# Three phases (PHASES) add spread shots, ring bursts, decoy warnings and, last,
# ambushes: it burrows under the player and erupts there.
extends CharacterBody2D

signal defeated

const OrbScene = preload("res://scenes/orb.tscn")
const FONT = preload("res://assets/fonts/BoldPixels.ttf")
const SFX_THROW = "res://audio/sfx/woosh.mp3"
const SFX_HIT = "res://audio/sfx/stone_door_close.mp3"
const SFX_DEFEAT = "res://audio/sfx/clear.mp3"

@export var max_health: float = 140.0
## Node whose Marker2D children are the spots it surfaces at.
@export var emerge_points: NodePath = ^"../EmergePoints"
## Arena interior in the parent's coordinates; the fight runs while the player is inside.
@export var arena_rect: Rect2 = Rect2(-32, -160, 864, 648)
## Camera view held during the fight, in the parent's coordinates: floor to the
## highest ledge, wall to wall, so it never attacks from off screen.
@export var camera_rect: Rect2 = Rect2(-48, 208, 896, 288)
@export var camera_zoom: float = 2.25  # shows camera_rect's full height
@export var attack_range: float = 280.0  # won't throw at anything further (it'd be off screen)
@export var hit_invuln: float = 1.0
@export var heal_on_player_death: float = 20.0  # one trap hit's worth; phases never go back

enum State { DORMANT, WARN, EMERGING, IDLE, ATTACK, HIT, HIDING, BURROWED, DEAD }

# A phase runs from health fraction `from` down. volleys: one attack each, in order.
const PHASES := [
	{"from": 1.0, "volleys": ["aim", "aim"], "pause": 0.8, "warn": 0.8, "linger": 0.7,
		"speed": 140.0, "decoy": 0.0, "ambush": 0.0, "color": Color(0.78, 0.16, 0.22)},
	{"from": 0.6, "volleys": ["spread", "ring", "spread"], "pause": 0.55, "warn": 0.65, "linger": 0.5,
		"speed": 155.0, "decoy": 0.5, "ambush": 0.0, "color": Color(0.95, 0.45, 0.15)},
	{"from": 0.3, "volleys": ["ring", "spread", "aim", "spread"], "pause": 0.4, "warn": 0.55, "linger": 0.35,
		"speed": 170.0, "decoy": 0.5, "ambush": 0.5, "color": Color(0.85, 0.25, 0.9)},
]
const START_DELAY := 1.2      # after the player walks in
const ORB_FRAME := 6          # attack frame where the orb leaves its hand
const HAND := Vector2(10, -28)
const SPREAD_DEG := 16.0
const RING_ORBS := 8
const RING_SPEED := 0.7       # ring orbs fly at this fraction of the phase's orb speed
const BURROW_SPEED := 220.0
const VANISH_TIME := 0.35     # hidden time when changing ledges
const NEAR_SPOT := 260.0      # spots this close to the player (on screen) are twice as likely
const RECENT := 2             # doesn't return to its last this-many spots
const SAME_SURFACE := 2.0     # px; spots this level with each other are reached as a ripple
const RESPAWN_GRACE := 2.0    # s after the player respawns before it may target them
const AMBUSH_WARN := 0.75     # s of warning before it erupts under the player
const AMBUSH_KILL := Vector2(14, 44)  # half width / height of the eruption, up from its feet

var current_health: float = 0.0
var is_dead := false
var is_enraged := false       # phase 2 or later
var phase_index := 0
var state: State = State.DORMANT
var direction := -1

var _spots: Array[Vector2] = []
var _spot_pads: Array = []    # per spot: the pads whose traps cover it
var _spot := -1               # -1 while ambushing (not on a spot)
var _pos := Vector2.ZERO      # where it is, or is heading
var _recent: Array[int] = []
var _ambush := false
var _timer := START_DELAY
var _volleys_left := 0
var _volley := 0
var _fired := false
var _invuln := 0.0
var _travelling := false
var _grace := 0.0
var _player_was_dead := false
var _target: Node2D = null
var _player: Node2D = null
var _hud: CanvasLayer
var _bar: ProgressBar
var _cam_saved: Array = []  # [zoom, top, bottom, left, right] from before the fight
var _marker: Node2D         # the glowing warning where it will surface
var _decoy: Node2D          # a second, fake one

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var ripple: AnimatedSprite2D = $Ripple


func _ready() -> void:
	current_health = max_health
	_player = get_tree().get_first_node_in_group("player")
	var holder := get_node_or_null(emerge_points)
	if holder:
		for m in holder.get_children():
			if m is Node2D:
				_spots.append(m.global_position)
				var pads := []
				for path in m.get_meta("pads", []):
					var pad := m.get_node_or_null(path)
					if pad:
						pads.append(pad)
				_spot_pads.append(pads)
	if _spots.is_empty():
		push_warning("boss: no emerge points under %s" % emerge_points)
		_spots.append(global_position)
		_spot_pads.append([])
	_marker = _make_marker()
	_decoy = _make_marker()
	_build_hud()
	_go_dormant()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_invuln = maxf(_invuln - delta, 0.0)
	_grace = maxf(_grace - delta, 0.0)
	if _player:
		if _player_was_dead and not _player.is_dead:
			_grace = RESPAWN_GRACE
		elif _player.is_dead and not _player_was_dead and state != State.DORMANT:
			_heal(heal_on_player_death)
		_player_was_dead = _player.is_dead
	if state == State.DORMANT:
		if _player_in_arena():
			_timer -= delta
			if _timer <= 0.0:
				_hud.visible = true
				_frame_camera(true)
				_go_to(_pick_spot())
				_warn()
		else:
			_timer = START_DELAY
		return
	if not _player_in_arena():
		_go_dormant()  # left through the portal; keeps its health for next time
		return

	var phase := _phase()
	_timer -= delta
	match state:
		State.WARN:
			if _timer <= 0.0:
				_emerge()
		State.EMERGING:
			if _ambush and sprite.frame >= 1 and sprite.frame <= 5:
				_erupt()
			if _timer <= 0.0:
				_volleys_left = phase.volleys.size()
				_volley = 0
				_idle(phase.linger)
		State.IDLE:
			if _timer <= 0.0:
				if _volleys_left <= 0:
					_hide()
				elif _pick_target():
					_attack()
				else:
					_next_volley()  # nothing in reach; wait this one out
		State.ATTACK:
			if not _fired and sprite.frame >= ORB_FRAME:
				_fired = true
				_throw()
			if _timer <= 0.0:
				_next_volley()
		State.HIT:
			if _timer <= 0.0:
				_hide()
		State.HIDING:
			if _timer <= 0.0:
				_burrow()
		State.BURROWED:
			if _travelling:
				global_position.x = move_toward(global_position.x, _pos.x, BURROW_SPEED * delta)
				if is_equal_approx(global_position.x, _pos.x):
					_warn()
			elif _timer <= 0.0:
				_warn()


# ── States ────────────────────────────────────────────────────────────────────
func _go_dormant() -> void:
	state = State.DORMANT
	_timer = START_DELAY
	sprite.visible = false
	ripple.visible = false
	_marker.visible = false
	_decoy.visible = false
	if _hud:
		_hud.visible = false
	_frame_camera(false)


func _warn() -> void:
	state = State.WARN
	_travelling = false
	global_position = _pos
	sprite.visible = false
	ripple.visible = false
	_marker.global_position = _pos
	_marker.visible = true
	_timer = AMBUSH_WARN if _ambush else _phase().warn
	# Phase 2+: sometimes a second, fake warning at another spot.
	if not _ambush and randf() < _phase().decoy:
		var fake := _pick_spot([_spot])
		if fake != _spot:
			_decoy.global_position = _spots[fake]
			_decoy.visible = true


func _emerge() -> void:
	state = State.EMERGING
	_marker.visible = false
	_decoy.visible = false
	sprite.visible = true
	_face(_player)
	_timer = _play("emerge")


func _idle(time: float) -> void:
	state = State.IDLE
	sprite.play("idle")
	_timer = time


func _next_volley() -> void:
	_volleys_left -= 1
	_volley += 1
	_idle(_phase().pause)


func _attack() -> void:
	state = State.ATTACK
	_fired = false
	_face(_target)
	_timer = _play("attack")


func _hide() -> void:
	state = State.HIDING
	_timer = _play("hide")


func _burrow() -> void:
	state = State.BURROWED
	sprite.visible = false
	var from := global_position
	var floor_y := _floor_y()
	if randf() < _phase().ambush and _grace <= 0.0 and _player and not _player.is_dead \
			and _player.is_on_floor() and absf(_player.global_position.y - floor_y) < 24.0:
		# Under the player, wherever they are on the floor. No trap covers it
		# there except the floor spear.
		var r := (get_parent() as Node2D).global_transform * arena_rect
		_spot = -1
		_ambush = true
		_pos = Vector2(clampf(_player.global_position.x, r.position.x + 24.0, r.end.x - 24.0), floor_y)
	else:
		_go_to(_pick_spot())
	_travelling = absf(from.y - _pos.y) <= SAME_SURFACE
	if _travelling:
		direction = 1 if _pos.x > from.x else -1
		ripple.visible = true
		ripple.play("burrow_right" if direction == 1 else "burrow_left")
	else:
		ripple.visible = false
		_timer = VANISH_TIME


## Ambush eruption: kills the player if they're still standing on it.
func _erupt() -> void:
	if _player == null or _player.is_dead:
		return
	var d := _player.global_position - global_position
	if absf(d.x) < AMBUSH_KILL.x and d.y > -AMBUSH_KILL.y and d.y < 4.0:
		_player.die()


# ── Attacks ───────────────────────────────────────────────────────────────────
## Nearest of the player and their echoes within reach. Echoes draw its fire
## (and each one swallows an orb), which buys the player time.
func _pick_target() -> bool:
	_target = null
	if _player == null or _player.get("is_dead"):
		return false
	var best := attack_range
	var candidates: Array = [] if _grace > 0.0 else [_player]
	for e in get_tree().get_nodes_in_group("echo"):
		if e.get("_is_active"):
			candidates.append(e)
	for c in candidates:
		var d := global_position.distance_to(c.global_position)
		if d <= best:
			best = d
			_target = c
	return _target != null


func _throw() -> void:
	if not is_instance_valid(_target):
		return
	var phase := _phase()
	var kind: String = phase.volleys[_volley % phase.volleys.size()]
	var speed: float = phase.speed
	if kind == "ring":
		# A burst all around it from the chest; slower, so the gaps can be read.
		var center := global_position + Vector2(0, -24)
		var start := randf() * TAU
		for i in RING_ORBS:
			_spawn_orb(center, Vector2.RIGHT.rotated(start + TAU * i / RING_ORBS), speed * RING_SPEED)
	else:
		var origin := global_position + Vector2(HAND.x * direction, HAND.y)
		var aim := (_target.global_position - origin).normalized()
		var angles := [0.0, -SPREAD_DEG, SPREAD_DEG] if kind == "spread" else [0.0]
		for a in angles:
			_spawn_orb(origin, aim.rotated(deg_to_rad(a)), speed)
	SoundManager.play(SFX_THROW, -12)


func _spawn_orb(at: Vector2, dir: Vector2, speed: float) -> void:
	var orb := OrbScene.instantiate()
	get_parent().add_child(orb)
	orb.global_position = at
	orb.launch(dir, speed)


# ── Damage ────────────────────────────────────────────────────────────────────
## Called by the arena traps. Returns whether the hit landed: it only can while
## surfaced, and not again until `hit_invuln` has passed.
func take_damage(amount: float) -> bool:
	if is_dead or _invuln > 0.0:
		return false
	if state not in [State.EMERGING, State.IDLE, State.ATTACK, State.HIDING]:
		return false
	current_health = maxf(current_health - amount, 0.0)
	_bar.value = current_health
	_invuln = hit_invuln
	sprite.modulate = Color(2.5, 2.5, 2.5)
	create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.25)
	SoundManager.play(SFX_HIT, -6)
	if current_health <= 0.0:
		die()
		return true
	while phase_index + 1 < PHASES.size() and current_health <= max_health * PHASES[phase_index + 1].from:
		phase_index += 1
		is_enraged = true
		_bar.add_theme_stylebox_override("fill", _box(_phase().color))
	state = State.HIT
	_timer = _play("hit")
	return true


## Each time the player dies mid-fight it recovers a little. The phase it has
## reached stays, so dying doesn't make the fight easier again.
func _heal(amount: float) -> void:
	if amount <= 0.0 or current_health >= max_health:
		return
	current_health = minf(current_health + amount, max_health)
	var tw := create_tween()
	tw.tween_property(_bar, "value", current_health, 0.5)
	_bar.modulate = Color(0.6, 1.8, 0.7)
	create_tween().tween_property(_bar, "modulate", Color.WHITE, 0.8)
	if sprite.visible:
		sprite.modulate = Color(0.6, 1.8, 0.7)
		create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.6)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	state = State.DEAD
	ripple.visible = false
	_marker.visible = false
	_decoy.visible = false
	sprite.visible = true
	collision_layer = 0
	for orb in get_tree().get_nodes_in_group("orb"):
		orb.queue_free()
	_hud.visible = false
	_frame_camera(false)
	SoundManager.play(SFX_DEFEAT, -4)
	defeated.emit()
	sprite.play("death")
	await sprite.animation_finished
	await create_tween().tween_property(sprite, "modulate:a", 0.0, 0.4).finished
	queue_free()


# ── Helpers ───────────────────────────────────────────────────────────────────
func _phase() -> Dictionary:
	return PHASES[phase_index]


func _go_to(i: int) -> void:
	_spot = i
	_ambush = false
	_pos = _spots[i]
	_recent.append(i)
	if _recent.size() > RECENT:
		_recent.pop_front()


## Next spot. Never one of its last RECENT spots, right where the player
## stands, or a spot the player guards (standing on one of its pads).
## On-screen spots are twice as likely. Relaxes the rules if nothing is left.
func _pick_spot(exclude: Array = []) -> int:
	var p := _player.global_position if _player else global_position
	var guarded := []
	for i in _spots.size():
		for pad in _spot_pads[i]:
			if is_instance_valid(pad) and pad.get("_player_count") > 0:
				guarded.append(i)
				break
	for strict in [true, false]:
		var pool: Array[int] = []
		var weights := PackedFloat32Array()
		for i in _spots.size():
			var s := _spots[i]
			if i == _spot or i in exclude:
				continue
			if strict and (i in _recent or i in guarded):
				continue
			if absf(s.x - p.x) < 32.0 and absf(s.y - p.y) < 40.0:
				continue  # would come up inside the player
			pool.append(i)
			weights.append(2.0 if s.distance_to(p) <= NEAR_SPOT else 1.0)
		if not pool.is_empty():
			return pool[RandomNumberGenerator.new().rand_weighted(weights)]
	return (maxi(_spot, 0) + 1) % _spots.size()


## The arena floor: the lowest spot.
func _floor_y() -> float:
	var y := -INF
	for s in _spots:
		y = maxf(y, s.y)
	return y


func _player_in_arena() -> bool:
	if _player == null:
		return false
	return arena_rect.has_point((get_parent() as Node2D).to_local(_player.global_position))


func _face(node: Node2D) -> void:
	if is_instance_valid(node):
		direction = 1 if node.global_position.x >= global_position.x else -1


## Plays the facing variant of `base` and returns its length in seconds.
func _play(base: String) -> float:
	var anim := "%s_%s" % [base, "right" if direction == 1 else "left"]
	sprite.play(anim)
	var frames := sprite.sprite_frames
	return frames.get_frame_count(anim) / frames.get_animation_speed(anim)


func _frame_camera(on: bool) -> void:
	var cam := get_tree().get_first_node_in_group("camera") as Camera2D
	var framed := not _cam_saved.is_empty()
	if cam == null or on == framed:
		return
	Echoes.unlimited = on  # the fight runs on free echoes
	Echoes.mortal = on     # and spears kill them
	if on:
		_cam_saved = [cam.zoom, cam.limit_top, cam.limit_bottom, cam.limit_left, cam.limit_right]
		var r := (get_parent() as Node2D).global_transform * camera_rect
		cam.set_limits(int(r.position.y), int(r.end.y), int(r.position.x), int(r.end.x))
		create_tween().tween_property(cam, "zoom", Vector2.ONE * camera_zoom, 0.8)
	else:
		cam.set_limits(_cam_saved[1], _cam_saved[2], _cam_saved[3], _cam_saved[4])
		create_tween().tween_property(cam, "zoom", _cam_saved[0], 0.8)
		_cam_saved = []


## The warning where it will surface: its ground-ripple strip (black, which
## vanishes on the dark floor) over a pulsing purple glow.
func _make_marker() -> Node2D:
	var m := Node2D.new()
	m.top_level = true
	m.z_index = z_index - 1
	m.visible = false
	for ring in [[26.0, Color(0.75, 0.35, 1.0, 0.45)], [14.0, Color(0.9, 0.6, 1.0, 0.6)]]:
		var glow := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 24:
			pts.append(Vector2(cos(TAU * i / 24), sin(TAU * i / 24) * 0.3) * ring[0] + Vector2(0, -3))
		glow.polygon = pts
		glow.color = ring[1]
		m.add_child(glow)
	var strip := AnimatedSprite2D.new()
	strip.sprite_frames = ripple.sprite_frames
	strip.position = ripple.position
	strip.play("warn")
	m.add_child(strip)
	add_child(m)
	var tw := m.create_tween().set_loops()
	tw.tween_property(m, "modulate:a", 0.5, 0.25)
	tw.tween_property(m, "modulate:a", 1.0, 0.25)
	return m


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 40  # under the story overlay (45) and dialogue box
	add_child(_hud)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)

	var title := Label.new()
	title.text = "The Guardian"
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.5
	title.anchor_right = 0.5
	title.offset_left = -220
	title.offset_right = 220
	title.offset_top = 14
	title.offset_bottom = 44
	root.add_child(title)

	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = max_health
	_bar.value = current_health
	_bar.anchor_left = 0.5
	_bar.anchor_right = 0.5
	_bar.offset_left = -220
	_bar.offset_right = 220
	_bar.offset_top = 46
	_bar.offset_bottom = 60
	var bg := _box(Color(0.04, 0.04, 0.08, 0.85))
	bg.border_color = Color(0.78, 0.74, 0.62)
	bg.set_border_width_all(2)
	_bar.add_theme_stylebox_override("background", bg)
	_bar.add_theme_stylebox_override("fill", _box(PHASES[0].color))
	root.add_child(_bar)


func _box(color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(2)
	return s
