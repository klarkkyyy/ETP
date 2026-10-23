#echo.gd
# Replays a recording of Ren. With solid echoes (Echoes.solid) it's a body in
# the level: Ren can't walk through it, it waits when he's in its way, and he
# can push it like a crate. Pushing shifts its whole replay; once pushed it has
# weight and falls off ledges (an echo never pushed replays exactly, so it can
# still re-enact rides on moving platforms).
extends Area2D

@onready var anim: AnimatedSprite2D = $animations  
@export var push_force: float = 180.0

const MAX_PUSH_STEP = 4.0   # px per frame; Ren runs ~1.7, a wall jump ~3.3
const PUSHED_SPEED = 60.0   # px/s when Ren pushes an echo
const GRAVITY = 980.0       # Ren's
const MAX_FALL = 500.0
const STEP_UP = 6.0         # a pushed echo walks up a ledge this high
const CRATE_HALF = 8.0      # half the width of a crate (box.tscn)
const ECHO_HALF = 4.5       # half the width of Ren's body
const TRAIL_LENGTH = 8
const TRAIL_INTERVAL = 3     
const SLOT_COLORS = [
	Color(0.4, 0.8, 1.0), 
	Color(0.7, 0.3, 1.0), 
	Color(0.2, 0.2, 0.2),  
]

var _last_echo_pos: Vector2 = Vector2.ZERO
var _frames: Array = []         
var _current_frame: int = 0
var _is_active: bool = true    
var _trail_nodes: Array = []
var _trail_counter: int = 0
var _slot_color: Color = SLOT_COLORS[0]
var _can_absorb_orb: bool = true
var _ghost: bool = true         # body off while it would overlap Ren (a replay can't be blocked)
var _dying: bool = false
var _offset: Vector2 = Vector2.ZERO   # how far Ren has pushed it (and it has fallen)
var _pushed: bool = false
var _fall_v: float = 0.0
@onready var _body_shape: CollisionShape2D = $EchoPlatform/CollisionShape2D

func setup(recorded_frames: Array, use_distance_check: bool, slot: int = 0) -> void:
	_frames = recorded_frames
	_current_frame = 0
	_last_echo_pos = recorded_frames[0]["pos"] if recorded_frames.size() > 0 else Vector2.ZERO
	_is_active = not use_distance_check
	_slot_color = SLOT_COLORS[clamp(slot, 0, SLOT_COLORS.size() - 1)]
	call_deferred("_setup_trail")
	_update_visuals()

func set_active(active: bool) -> void:
	if _is_active == active or _dying:
		return
	_is_active = active
	if not active:
		_set_ghost(true)
	_update_visuals()

var _interactables: Array = [] 

func _physics_process(_delta: float) -> void:
	if not _is_active or _frames.size() == 0:
		return
	# Move the echo's physical platform with it
	if $EchoPlatform:
		$EchoPlatform.global_position = global_position
		
	_trail_counter += 1
	if _trail_counter >= TRAIL_INTERVAL:
		_trail_counter = 0
		_update_trail()

	var frame_data = _frames[_current_frame]
	var offset_before := _offset
	var target: Vector2 = frame_data["pos"] + _offset
	if Echoes.solid == Echoes.Solid.FULL:
		var push := _push_from_player(_delta)
		_offset.x += push
		target.x += push
		if _pushed:
			target = _settle(target, frame_data, _delta)
			if _blocked_at(target):
				# its replay walks into a wall: stop at the wall, as Ren would,
				# and keep replaying from there
				var dx := target.x - global_position.x
				var at_wall := Vector2(global_position.x + signf(dx) * _free_distance(global_position, Vector2(dx, 0)), target.y)
				if _blocked_at(at_wall):
					global_position += _offset - offset_before
					return
				_offset.x += at_wall.x - target.x
				target = at_wall
	if Echoes.solid != Echoes.Solid.OFF:
		# Ren in the way, or about to be: wait for him to move, as he has to for
		# the echo. (Ren riding on its head goes up with it.) Only an echo that's
		# really inside him (spawned on him) is a ghost; a brushing overlap from
		# a head-on run stays solid so Ren is pushed back out on his own side.
		if _hits_player(target) and not _carrying_player():
			_set_ghost(_inside_player(), false)
			global_position += _offset - offset_before   # still give way to a push, and fall
			return
		_set_ghost(_current_frame == 0, false)   # the loop jumping back sweeps nothing along
	global_position = target
	if anim:
		anim.flip_h = frame_data["flip_h"]
		_update_echo_animation(frame_data)

	if frame_data.get("interact", false):
		for area in _interactables:
			if is_instance_valid(area) and area.has_method("on_echo_interact"):
				area.on_echo_interact(self)

	_current_frame = (_current_frame + 1) % _frames.size()
	# Push crates the echo walks into, the way Ren pushed them while recording.
	# A bigger step than a run frame is the loop starting over, not a push.
	var move_delta = global_position - _last_echo_pos
	if absf(move_delta.x) >= 0.5 and absf(move_delta.x) < MAX_PUSH_STEP:
		var dir := signf(move_delta.x)
		for body in get_tree().get_nodes_in_group("moveable"):
			if not is_instance_valid(body):
				continue
			if body.has_method("receive_push"):
				if _touching(body, dir):
					body.receive_push(dir)
			elif body is RigidBody2D and overlaps_body(body):
				body.apply_central_force(move_delta.normalized() * push_force)
	_last_echo_pos = global_position

