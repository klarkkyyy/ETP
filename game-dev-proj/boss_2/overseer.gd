# overseer.gd — the Overseer, the floating mechanical eye that chases Ren
# through the boss 2 level. It can't be fought: it follows `path` (a Path2D
# laid along the level's route) straight through the rock, and touching it
# kills. It drifts at the speed `speed_marks` sets for that stretch of the
# path and races to catch up when Ren gets more than `lead` ahead, so it is
# always close. Within `near` of Ren it slows the closer it gets, down to
# `close_floor` at the touch, so waiting a moment for a trap costs ground but
# isn't certain death, while standing still is (it creeps in over a few
# seconds). If Ren slips back
# past it, it turns round. When Ren respawns
# it reappears `respawn_gap` behind him after `respawn_grace` seconds.
# Its attacks, only while it hangs in open air and Ren is in range:
#   beam  — a warning line locked on where Ren stood, held long enough to step
#           out of, then a ray down exactly that line; it stops at walls but
#           passes through echoes
#   bolts — a fan of bolts (eye_bolt.gd) aimed where Ren is running to;
#           walls and echoes stop them
#   ring  — from halfway on, a ring of bolts in every direction
# Attacks come faster the further along the path Ren gets, and once Ren gets
# past `enrage_at` (the last two sections) it enrages for good: it glows and
# shakes red, moves faster, attacks far more often, follows each beam with a
# fan of bolts, fires its bolts in double volleys and its rings denser. The
# beam's warning keeps its full length. intro() lets the
# voice warn Ren first and then wakes it. flush() is the finale: the torrent
# from the last floodgate washes it back down the path.
extends Node2D

signal defeated

const SHEETS = "res://assets/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/Another Metroidvania Asset Pack Vol. 1 ver. 1.7/UPDATES/UPDATE ver 1.6/boss/beleye_boss_%s.png"
const ANIMS = {"idle": [8, true], "run": [10, true], "attack": [6, false], "other_attack": [6, false],
		"taking_damage": [5, true], "death": [15, false]}
const BoltScript = preload("res://boss_2/eye_bolt.gd")
const SFX_WAKE = "res://audio/sfx/stone_door.mp3"
const SFX_BEAM = "res://audio/sfx/woosh_r.mp3"
const SFX_BOLTS = "res://audio/sfx/woosh.mp3"
const SFX_DEFEAT = "res://audio/sfx/clear.mp3"
const SFX_ENRAGE = "res://audio/sfx/stone_door_close.mp3"

@export var path: NodePath
@export var base_speed: float = 90.0        # px/s along the path, where no speed mark applies
## (offset along the path, speed from there on), sorted by offset
@export var speed_marks: PackedVector2Array = PackedVector2Array()
@export var catch_up_speed: float = 240.0
@export var lead: float = 300.0             # Ren this far ahead along the path: it races to catch up
@export var near: float = 170.0             # closer than this it slows down...
@export var close_floor: float = 32.0       # ...to this at the touch (px/s)
@export var kill_radius: float = 42.0       # the shell, ~90 px across at sprite_scale 1.5
@export var respawn_gap: float = 380.0
@export var respawn_grace: float = 1.2
@export var sprite_scale: float = 1.5
## Ren this far along the path (px) enrages it for the rest of the chase; -1: never.
@export var enrage_at: float = -1.0
@export var enrage_speed: float = 1.35       # its speeds (and catch-up) times this
@export var enrage_cooldown: float = 0.55    # time between attacks times this
@export var enrage_max_speed: float = 95.0   # enraged, it still never outruns Ren's 100 px/s
## StoryDirector event played before it wakes ("" = wake straight away).
@export var intro_event: String = "overseer"

@export_group("Attacks")
@export var attack_range: float = 320.0
@export var beam_length: float = 640.0
@export var beam_warn: float = 1.15          # the warning line holds this long before it fires
@export var beam_fire: float = 0.3
@export var beam_half_width: float = 5.0
@export var bolt_speed: float = 175.0
@export var bolt_count: int = 5
@export var bolt_spread_deg: float = 12.0
@export var ring_from: float = 0.5           # fraction of the path where ring bursts start
@export var ring_count: int = 12
## seconds between the eye's own attacks at the start of the path and at its end
@export var cooldown_start: float = 2.2
@export var cooldown_end: float = 1.1

