extends CharacterBody2D

const OrbScene = preload("res://scenes/orb.tscn")

# ── Exports ───────────────────────────────────────────────────────────────────
@export var speed: float                 = 70.0
@export var run_speed: float             = 140.0
@export var gravity: float               = 900.0
@export var idle_time_min: float         = 0.8
@export var idle_time_max: float         = 2.2
@export var walk_time_min: float         = 2.0
@export var walk_time_max: float         = 4.0
@export var max_health: float            = 100.0
@export var attack_cooldown: float       = 2.5
@export var orb_speed: float             = 200.0
@export var orb_damage: float            = 15.0
@export var teleport_interval_min: float = 7.0
@export var teleport_interval_max: float = 14.0
@export var enrage_threshold: float      = 0.35
@export var teleport_zone: NodePath  # kept for compatibility but unused
var _current_target: Node2D = null

# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, MOVING, RUNNING, HIT, ATTACK_ORB, TELEPORTING, EMERGING, DEAD }

# Sub-steps for multi-phase states (teleport has 3 phases)
enum TeleportPhase { VANISH, HIDDEN, EMERGE }

# ── Runtime ───────────────────────────────────────────────────────────────────
var current_health: float    = 0.0
var current_state: State     = State.IDLE
var direction: int           = 1
var is_dead: bool            = false
var is_enraged: bool         = false

var state_timer: float       = 0.0   # wander / hit duration
var attack_timer: float      = 0.0   # cooldown between orb attacks
var spawn_immunity: float    = 1.5   # ignore damage for this many seconds on spawn
var teleport_timer: float    = 0.0   # cooldown between teleports
var phase_timer: float       = 0.0   # duration of current locked phase
var teleport_phase: TeleportPhase = TeleportPhase.VANISH

var player: Node              = null
var _teleport_areas: Array    = []

# How long each one-shot animation lasts (seconds). Tune to match your sprite.
const ANIM_ATTACK_DUR  : float = 0.6
const ANIM_HIT_DUR     : float = 0.4
const ANIM_VANISH_DUR  : float = 0.4
const ANIM_HIDDEN_DUR  : float = 0.25
const ANIM_EMERGE_DUR  : float = 0.7

@onready var sprite         : AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_detector  : RayCast2D        = $WallDetector
@onready var ledge_detector : RayCast2D        = $LedgeDetector
@onready var health_bar                        = $BossHealthBar

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	current_health = max_health
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value     = current_health

	wall_detector.add_exception(self)
	ledge_detector.add_exception(self)

	# Configure wall detector via script
	wall_detector.target_position = Vector2(30, 0)
	wall_detector.collision_mask  = 1
	wall_detector.enabled         = true

	player = get_tree().get_first_node_in_group("player")

	# Collect all teleport zones by name under the boss's parent
	var zone_names := ["boss_tp", "boss_tp2", "boss_tp3", "boss_tp5", "boss_tp6"]
	for zname in zone_names:
		var z := get_parent().get_node_or_null(zname)
		if z:
			_teleport_areas.append(z)
	# Also grab any node in group as fallback
	for z in get_tree().get_nodes_in_group("boss_teleport_zone"):
		if not _teleport_areas.has(z):
			_teleport_areas.append(z)

	# Delay first attack so boss walks around first
	attack_timer   = attack_cooldown + randf_range(1.5, 3.0)
	spawn_immunity = 1.5
	teleport_timer = randf_range(teleport_interval_min, teleport_interval_max)

	_set_wander_state(State.MOVING)

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if spawn_immunity > 0.0:
		spawn_immunity -= delta

	if not is_on_floor():
		velocity.y += gravity * delta

	match current_state:
		State.IDLE, State.MOVING, State.RUNNING:
			_tick_wander(delta)

		State.HIT:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_set_wander_state(State.MOVING)

		State.ATTACK_ORB:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_fire_orb()
				if is_enraged:
					_fire_orb(15.0)
				# Full cooldown so boss wanders before attacking again
				attack_timer   = attack_cooldown + randf_range(0.5, 1.5)
				teleport_timer = maxf(teleport_timer, 3.0)
				_set_wander_state(State.MOVING if not is_enraged else State.RUNNING)

		State.TELEPORTING:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_teleport_next_phase()

		State.EMERGING:
			phase_timer -= delta
			if phase_timer <= 0.0:
				_on_before_emerging_finished()
				attack_timer   = attack_cooldown + randf_range(1.0, 2.5)
				teleport_timer = randf_range(teleport_interval_min, teleport_interval_max)
				_set_wander_state(State.MOVING if not is_enraged else State.RUNNING)

	move_and_slide()
	_update_animation()

