#player.gd
extends CharacterBody2D

@onready var anim = $animations
@onready var feet_point = $FeetPoint 
@onready var run_point_left = $RunPointLeft
@onready var run_point_right = $RunPointRight

const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const DOUBLE_JUMP_VELOCITY = -250.0
const WALL_SLIDE_GRAVITY = 40.0
const WALL_JUMP_VELOCITY_X = 200.0
const WALL_JUMP_VELOCITY_Y = -250.0
const WALL_JUMP_LOCKOUT = 0.15
const RUN_DUST_INTERVAL = 0.15
const JUMP_BUFFER_TIME = 0.1

const AfterJumpDust = preload("res://effects/after_jump_dust.tscn")
const BeforeJumpDust = preload("res://effects/before_jump_dust.tscn")
const RunDust = preload("res://effects/run.tscn")
const StopDust = preload("res://effects/stop.tscn")
const DoubleJumpDust = preload("res://effects/double_jump.tscn")
const WallJumpDust = preload("res://effects/wall_jump.tscn")

var can_double_jump: bool = false
var is_dead: bool = false
var was_on_floor: bool = true
var is_wall_sliding: bool = false
var is_pushing: bool = false
var wall_jump_timer: float = 0.0
var run_dust_timer: float = 0.0
var was_running: bool = false
var current_echo_zone: Node = null
var _jump_buffer_timer: float = 0.0

func _ready() -> void:
	print("run_point_left: ", run_point_left)
	print("run_point_right: ", run_point_right)

func spawn_effect(scene: PackedScene, point: Marker2D = feet_point) -> void:
	var effect = scene.instantiate()
	get_parent().add_child(effect)
	effect.global_position = point.global_position
	effect.scale.x = -1 if anim.flip_h else 1

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if Input.is_action_pressed("respawn"):
		_respawn()
	if wall_jump_timer > 0.0:
		wall_jump_timer -= delta

	if is_on_floor():
		can_double_jump = false
	else:
		if was_on_floor and not is_on_floor():
			can_double_jump = true

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = JUMP_BUFFER_TIME
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	is_wall_sliding = false
	if is_on_wall() and not is_on_floor() and velocity.y > 20.0:
		var wall_dir = Input.get_axis("left", "right")
		if (wall_dir > 0 and get_wall_normal().x < 0) or (wall_dir < 0 and get_wall_normal().x > 0):
			is_wall_sliding = true

	# Detect push: on floor, pressing into a wall or moveable object, not wall sliding
	is_pushing = false
	var push_dir = Input.get_axis("left", "right")
	if is_on_floor() and not is_wall_sliding and push_dir != 0:
		# Case 1: pressing into a static wall
		if is_on_wall():
			var wall_normal = get_wall_normal()
			if (push_dir > 0 and wall_normal.x < 0) or (push_dir < 0 and wall_normal.x > 0):
				is_pushing = true
				anim.flip_h = push_dir < 0
		if not is_pushing:
			for i in get_slide_collision_count():
				var col = get_slide_collision(i)
				var collider = col.get_collider()
				if is_instance_valid(collider) and collider.is_in_group("moveable"):
					var to_collider = (collider.global_position - global_position).normalized()
					if (push_dir > 0 and to_collider.x > 0.3) or (push_dir < 0 and to_collider.x < -0.3):
						is_pushing = true
						anim.flip_h = push_dir < 0
						if collider.has_method("receive_push"):
							collider.receive_push(push_dir)
						break

	if not is_on_floor():
		if is_wall_sliding:
			velocity.y += WALL_SLIDE_GRAVITY * delta
			velocity.y = min(velocity.y, 60.0)
		else:
			velocity += get_gravity() * delta

	if _jump_buffer_timer > 0.0:
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			_jump_buffer_timer = 0.0
			spawn_effect(AfterJumpDust)
			anim.play("before_or_after_jump")
		elif is_wall_sliding:
			velocity.y = WALL_JUMP_VELOCITY_Y
			velocity.x = get_wall_normal().x * WALL_JUMP_VELOCITY_X
			wall_jump_timer = WALL_JUMP_LOCKOUT
			is_wall_sliding = false
			anim.flip_h = get_wall_normal().x < 0
			_jump_buffer_timer = 0.0
			spawn_effect(WallJumpDust)
			anim.play("before_or_after_jump")
		elif can_double_jump:
			print("double jump triggered | vel.y: ", velocity.y, " | can_double: ", can_double_jump)
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			_jump_buffer_timer = 0.0
			spawn_effect(DoubleJumpDust)
			anim.play("double_jump")

	var direction := Input.get_axis("left", "right")
	if wall_jump_timer <= 0.0:
		if direction:
			velocity.x = direction * SPEED
			# Only update flip from movement when not pushing (push sets its own flip)
			if not is_pushing:
				anim.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	var on_floor_now = is_on_floor()
	if on_floor_now and not was_on_floor:
		_on_landed()
	was_on_floor = on_floor_now

	if is_on_floor() and _jump_buffer_timer <= 0.0:
		floor_snap_length = 10.0
	else:
		floor_snap_length = 0.0
	floor_max_angle = deg_to_rad(50.0)
	move_and_slide()

	var move_dir := Input.get_axis("left", "right")
	if is_on_floor() and abs(move_dir) > 0 and not is_pushing:
		run_dust_timer -= delta
		if run_dust_timer <= 0.0:
			spawn_effect(RunDust, run_point_left if not anim.flip_h else run_point_right)
			run_dust_timer = RUN_DUST_INTERVAL
		was_running = true
	else:
		run_dust_timer = RUN_DUST_INTERVAL
		if was_running and is_on_floor():
			spawn_effect(StopDust, run_point_left if not anim.flip_h else run_point_right)
		was_running = false
	update_animation()

func update_animation() -> void:
	if is_on_floor():
		# Push animation takes priority over run/idle
		if is_pushing:
			if anim.animation != "push_forward":
				anim.play("push_forward")
			return
		var move = Input.get_axis("left", "right")
		if move != 0:
			anim.play("run")
		else:
			anim.play("idle")
	else:
		if is_wall_sliding:
			anim.play("wall_slide")
		elif anim.animation == "double_jump" and anim.is_playing():
			pass
		elif anim.animation == "before_or_after_jump" and anim.is_playing():
			pass
		elif anim.animation == "before_or_after_jump" and not anim.is_playing():
			anim.play("before_or_after_jump_pt2")
		elif anim.animation == "before_or_after_jump_pt2" and anim.is_playing():
			pass
		elif velocity.y < 0:
			if anim.animation != "jump_up":
				anim.play("jump_up")
		elif velocity.y > 0:
			if anim.animation != "jump_down":
				anim.play("jump_down")

func _on_landed() -> void:
	spawn_effect(BeforeJumpDust)
	anim.play("before_or_after_jump_pt2")
	await anim.animation_finished
	anim.play("before_or_after_jump")

func take_hit() -> void:
	anim.play("hit")
	await anim.animation_finished
	anim.play("idle")

func die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	if current_echo_zone:
		current_echo_zone.stop_recording()
		current_echo_zone.player = null
		current_echo_zone = null
	anim.play("death")
	await anim.animation_finished
	_respawn()

func _respawn() -> void:
	is_dead = false
	set_physics_process(true)
	global_position = GameManager.get_respawn_position()
	anim.play("idle")

func _clear_all_echoes() -> void:
	pass

func _process(_delta: float) -> void:
	if is_dead:
		return

func set_echo_zone(zone) -> void:
	current_echo_zone = zone