var is_dead := false
var awake := false
var offset := 0.0                           # the eye's distance along the path

var _path: Path2D
var _curve: Curve2D
var _player: Node2D
var _player_offset := 0.0
var _player_was_dead := false
var _wait := 0.0
var _cooldown := 1.5
var _flushed := false
var _sprite: AnimatedSprite2D
var _beam: Line2D
var _beam_dir := Vector2.ZERO
var _beam_from := Vector2.ZERO               # locked when the warning appears
var _beam_t := -1.0                          # time into the current beam, -1: none
var _bob := 0.0
var _intro_started := false
var enraged := false

func _ready() -> void:
	z_index = 8  # over the rock it drifts through
	_path = get_node_or_null(path) as Path2D
	_curve = _path.curve if _path else null
	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2.ONE * sprite_scale
	_sprite.animation_finished.connect(_on_anim_finished)
	add_child(_sprite)
	_beam = Line2D.new()
	_beam.top_level = true
	_beam.z_index = 9
	_beam.visible = false
	_beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(_beam)
	visible = false
	set_physics_process(false)

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ANIMS:
		var tex: Texture2D = load(SHEETS % anim)
		frames.add_animation(anim)
		frames.set_animation_loop(anim, ANIMS[anim][1])
		frames.set_animation_speed(anim, 10.0)
		for i in ANIMS[anim][0]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * 64, 0, 64, 64)
			frames.add_frame(anim, at)
	return frames

## Connect the trigger that starts the chase to this: the voice warns Ren
## about it (the game is paused while it talks), then it wakes. Once the
## warning has been heard, later runs skip straight to waking.
func intro() -> void:
	if _intro_started or awake:
		return
	_intro_started = true
	if intro_event != "" and StoryDirector.has_method("event"):
		StoryDirector.event(intro_event)
		await get_tree().process_frame
		while get_tree().paused or StoryDirector.get("_playing"):
			await get_tree().process_frame
	wake()

## Starts the chase. Safe to call more than once.
func wake() -> void:
	if awake or is_dead or _curve == null:
		return
	awake = true
	_player = get_tree().get_first_node_in_group("player") as Node2D
	offset = 0.0
	_place()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
	_sprite.play("idle")
	_wait = 0.8
	SoundManager.play(SFX_WAKE, -2)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if _flushed or _player == null:
		return
	var dead: bool = _player.get("is_dead")
	if dead and not _player_was_dead:
		_cancel_attacks()
	elif not dead and _player_was_dead:
		_on_player_respawned()
	_player_was_dead = dead
	if dead:
		return
	_track_player()
	if not enraged and enrage_at >= 0.0 and _player_offset >= enrage_at:
		_enrage()
	if _wait > 0.0:
		_wait -= delta
	elif _beam_t < 0.0:
		_move(delta)  # it holds still while it glares
	_place()
	if global_position.distance_to(_player.global_position + Vector2(0, -7)) < kill_radius:
		_player.die()
		return
	_attack(delta)

## How far along the path the eye is, 0..1.
func progress() -> float:
	return clampf(offset / _curve.get_baked_length(), 0.0, 1.0)

# ── Chase ─────────────────────────────────────────────────────────────────────
func _track_player() -> void:
	var o := _curve.get_closest_offset(_path.to_local(_player.global_position))
	# the route doubles back on itself in places; don't let Ren's place on it jump
	if absf(o - _player_offset) < 500.0:
		_player_offset = o

func _move(delta: float) -> void:
	var speed := _speed_at(offset)
	var ahead := _player_offset - offset
	if ahead > lead:
		var catch_up := catch_up_speed * (enrage_speed if enraged else 1.0)
		speed = lerpf(speed, catch_up, clampf((ahead - lead) / 160.0, 0.0, 1.0))
	elif ahead < near:
		var creep := minf(close_floor * (1.2 if enraged else 1.0), speed)
		speed = lerpf(creep, speed, clampf((ahead - kill_radius) / (near - kill_radius), 0.0, 1.0))
	# Ren slipped back past it (or went back for a valve): it turns round
	var step := speed * delta if ahead >= 0.0 else -minf(speed * delta, -ahead)
	offset = clampf(offset + step, 0.0, _curve.get_baked_length())
	if _beam_t < 0.0 and _sprite.animation in ["idle", "run"]:
		_sprite.play("run" if speed > _speed_at(offset) * 1.3 else "idle")