# ── Wander tick (only runs during IDLE / MOVING / RUNNING) ───────────────────
func _tick_wander(delta: float) -> void:
	# State duration
	state_timer -= delta
	if state_timer <= 0.0:
		_pick_random_state()
		return

	# Attack
	attack_timer -= delta
	if attack_timer <= 0.0:
		attack_timer = attack_cooldown if not is_enraged else attack_cooldown * 0.6
		_start_attack()
		return

	# Teleport
	teleport_timer -= delta
	if teleport_timer <= 0.0:
		teleport_timer = randf_range(teleport_interval_min, teleport_interval_max)
		_start_teleport()
		return

	_apply_movement()

# ── State setters ─────────────────────────────────────────────────────────────
func _set_wander_state(s: State) -> void:
	current_state = s
	match s:
		State.IDLE:
			velocity.x  = 0.0
			state_timer = randf_range(idle_time_min, idle_time_max)
		State.MOVING:
			_pick_direction()
			state_timer = randf_range(walk_time_min, walk_time_max)
		State.RUNNING:
			_pick_direction(true)
			state_timer = randf_range(1.2, 2.8)

func _pick_random_state() -> void:
	if is_enraged:
		# Enraged: mix of running and walking, rarely idle
		var r := randf()
		if r < 0.55:
			_set_wander_state(State.RUNNING)
		elif r < 0.80:
			_set_wander_state(State.MOVING)
		else:
			_set_wander_state(State.IDLE)
	else:
		# Normal: mostly walking, sometimes idle, sometimes flip direction
		var r := randf()
		if r < 0.50:
			_set_wander_state(State.MOVING)
		elif r < 0.75:
			_set_wander_state(State.IDLE)
		else:
			direction     *= -1
			sprite.flip_h  = (direction == -1)
			_set_wander_state(State.MOVING)

# ── Movement ──────────────────────────────────────────────────────────────────
func _apply_movement() -> void:
	match current_state:
		State.MOVING:
			if wall_detector.is_colliding():
				_flip()
			velocity.x = direction * speed
		State.RUNNING:
			if wall_detector.is_colliding():
				_flip()
			velocity.x = direction * run_speed
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, speed)

func _pick_direction(toward_player: bool = false) -> void:
	if (toward_player or randf() < 0.65) and player:
		var dx: float = player.global_position.x - global_position.x
		direction = 1 if dx >= 0.0 else -1
	else:
		direction = 1 if randf() < 0.5 else -1
	sprite.flip_h = (direction == -1)

func _flip() -> void:
	direction                        *= -1
	wall_detector.target_position.x  = abs(wall_detector.target_position.x) * direction
	sprite.flip_h                     = (direction == -1)

func _face_player() -> void:
	if not player:
		return
	var dx: float = player.global_position.x - global_position.x
	direction     = 1 if dx >= 0.0 else -1
	sprite.flip_h = (direction == -1)

# ── Animations ────────────────────────────────────────────────────────────────
func _update_animation() -> void:
	match current_state:
		State.IDLE:
			sprite.play("Idle")
		State.MOVING:
			sprite.play("Moving Right" if direction == 1 else "Moving_Left")
		State.RUNNING:
			sprite.play("run_right" if direction == 1 else "run_left")
		# All other states play their anim when the state is entered; don't override here

# ── Attack ────────────────────────────────────────────────────────────────────
func _start_attack() -> void:
	current_state = State.ATTACK_ORB
	velocity      = Vector2.ZERO
	_face_player()
	sprite.play("attack_left" if direction == -1 else "attack_right")
	phase_timer   = ANIM_ATTACK_DUR

func _fire_orb(angle_offset_deg: float = 0.0) -> void:
	if not player:
		return
	var base_dir: Vector2 = (player.global_position - global_position).normalized()
	var dir: Vector2      = base_dir.rotated(deg_to_rad(angle_offset_deg))
	var orb               := OrbScene.instantiate()
	get_parent().add_child(orb)
	orb.global_position = global_position
	orb.launch(dir, orb_speed, orb_damage)

