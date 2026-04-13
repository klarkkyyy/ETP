extends CharacterBody2D
const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const DOUBLE_JUMP_VELOCITY = -250.0
const WALL_SLIDE_GRAVITY = 40.0
const WALL_JUMP_VELOCITY_X = 200.0
const WALL_JUMP_VELOCITY_Y = -250.0

var can_double_jump = false
var is_dead = false
var was_on_floor = true
var is_wall_sliding = false
var wall_jump_timer = 0.0          # NEW: lockout timer
const WALL_JUMP_LOCKOUT = 0.15     # NEW: seconds to ignore horizontal input

@onready var anim = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# Tick down the wall jump lockout timer
	if wall_jump_timer > 0.0:
		wall_jump_timer -= delta

	# Wall slide check
	is_wall_sliding = false
	if is_on_wall() and not is_on_floor() and velocity.y >= 0:   # CHANGED: added velocity.y >= 0
		var direction = Input.get_axis("left", "right")
		if (direction > 0 and get_wall_normal().x < 0) or (direction < 0 and get_wall_normal().x > 0):
			is_wall_sliding = true

	# Gravity
	if not is_on_floor():
		if is_wall_sliding:
			velocity.y += WALL_SLIDE_GRAVITY * delta
			velocity.y = min(velocity.y, 60.0)
		else:
			velocity += get_gravity() * delta

	# Jump / Double Jump / Wall Jump
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true              # only granted here
			anim.play("before_or_after_jump")
		elif is_wall_sliding:
			velocity.y = WALL_JUMP_VELOCITY_Y
			velocity.x = get_wall_normal().x * WALL_JUMP_VELOCITY_X
			wall_jump_timer = WALL_JUMP_LOCKOUT
			# can_double_jump intentionally NOT touched here
			is_wall_sliding = false
			anim.play("before_or_after_jump")
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			anim.play("double_jump")

	# Horizontal movement — skipped during wall jump lockout
	var direction := Input.get_axis("left", "right")
	if wall_jump_timer <= 0.0:
		if direction:
			velocity.x = direction * SPEED
			anim.flip_h = direction < 0
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
	# (if locked out, velocity.x keeps its wall-jump value)

	# Landing detection
	var on_floor_now = is_on_floor()
	if on_floor_now and not was_on_floor:
		_on_landed()
	was_on_floor = on_floor_now

	move_and_slide()
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
			anim.play("wall_slide")                             # CHANGED
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