## True when a crate is right against the echo's side in the direction it's moving.
func _touching(box: Node2D, dir: float) -> bool:
	var d := box.global_position - global_position
	return absf(d.y) < 12.0 and d.x * dir > 0.0 and absf(d.x) < CRATE_HALF + ECHO_HALF + 3.0

func _update_echo_animation(frame_data: Dictionary) -> void:
	if frame_data.has("anim"):
		anim.play(frame_data["anim"]) 
		return
	var prev_idx = (_current_frame - 1 + _frames.size()) % _frames.size()
	var prev_pos: Vector2 = _frames[prev_idx]["pos"]
	var delta_x = abs(frame_data["pos"].x - prev_pos.x)
	var delta_y = frame_data["pos"].y - prev_pos.y

	if delta_y < -1.5:
		anim.play("jump_up")
	elif delta_y > 1.5:
		anim.play("jump_down")
	elif delta_x > 0.5:
		anim.play("run")
	else:
		anim.play("idle")

func _update_trail() -> void:
	for i in range(TRAIL_LENGTH - 1, 0, -1):
		_trail_nodes[i].position = _trail_nodes[i - 1].position
		_trail_nodes[i].flip_h = _trail_nodes[i - 1].flip_h
		_trail_nodes[i].visible = _trail_nodes[i - 1].visible
		_trail_nodes[i].play(_trail_nodes[i - 1].animation) 
	_trail_nodes[0].position = Vector2.ZERO
	_trail_nodes[0].flip_h = anim.flip_h
	_trail_nodes[0].visible = _is_active
	_trail_nodes[0].play(anim.animation) 


func _update_visuals() -> void:
	if anim:
		anim.visible = false
	modulate = Color(_slot_color.r, _slot_color.g, _slot_color.b, 0.45) if _is_active else Color(1, 1, 1, 0)
	for trail in _trail_nodes:
		trail.visible = _is_active
signal echo_entered_pad(echo: Area2D)
signal echo_exited_pad(echo: Area2D)

func _ready() -> void:
	add_to_group("echo")
	if Echoes.solid != Echoes.Solid.OFF:
		_body_shape.one_way_collision = Echoes.solid == Echoes.Solid.TOP
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)



func _setup_trail() -> void:
	for t in _trail_nodes:
		t.queue_free()
	_trail_nodes.clear()

	if not anim or not anim.sprite_frames:
		return

	for i in range(TRAIL_LENGTH):
		var trail_sprite = AnimatedSprite2D.new()
		trail_sprite.sprite_frames = anim.sprite_frames
		trail_sprite.play("idle")
		var alpha = (1.0 - float(i) / TRAIL_LENGTH) * 0.18
		trail_sprite.modulate = Color(_slot_color.r, _slot_color.g, _slot_color.b, alpha)
		trail_sprite.z_index = -1
		add_child(trail_sprite)
		trail_sprite.visible = false
		_trail_nodes.append(trail_sprite)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("pressure_pad") or area.is_in_group("switch"):
		area.on_echo_enter(self)
	if area.is_in_group("lever"):
		_interactables.append(area)
	if area.is_in_group("orb") and _can_absorb_orb:
		_absorb_orb(area)
	emit_signal("echo_entered_pad", self)
	
func _absorb_orb(orb: Area2D) -> void:
	_can_absorb_orb = false
	orb.queue_free()
	die()

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("pressure_pad") or area.is_in_group("switch"):
		area.on_echo_exit(self)
	if area.is_in_group("lever"):
		_interactables.erase(area)
	emit_signal("echo_exited_pad", self)
	
## Solid echoes: the body Ren collides with goes off (true) or on (false).
## Deferred unless called from the echo's own physics step.
func _set_ghost(on: bool, deferred: bool = true) -> void:
	if _ghost == on:
		return
	_ghost = on
	if deferred:
		_body_shape.set_deferred("disabled", on)
	else:
		_body_shape.disabled = on

