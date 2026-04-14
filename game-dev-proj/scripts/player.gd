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
const AfterJumpDust = preload("res://effects/after_jump_dust.tscn")    
const BeforeJumpDust = preload("res://effects/before_jump_dust.tscn")  
const RunDust = preload("res://effects/run.tscn")
const StopDust = preload("res://effects/stop.tscn")
const DoubleJumpDust = preload("res://effects/double_jump.tscn")
const WallJumpDust = preload("res://effects/wall_jump.tscn")

var can_double_jump = false
var is_dead = false
var was_on_floor = true
var is_wall_sliding = false
var wall_jump_timer = 0.0                                
var run_dust_timer = 0

var was_running = false

func _ready():
	print("run_point_left: ", run_point_left)
	print("run_point_right: ", run_point_right)

func spawn_effect(scene: PackedScene, point: Marker2D = feet_point):
	var effect = scene.instantiate()
	get_parent().add_child(effect)
	effect.global_position = point.global_position
	effect.scale.x = -1 if anim.flip_h else 1

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if wall_jump_timer > 0.0:
		wall_jump_timer -= delta
	is_wall_sliding = false
	if is_on_wall() and not is_on_floor() and velocity.y >= 0:
		var direction = Input.get_axis("left", "right")
		if (direction > 0 and get_wall_normal().x < 0) or (direction < 0 and get_wall_normal().x > 0):
			is_wall_sliding = true
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y += WALL_SLIDE_GRAVITY * delta
			velocity.y = min(velocity.y, 60.0)
		else:
			velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			spawn_effect(AfterJumpDust)
			anim.play("before_or_after_jump")
		elif is_wall_sliding:
			velocity.y = WALL_JUMP_VELOCITY_Y
			velocity.x = get_wall_normal().x * WALL_JUMP_VELOCITY_X
			wall_jump_timer = WALL_JUMP_LOCKOUT
			is_wall_sliding = false
			anim.flip_h = get_wall_normal().x < 0
			spawn_effect(WallJumpDust)          # ← added
			anim.play("before_or_after_jump")
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			spawn_effect(DoubleJumpDust)        # ← added
			anim.play("double_jump")
	var direction := Input.get_axis("left", "right")
	if wall_jump_timer <= 0.0:
		if direction:
			velocity.x = direction * SPEED
			anim.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	var on_floor_now = is_on_floor()
	if on_floor_now and not was_on_floor:
		_on_landed()
	was_on_floor = on_floor_now
	move_and_slide()

	# Run dust
	var move_dir := Input.get_axis("left", "right")
	if is_on_floor() and abs(move_dir) > 0:
		run_dust_timer -= delta
		if run_dust_timer <= 0.0:
			spawn_effect(RunDust, run_point_left if not anim.flip_h else run_point_right)
			run_dust_timer = RUN_DUST_INTERVAL
		was_running = true
	else:
		run_dust_timer = RUN_DUST_INTERVAL  # ← reset to interval, not 0
		if was_running and is_on_floor():
			spawn_effect(StopDust, run_point_left if not anim.flip_h else run_point_right)
		was_running = false
	update_animation()

func update_animation():
	if is_on_floor():
		var direction = Input.get_axis("left", "right")
		if direction != 0:
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

func _on_landed():
	spawn_effect(BeforeJumpDust)                                        # ADDED
	anim.play("before_or_after_jump_pt2")
	await anim.animation_finished
	anim.play("before_or_after_jump")

func take_hit():
	anim.play("hit")
	await anim.animation_finished
	anim.play("idle")

func die():
	if is_dead:
		return
	is_dead = true
	velocity = Vector2.ZERO
	anim.play("death")
	await anim.animation_finished

func _process(_delta):
	if is_dead:
		return