func _speed_at(at: float) -> float:
	var s := base_speed
	for m in speed_marks:
		if at >= m.x:
			s = m.y
	return minf(s * enrage_speed, maxf(s, enrage_max_speed)) if enraged else s

func _place() -> void:
	_bob += get_physics_process_delta_time() * 2.4
	var p := _path.to_global(_curve.sample_baked(offset))
	global_position = p + Vector2(0, sin(_bob) * 4.0)
	if _player:
		_sprite.flip_h = _player.global_position.x < global_position.x

func _on_player_respawned() -> void:
	_player_offset = _curve.get_closest_offset(_path.to_local(_player.global_position))
	offset = maxf(0.0, _player_offset - respawn_gap)
	# near the start there's no room to put it a full gap behind: it waits instead
	_wait = respawn_grace + maxf(0.0, respawn_gap - _player_offset) / maxf(_speed_at(0.0), 1.0)
	_cooldown = maxf(_cooldown, 1.0)
	_place()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

# ── The eye's attacks ─────────────────────────────────────────────────────────
func _attack(delta: float) -> void:
	if _beam_t >= 0.0:
		_run_beam(delta)
		return
	_cooldown -= delta
	if _cooldown > 0.0 or _wait > 0.0:
		return
	var to_player := _player.global_position + Vector2(0, -7) - global_position
	if to_player.length() > attack_range or _in_rock(global_position):
		return
	var t := progress()
	_cooldown = lerpf(cooldown_start, cooldown_end, t) * randf_range(0.85, 1.15)
	if enraged:
		_cooldown *= enrage_cooldown
	var roll := randf()
	if t >= ring_from and roll < 0.25:
		_fire_ring()
	elif roll < 0.6:
		_start_beam(to_player.normalized())
	else:
		_fire_bolts()

func _start_beam(dir: Vector2) -> void:
	_beam_dir = dir
	_beam_from = global_position
	_beam_t = 0.0
	_sprite.play("attack")
	_beam.visible = true

func _run_beam(delta: float) -> void:
	_beam_t += delta
	var from := _beam_from
	var to := _beam_end(from, _beam_dir)
	_beam.points = PackedVector2Array([from, to])
	if _beam_t < beam_warn:
		# the warning: exactly the line it will fire down, as wide as the
		# beam, flickering faster as it's about to fire
		var k := _beam_t / beam_warn
		var flick := 0.3 + 0.2 * sin(_beam_t * lerpf(10.0, 36.0, k))
		_beam.width = beam_half_width * 2.0
		_beam.default_color = Color(1.0, 0.25, 0.2, flick * (0.6 + 0.6 * k))
		return
	if _beam_t - delta < beam_warn:
		SoundManager.play(SFX_BEAM, -4, 0.7)
		if enraged:
			_fire_bolts()  # and a fan of bolts to dodge into
	_beam.width = beam_half_width * 2.0
	_beam.default_color = Color(1.0, 0.55, 0.45, 0.95)
	# Ren's body is ~9 px wide: he's hit only if he overlaps the drawn beam
	if _hits_segment(_player.global_position + Vector2(0, -7), from, to, beam_half_width + 3.0):
		_player.die()
	if _beam_t >= beam_warn + beam_fire:
		_end_beam()

func _end_beam() -> void:
	_beam_t = -1.0
	_beam.visible = false
	if not _flushed and _sprite.animation == "attack":
		_sprite.play("idle")

