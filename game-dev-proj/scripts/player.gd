extends CharacterBody2D
const SPEED = 100.0
const JUMP_VELOCITY = -300.0
const DOUBLE_JUMP_VELOCITY = -250.0
var can_double_jump = false
var is_dead = false
var was_on_floor = true  # ← added
@onready var anim = $AnimatedSprite2D

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			anim.play("before_or_after_jump")
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			anim.play("double_jump")

	var on_floor_now = is_on_floor()  # ← moved here
	if on_floor_now and not was_on_floor:
		_on_landed()
	was_on_floor = on_floor_now

	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		anim.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
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
		if anim.animation == "double_jump" and anim.is_playing():
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
	if Input.get_axis("left", "right") != 0 and is_on_wall():
		anim.play("push_forward")