# ── Teleport ──────────────────────────────────────────────────────────────────
func _start_teleport() -> void:
	current_state   = State.TELEPORTING
	teleport_phase  = TeleportPhase.VANISH
	velocity        = Vector2.ZERO
	sprite.play("Boss_Hit")   # vanish flash
	phase_timer     = ANIM_VANISH_DUR

func _teleport_next_phase() -> void:
	match teleport_phase:
		TeleportPhase.VANISH:
			# Hide and wait briefly
			sprite.visible = false
			teleport_phase = TeleportPhase.HIDDEN
			phase_timer    = ANIM_HIDDEN_DUR

		TeleportPhase.HIDDEN:
			# Warp to destination, show emerge animation
			global_position = _random_point_in_zone()
			sprite.visible  = true
			sprite.play("before_emerging")
			current_state   = State.EMERGING
			phase_timer     = ANIM_EMERGE_DUR

func _random_point_in_zone() -> Vector2:
	if _teleport_areas.is_empty():
		return global_position + Vector2(randf_range(-220.0, 220.0), 0.0)

	# Pick a random zone, avoid repeating the same one if possible
	var zone: Node = _teleport_areas[randi() % _teleport_areas.size()]
	return _center_of_zone(zone)

func _center_of_zone(zone: Node) -> Vector2:
	var shape_node := zone.get_node_or_null("CollisionShape2D")
	if not shape_node:
		return zone.global_position

	var cs := shape_node as CollisionShape2D
	if not cs or not cs.shape:
		return zone.global_position

	var ext: Vector2 = Vector2(40.0, 0.0)
	if cs.shape is RectangleShape2D:
		ext = (cs.shape as RectangleShape2D).size * 0.5

	return zone.global_position + Vector2(randf_range(-ext.x, ext.x), 0.0)

# ── Damage & death ────────────────────────────────────────────────────────────
func take_damage(amount: float) -> void:
	if is_dead or current_state == State.HIT or spawn_immunity > 0.0:
		return
	print("Boss take_damage: ", amount, " | caller: ", get_stack())

	current_health -= amount
	if health_bar:
		health_bar.value = current_health

	if not is_enraged and current_health / max_health <= enrage_threshold:
		_enter_enrage()

	if current_health <= 0.0:
		die()
	else:
		current_state = State.HIT
		velocity      = Vector2.ZERO
		sprite.play("Boss_Hit")
		phase_timer   = ANIM_HIT_DUR

func _enter_enrage() -> void:
	is_enraged      = true
	attack_cooldown = 1.2
	orb_speed       = 270.0
	_set_wander_state(State.RUNNING)

func die() -> void:
	if is_dead:
		return
	is_dead         = true
	current_state   = State.DEAD
	velocity        = Vector2.ZERO
	sprite.visible  = true
	sprite.play("Dead")
	collision_layer = 0
	collision_mask  = 0
	if health_bar:
		health_bar.hide()
	await get_tree().create_timer(1.8).timeout
	queue_free()
	
# boss.gd

func _get_nearest_target() -> Node2D:
	var candidates: Array = []
	
	# Gather all echoes
	var echoes = get_tree().get_nodes_in_group("echo")
	for echo in echoes:
		if is_instance_valid(echo):
			candidates.append(echo)
	
	# Also consider the player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		candidates.append(player)
	
	# Find nearest
	var nearest: Node2D = null
	var nearest_dist: float = INF
	for c in candidates:
		var dist = global_position.distance_to(c.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = c
	
	return nearest

func _fire_orb_at(target: Node2D, angle_offset_deg: float = 0.0) -> void:
	if not target:
		return
	var base_dir: Vector2 = (target.global_position - global_position).normalized()
	var dir: Vector2 = base_dir.rotated(deg_to_rad(angle_offset_deg))
	var orb := OrbScene.instantiate()
	get_parent().add_child(orb)
	orb.global_position = global_position
	orb.launch(dir, orb_speed, orb_damage)

func _on_before_emerging_finished() -> void:
	var target = _get_nearest_target()
	if target and target.is_in_group("echo"):
		print("Boss targeted echo — player has free window!")
		_current_target = target
		_fire_orb_at(target)
	else:
		_current_target = player
