# overseer.gd — the Overseer, the floating mechanical eye that chases Ren
# through the boss 2 level. It can't be fought: it follows `path` (a Path2D
# laid along the level's route) straight through the rock, and touching it
# kills. It drifts at the speed `speed_marks` sets for that stretch of the
# path, and races to catch up when Ren gets more than `lead` ahead, so it is
# never far behind. When Ren respawns it reappears `respawn_gap` behind him
# and waits `respawn_grace` seconds.
# Two attacks, only while it hangs in open air and Ren is in range:
#   beam  — a warning line locked on where Ren stood, then a ray that stops at
#           walls but passes through echoes;
#   bolts — a spread of eye bolts (eye_bolt.gd) that walls and echoes stop.
# Attacks come faster the further along the path Ren gets. flush() is the
# finale: the torrent from the last floodgate washes it back down the path.
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

@export var path: NodePath
@export var base_speed: float = 58.0        # px/s along the path, where no speed mark applies
## (offset along the path, speed from there on), sorted by offset
@export var speed_marks: PackedVector2Array = PackedVector2Array()
@export var catch_up_speed: float = 170.0
@export var lead: float = 380.0             # Ren this far ahead along the path: it races to catch up
@export var kill_radius: float = 42.0         # the shell, ~90 px across at sprite_scale 1.5
@export var respawn_gap: float = 320.0
@export var respawn_grace: float = 1.6
@export var sprite_scale: float = 1.5

@export_group("Attacks")
@export var attack_range: float = 300.0
@export var beam_length: float = 640.0
@export var beam_warn: float = 0.85
@export var beam_fire: float = 0.3
@export var beam_half_width: float = 6.0
@export var bolt_speed: float = 135.0
@export var bolt_count: int = 3
@export var bolt_spread_deg: float = 14.0
## seconds between attacks at the start of the path and at its end
@export var cooldown_start: float = 3.2
@export var cooldown_end: float = 1.6

var is_dead := false
var awake := false
var offset := 0.0                           # the eye's distance along the path

var _path: Path2D
var _curve: Curve2D
var _player: Node2D
var _player_offset := 0.0
var _player_was_dead := false
var _wait := 0.0
var _cooldown := 2.0
var _flushed := false
var _sprite: AnimatedSprite2D
var _beam: Line2D
var _beam_dir := Vector2.ZERO
var _beam_t := -1.0                          # time into the current beam, -1: none
var _bob := 0.0

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

## Starts the chase (connect a trigger to this). Safe to call more than once.
func wake() -> void:
	if awake or is_dead or _curve == null:
		return
	awake = true
	_player = get_tree().get_first_node_in_group("player") as Node2D
	offset = 0.0
	_place()
	visible = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.8)
	_sprite.play("idle")
	_wait = 1.2
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
	if _wait > 0.0:
		_wait -= delta
	else:
		_move(delta)
	_place()
	if global_position.distance_to(_player.global_position + Vector2(0, -7)) < kill_radius:
		_player.die()
		return
	_attack(delta)

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
		speed = lerpf(speed, catch_up_speed, clampf((ahead - lead) / 200.0, 0.0, 1.0))
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
	return s

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
	_wait = respawn_grace + maxf(0.0, respawn_gap - _player_offset) / _speed_at(0.0)
	_cooldown = maxf(_cooldown, respawn_grace + 1.0)
	_place()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

# ── Attacks ───────────────────────────────────────────────────────────────────
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
	var t := clampf(offset / _curve.get_baked_length(), 0.0, 1.0)
	_cooldown = lerpf(cooldown_start, cooldown_end, t) * randf_range(0.85, 1.15)
	if randf() < 0.5:
		_start_beam(to_player.normalized())
	else:
		_fire_bolts(to_player.normalized())

func _start_beam(dir: Vector2) -> void:
	_beam_dir = dir
	_beam_t = 0.0
	_sprite.play("attack")
	_beam.visible = true

func _run_beam(delta: float) -> void:
	_beam_t += delta
	var from := global_position
	var to := _beam_end(from)
	_beam.points = PackedVector2Array([from, to])
	if _beam_t < beam_warn:
		# the warning: a thin line that flickers faster as it's about to fire
		var flick := 0.7 + 0.25 * sin(_beam_t * lerpf(14.0, 40.0, _beam_t / beam_warn))
		_beam.width = 2.0
		_beam.default_color = Color(1.0, 0.25, 0.2, flick)
		return
	if _beam_t - delta < beam_warn:
		SoundManager.play(SFX_BEAM, -4, 0.7)
	_beam.width = beam_half_width * 2.0
	_beam.default_color = Color(1.0, 0.55, 0.45, 0.95)
	if _hits_segment(_player.global_position + Vector2(0, -7), from, to, beam_half_width + 4.0):
		_player.die()
	if _beam_t >= beam_warn + beam_fire:
		_cancel_attacks()

## Where the beam stops: the first wall along it (echoes don't stop it).
func _beam_end(from: Vector2) -> Vector2:
	var q := PhysicsRayQueryParameters2D.create(from, from + _beam_dir * beam_length, 1)
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	return hit.position if hit else from + _beam_dir * beam_length

func _hits_segment(p: Vector2, a: Vector2, b: Vector2, r: float) -> bool:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) <= r

func _fire_bolts(dir: Vector2) -> void:
	_sprite.play("other_attack")
	SoundManager.play(SFX_BOLTS, -8, 1.3)
	for i in bolt_count:
		var a := deg_to_rad(bolt_spread_deg * (i - (bolt_count - 1) / 2.0))
		var bolt := Area2D.new()
		bolt.set_script(BoltScript)
		get_parent().add_child(bolt)
		bolt.global_position = global_position + dir * 20.0
		bolt.launch(dir.rotated(a), bolt_speed)

func _cancel_attacks() -> void:
	_beam_t = -1.0
	_beam.visible = false
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

# ── Finale ────────────────────────────────────────────────────────────────────
## The torrent hits it: it reels back down the path, breaks apart and is gone.
func flush() -> void:
	if _flushed or is_dead:
		return
	_flushed = true
	_cancel_attacks()
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