## Where the beam stops: the first wall along it (echoes don't stop it).
func _beam_end(from: Vector2, dir: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(from, from + dir * beam_length, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.position if hit else from + dir * beam_length

func _hits_segment(p: Vector2, a: Vector2, b: Vector2, r: float) -> bool:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= r

func _fire_bolts() -> void:
	_sprite.play("other_attack")
	SoundManager.play(SFX_BOLTS, -8, 1.3)
	var from := global_position
	var target := _player.global_position + Vector2(0, -7)
	if _player is CharacterBody2D:
		# aim where Ren will be when the bolts get there
		var travel := from.distance_to(target) / bolt_speed
		target += (_player as CharacterBody2D).velocity * travel * 0.8
	var dir := (target - from).normalized()
	for i in bolt_count:
		var a := deg_to_rad(bolt_spread_deg * (i - (bolt_count - 1) / 2.0))
		_spawn_bolt(from + dir * 18.0, dir.rotated(a), bolt_speed)
	if enraged:
		# a second volley, offset to fill the gaps of the first
		await get_tree().create_timer(0.3, false).timeout
		if _flushed or _player == null or _player.get("is_dead"):
			return
		for i in bolt_count - 1:
			var a := deg_to_rad(bolt_spread_deg * (i - (bolt_count - 2) / 2.0))
			_spawn_bolt(global_position + dir * 18.0, dir.rotated(a), bolt_speed * 1.1)

func _fire_ring() -> void:
	_sprite.play("other_attack")
	SoundManager.play(SFX_BOLTS, -6, 0.9)
	var start := randf() * TAU
	var count := ring_count * 3 / 2 if enraged else ring_count
	for i in count:
		var d := Vector2.RIGHT.rotated(start + TAU * i / count)
		_spawn_bolt(global_position + d * 18.0, d, bolt_speed * 0.7)

func _spawn_bolt(at: Vector2, dir: Vector2, speed: float) -> void:
	var bolt := Area2D.new()
	bolt.set_script(BoltScript)
	get_parent().add_child(bolt)
	bolt.global_position = at
	bolt.launch(dir, speed)

func _cancel_attacks() -> void:
	_end_beam()
	for b in get_tree().get_nodes_in_group("eye_bolt"):
		b.queue_free()
	if not _flushed and _sprite.animation in ["attack", "other_attack"]:
		_sprite.play("idle")

func _in_rock(p: Vector2) -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = p
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()

func _on_anim_finished() -> void:
	if _sprite.animation in ["attack", "other_attack"] and not _flushed:
		_sprite.play("idle")

# ── Enrage ────────────────────────────────────────────────────────────────────
func _enrage() -> void:
	enraged = true
	SoundManager.play(SFX_ENRAGE, 0.0, 0.6)
	SoundManager.play(SFX_WAKE, -2, 0.7)
	_cooldown = minf(_cooldown, 0.8)
	var tw := create_tween()
	tw.tween_property(_sprite, "scale", Vector2.ONE * sprite_scale * 1.25, 0.15)
	tw.tween_property(_sprite, "scale", Vector2.ONE * sprite_scale * 1.08, 0.35)

func _process(_delta: float) -> void:
	if not enraged or _flushed:
		return
	# a pulsing red glare and a shudder
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
	_sprite.modulate = Color(1.0 + 0.8 * pulse, 0.55 - 0.25 * pulse, 0.5 - 0.25 * pulse)
	_sprite.position = Vector2(randf_range(-1.2, 1.2), randf_range(-1.2, 1.2))
	queue_redraw()

func _draw() -> void:
	if not enraged or _flushed:
		return
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 9.0)
	var r := 40.0 * _sprite.scale.x / sprite_scale
	draw_circle(Vector2.ZERO, r + 10.0 + 6.0 * pulse, Color(1.0, 0.15, 0.1, 0.12 + 0.1 * pulse))
	draw_arc(Vector2.ZERO, r + 4.0 + 4.0 * pulse, 0.0, TAU, 40, Color(1.0, 0.3, 0.2, 0.5 * pulse), 2.0)

# ── Finale ────────────────────────────────────────────────────────────────────
## The torrent hits it: it reels back down the path, breaks apart and is gone.
func flush() -> void:
	if _flushed or is_dead:
		return
	_flushed = true
	_cancel_attacks()
	queue_redraw()
	_sprite.modulate = Color(1.0, 0.7, 0.7) if enraged else Color.WHITE
	_sprite.play("taking_damage")
	var back := maxf(0.0, offset - 260.0)
	var tw := create_tween()
	tw.tween_method(func(o: float) -> void:
		offset = o
		_place()
		_sprite.position = Vector2(randf_range(-2, 2), randf_range(-2, 2)), offset, back, 1.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw.finished
	_sprite.position = Vector2.ZERO
	SoundManager.play(SFX_DEFEAT, -4)
	_sprite.play("death")
	await _sprite.animation_finished
	is_dead = true
	defeated.emit()
	await create_tween().tween_property(self, "modulate:a", 0.0, 0.5).finished
	visible = false