## Ren walking into its side on the same floor pushes it. Returns how far it
## moves this frame (stopped by walls, crates and other echoes).
func _push_from_player(delta: float) -> float:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if p == null or p.get("is_dead") or not p.is_on_floor():
		return 0.0
	var dir: float = signf(p.call("_move_axis"))
	var d := global_position - p.global_position
	if dir == 0.0 or d.x * dir <= 0.0 or absf(d.x) > 10.5 or absf(d.y) > 3.0:
		return 0.0
	var step := minf(PUSHED_SPEED * delta, _free_distance(global_position, Vector2(dir * PUSHED_SPEED * delta, 0)))
	if step <= 0.0:
		return 0.0
	_pushed = true
	return dir * step

## A pushed echo has weight: on frames Ren was standing when it was recorded,
## it falls to whatever is below it, or steps up onto a low ledge it was
## pushed into.
func _settle(target: Vector2, frame_data: Dictionary, delta: float) -> Vector2:
	if not _was_on_floor(frame_data):
		_fall_v = 0.0
		return target
	if _blocked_at(target):
		for lift in range(1, int(STEP_UP) + 1):
			if not _blocked_at(target - Vector2(0, lift)):
				_offset.y -= lift
				_fall_v = 0.0
				return target - Vector2(0, lift)
		return target
	var gap := _free_distance(target, Vector2(0, 400))
	if gap > 0.5:
		_fall_v = minf(_fall_v + GRAVITY * delta, MAX_FALL)
		var step := minf(_fall_v * delta, gap)
		_offset.y += step
		return target + Vector2(0, step)
	_fall_v = 0.0
	return target

func _was_on_floor(frame_data: Dictionary) -> bool:
	if frame_data.has("floor"):
		return frame_data["floor"]
	var prev: Dictionary = _frames[(_current_frame - 1 + _frames.size()) % _frames.size()]
	return is_equal_approx(prev["pos"].y, frame_data["pos"].y)

func _body_query(pos: Vector2) -> PhysicsShapeQueryParameters2D:
	var rect := RectangleShape2D.new()
	rect.size = (_body_shape.shape as RectangleShape2D).size - Vector2(0.4, 0.4)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = rect
	q.transform = Transform2D(0.0, pos + _body_shape.position)
	q.collision_mask = 1 | 4   # the world (crates too) and other echoes
	q.exclude = [($EchoPlatform as CollisionObject2D).get_rid()]
	return q

## How far the echo's body can move from pos by motion before it hits something.
func _free_distance(pos: Vector2, motion: Vector2) -> float:
	var q := _body_query(pos)
	q.motion = motion
	return get_world_2d().direct_space_state.cast_motion(q)[0] * motion.length()

func _blocked_at(pos: Vector2) -> bool:
	return not get_world_2d().direct_space_state.intersect_shape(_body_query(pos), 1).is_empty()

## Ren standing on the echo's head.
func _carrying_player() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	var d := p.global_position - global_position
	return absf(d.x) < 9.0 and absf(d.y + 15.0) < 2.0

## Would the echo's body, standing at pos, be inside Ren, where he is now or
## where he'll be after this frame's move? Full width, so it stops before it
## can shove him, but a little short so Ren standing on its head (or a touch
## against its side) doesn't count.
func _hits_player(pos: Vector2) -> bool:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if p == null:
		return false
	var rect := RectangleShape2D.new()
	rect.size = (_body_shape.shape as RectangleShape2D).size - Vector2(0.2, 2)
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = rect
	q.collision_mask = 2
	var space := get_world_2d().direct_space_state
	# Ren's next step, as a shift of the echo the other way
	for lead in [Vector2.ZERO, -p.velocity * get_physics_process_delta_time()]:
		q.transform = Transform2D(0.0, pos + _body_shape.position + lead)
		if not space.intersect_shape(q, 1).is_empty():
			return true
	return false

## Ren's middle is inside the echo's body (it spawned or looped onto him).
func _inside_player() -> bool:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return false
	var d := p.global_position - global_position
	return absf(d.x) < 4.5 and absf(d.y) < 7.5

func die() -> void:
	# Stop physics and interactions immediately
	_dying = true
	set_physics_process(false)
	_is_active = false
	_set_ghost(true)
	# Hide trail
	for trail in _trail_nodes:
		trail.visible = false
	# Play death animation then free
	if anim and anim.sprite_frames.has_animation("death"):
		anim.visible = true
		anim.play("death")
		await anim.animation_finished
	queue_free()
