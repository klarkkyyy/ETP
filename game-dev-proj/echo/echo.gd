#echo.gd
# Replays a recording of Ren's inputs (Echoes records them): each frame it
# presses what he pressed, through his own movement rules, as a body in the
# level. Where the level is as it was when he recorded, it retraces his steps;
# where it isn't (a moving platform elsewhere, Ren or another echo in the way,
# Ren pushing it) it does what Ren would have, and keeps to its inputs from
# there. It rides platforms, stands on crates and echoes, and blocks Ren and
# other echoes (Echoes.solid). Something closing on it from above while it
# stands on the floor crushes it: it starts its loop over. Every loop starts
# where and as Ren started the recording; just before, it's gone for a couple
# of frames, so whatever stands on it drops off rather than going along. A recording of
# Ren standing still doesn't loop: that echo stands where it is until pushed.
extends Area2D

const Ren = preload("res://player/player.gd")

@onready var anim: AnimatedSprite2D = $animations
@onready var _body: CharacterBody2D = $EchoPlatform
@onready var _body_shape: CollisionShape2D = $EchoPlatform/CollisionShape2D

const PUSHED_SPEED = 60.0   # px/s when Ren pushes an echo
const CRUSH_INSET = 0.5     # this far inside something solid that closed on it from above = crushed
const SYNC_TOLERANCE = 0.5  # this close to where Ren was, it shows his recorded animation
const TRAIL_LENGTH = 8
static var GLOW := _unshaded()
const TRAIL_INTERVAL = 3
const SLOT_COLORS = [
	Color(0.4, 0.8, 1.0),
	Color(0.7, 0.3, 1.0),
	Color(0.2, 0.2, 0.2),
]

var _frames: Array = []
var _current_frame: int = 0
var _is_active: bool = true
var _trail_nodes: Array = []
var _trail_counter: int = 0
var _slot_color: Color = SLOT_COLORS[0]
var _can_absorb_orb: bool = true
var _dying: bool = false
var _crushed: bool = false
var _idle: bool = false         # Ren pressed nothing the whole recording
var _started: bool = false      # has played its first loop
var _gone: int = 0              # frames into the gap between one loop and the next
var _phantom: bool = false      # the stranger's demonstrations (make_phantom): seen, never touched
var _solid: int                 # Echoes.solid, or OFF for a phantom
var _passing: Array = []        # Ren and echoes it's passing through (it started a loop inside them)
var _interactables: Array = []

# Ren's movement state, as in player.gd
var _can_double_jump := false
var _was_on_floor := true
var _wall_sliding := false
var _pushing := false
var _wall_jump_timer := 0.0
var _jump_buffer_timer := 0.0
var _coyote_timer := 0.0

## A phantom has played its moves to the end (make_phantom).
signal played
signal echo_entered_pad(echo: Area2D)
signal echo_exited_pad(echo: Area2D)

func setup(recorded_frames: Array, use_distance_check: bool, slot: int = 0) -> void:
	_frames = recorded_frames
	_current_frame = 0
	_is_active = not use_distance_check
	_slot_color = SLOT_COLORS[clamp(slot, 0, SLOT_COLORS.size() - 1)]
	_idle = recorded_frames.all(func(f): return f.get("move", 0.0) == 0.0 		and not f.get("jump", false) and not f.get("interact", false))
	call_deferred("_setup_trail")
	_update_visuals()

static func _unshaded() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return m

## Turns it into a phantom: it plays its inputs through Ren's movement like any
## echo (once, then stops: `played`), but nothing touches it (no body, no pads, levers, orbs or spears, not
## in the "echo" group) and it's drawn with `look` instead of the echo trail.
## The stranger (story/stranger.gd) uses this for its demonstrations; a
## phantom's frames may be bare inputs, with only the first giving "pos".
func make_phantom(look: Material) -> void:
	_phantom = true
	_solid = Echoes.Solid.OFF
	_body.collision_layer = 0
	_body.collision_mask = 1
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)
	remove_from_group("echo")
	modulate = Color.WHITE
	anim.material = look
	anim.visible = true
	for t in _trail_nodes:
		t.queue_free()
	_trail_nodes.clear()

func set_active(active: bool) -> void:
	if _is_active == active or _dying:
		return
	_is_active = active
	_update_visuals()

func _ready() -> void:
	add_to_group("echo")
	process_physics_priority = 10   # after Ren and moving platforms, so it sees this frame's level
	_body.top_level = true
	_body.floor_max_angle = deg_to_rad(50.0)
	_solid = Echoes.solid
	match Echoes.solid:
		Echoes.Solid.OFF:
			_body.collision_layer = 0
			_body.collision_mask = 1
		Echoes.Solid.TOP:
			_body_shape.one_way_collision = true
			_body.collision_mask = 1 | 4   # Ren goes through its sides, so it goes through his
	# (area_entered / area_exited are connected in echo.tscn)

func _physics_process(delta: float) -> void:
	# Solid only while it's playing: paused far from Ren, crushed or between
	# loops, nothing stands on it or bumps into it. (Set here, not deferred,
	# so it's off before anyone moves on the next frame.)
	_body_shape.disabled = not _is_active or _crushed or _gone > 0
	if not _is_active or _crushed or _frames.size() == 0:
		return
	if _current_frame == 0 and (not _started or not _idle or _gone > 0):
		if _gone < 2:
			_vanish()
			return
		_start_loop()
	elif _is_crushed():
		_crush()
		return

	var f: Dictionary = _frames[_current_frame]
	var in_sync: bool = f.has("pos") and _body.global_position.distance_to(f["pos"]) <= SYNC_TOLERANCE
	_update_passing()
	_step(f, delta)
	global_position = _body.global_position
	_animate(f, in_sync)

	_trail_counter += 1
	if _trail_counter >= TRAIL_INTERVAL:
		_trail_counter = 0
		_update_trail()

	if f.get("interact", false):
		for area in _interactables:
			if is_instance_valid(area) and area.has_method("on_echo_interact"):
				area.on_echo_interact(self)

	_current_frame = (_current_frame + 1) % _frames.size()
	if _phantom and _current_frame == 0:
		# a phantom plays its moves once and stops where they leave it
		set_physics_process(false)
		played.emit()

## The gap before a loop starts over. First it's gone, so Ren (or an echo)
## on its head falls instead of going with it to the start; a frame later,
## with nothing standing on it, it moves to the start (the physics server
## takes the jump for a speed, which would fling anything still riding it).
func _vanish() -> void:
	_gone += 1
	_body_shape.disabled = true
	if _gone == 2:
		_body.global_position = _frames[0]["pos"]
		global_position = _frames[0]["pos"]

## Back to where, and as, Ren was when the recording started.
func _start_loop() -> void:
	_started = true
	_gone = 0
	_body_shape.disabled = false
	var f: Dictionary = _frames[0]
	var s: Dictionary = f.get("start", {})
	_body.velocity = Vector2.ZERO
	_was_on_floor = s.get("was_on_floor", f.get("floor", true))
	if s.get("on_floor", f.get("floor", true)):
		# is_on_floor() only knows what the last move found
		_body.floor_snap_length = 10.0
		_body.apply_floor_snap()
	_body.velocity = s.get("velocity", Vector2.ZERO)
	_can_double_jump = s.get("can_double_jump", false)
	_wall_jump_timer = s.get("wall_jump_timer", 0.0)
	_jump_buffer_timer = s.get("jump_buffer", 0.0)
	_coyote_timer = s.get("coyote", 0.0)
	_wall_sliding = false
	_pushing = false
	_pass_through_overlaps()   # it may have looped back onto Ren or another echo

## One frame of Ren's movement (player.gd's _physics_process) on the
## recorded inputs.
func _step(f: Dictionary, delta: float) -> void:
	var b := _body
	var axis: float = f.get("move", 0.0)
	if _wall_jump_timer > 0.0:
		_wall_jump_timer -= delta

	if b.is_on_floor():
		_can_double_jump = false
		_coyote_timer = Ren.COYOTE_TIME
	else:
		if _was_on_floor:
			_can_double_jump = true
		_coyote_timer -= delta

	if f.get("jump", false):
		_jump_buffer_timer = Ren.JUMP_BUFFER_TIME
	elif _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	_wall_sliding = false
	if b.is_on_wall() and not b.is_on_floor() and b.velocity.y > 20.0:
		var n := b.get_wall_normal().x
		_wall_sliding = (axis > 0 and n < 0) or (axis < 0 and n > 0)

	# pressing into a crate pushes it; into a wall, leans on it
	_pushing = false
	if b.is_on_floor() and not _wall_sliding and axis != 0:
		for i in b.get_slide_collision_count():
			var collider = b.get_slide_collision(i).get_collider()
			if is_instance_valid(collider) and collider.is_in_group("moveable"):
				var to_collider: Vector2 = (collider.global_position - b.global_position).normalized()
				if (axis > 0 and to_collider.x > 0.3) or (axis < 0 and to_collider.x < -0.3):
					_pushing = true
					if collider.has_method("receive_push"):
						collider.receive_push(axis)
					break
		if not _pushing and b.is_on_wall():
			var n := b.get_wall_normal().x
			_pushing = (axis > 0 and n < 0) or (axis < 0 and n > 0)

	if not b.is_on_floor():
		if _wall_sliding:
			b.velocity.y = minf(b.velocity.y + Ren.WALL_SLIDE_GRAVITY * delta, 60.0)
		else:
			b.velocity += b.get_gravity() * delta

	if _jump_buffer_timer > 0.0:
		if b.is_on_floor() or _coyote_timer > 0.0:
			b.velocity.y = Ren.JUMP_VELOCITY
			_can_double_jump = true
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0
		elif _wall_sliding:
			b.velocity.y = Ren.WALL_JUMP_VELOCITY_Y
			b.velocity.x = b.get_wall_normal().x * Ren.WALL_JUMP_VELOCITY_X
			_wall_jump_timer = Ren.WALL_JUMP_LOCKOUT
			_wall_sliding = false
			_jump_buffer_timer = 0.0
		elif _can_double_jump:
			b.velocity.y = Ren.DOUBLE_JUMP_VELOCITY
			_can_double_jump = false
			_jump_buffer_timer = 0.0

	if _wall_jump_timer <= 0.0:
		if axis:
			b.velocity.x = axis * Ren.SPEED
		else:
			b.velocity.x = move_toward(b.velocity.x, 0, Ren.SPEED)

	_was_on_floor = b.is_on_floor()
	b.floor_snap_length = 10.0 if b.is_on_floor() and _jump_buffer_timer <= 0.0 else 0.0

	# Ren pushing it shoves it along on top of its own running, for this frame
	var push := _push_from_player()
	b.velocity.x += push
	# Ren or an echo standing on its head rises with it, rather than stopping it
	var riders := _riders()
	for r in riders:
		b.add_collision_exception_with(r)
	b.move_and_slide()
	for r in riders:
		b.remove_collision_exception_with(r)
	b.velocity.x -= push
	for i in b.get_slide_collision_count():
		var collider = b.get_slide_collision(i).get_collider()
		if is_instance_valid(collider) and collider.is_in_group("box") and collider.is_on_wall():
			b.velocity.x = 0.0   # a pinned crate stops it, as it stops Ren

## Ren walking into its side on the same floor pushes it (solid echoes).
## Returns the push's speed this frame. The echo needn't be on the floor
## itself: level with Ren, it's tipping over an edge (the front of a moving
## platform keeps catching it there), and a push should carry it off.
func _push_from_player() -> float:
	if _solid != Echoes.Solid.FULL:
		return 0.0
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if p == null or p.get("is_dead") or not p.is_on_floor() or _passing.has(p):
		return 0.0
	var dir: float = signf(p.call("_move_axis"))
	var d := _body.global_position - p.global_position
	if dir == 0.0 or d.x * dir <= 0.0 or absf(d.x) > 10.5 or absf(d.y) > 3.0:
		return 0.0
	return dir * PUSHED_SPEED

## Ren and the echoes standing on its head (and not passing through it).
func _riders() -> Array:
	var riders: Array = []
	if _solid == Echoes.Solid.OFF:
		return riders
	var candidates: Array = [get_tree().get_first_node_in_group("player")]
	for e in get_tree().get_nodes_in_group("echo"):
		if e != self:
			candidates.append(e.get_node("EchoPlatform"))
	for c in candidates:
		if c is PhysicsBody2D and not _passing.has(c):
			var d: Vector2 = (c as Node2D).global_position - _body.global_position
			if absf(d.x) < 9.0 and d.y < -12.0 and d.y > -17.0:
				riders.append(c)
	return riders

## Starting a loop inside Ren or another echo, it passes through just those
## (and they through it) until they're apart, so neither is shoved out;
## everything else still stands on it and bumps into it.
func _pass_through_overlaps() -> void:
	if _solid == Echoes.Solid.OFF:
		return
	for hit in _overlapping(2 | 4, 0.1):
		var other = hit["collider"]
		if other is PhysicsBody2D and not _passing.has(other):
			_body.add_collision_exception_with(other)
			_passing.append(other)

func _update_passing() -> void:
	if _passing.is_empty():
		return
	var still: Array = []
	for hit in _overlapping(2 | 4, 0.1):
		still.append(hit["collider"])
	for other in _passing.duplicate():
		if not is_instance_valid(other):
			_passing.erase(other)
		elif not still.has(other):
			_body.remove_collision_exception_with(other)
			_passing.erase(other)

## What in the given layers is inside the echo's body (shrunk by inset).
func _overlapping(mask: int, inset: float = CRUSH_INSET) -> Array[Dictionary]:
	var capsule := _body_shape.shape as CapsuleShape2D
	var shape := CapsuleShape2D.new()
	shape.radius = capsule.radius - inset
	shape.height = capsule.height - 2.0 * inset
	var q := PhysicsShapeQueryParameters2D.new()
	q.shape = shape
	q.transform = _body_shape.global_transform
	q.collision_mask = mask
	q.exclude = [_body.get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(q, 8)

## Standing on the floor with something solid come down into it from above
## (a crushing platform, a crate dropped on it).
func _is_crushed() -> bool:
	if not _body.is_on_floor():
		return false
	for hit in _overlapping(1):
		# only what moves can close on it (the level's tiles and walls don't)
		var other = hit["collider"]
		if (other is AnimatableBody2D or other is CharacterBody2D or other is RigidBody2D) \
				and other.global_position.y < _body.global_position.y:
			return true
	return false

## Crushed: it dies, as Ren would, and comes back at the start of its loop.
func _crush() -> void:
	_crushed = true
	_body_shape.disabled = true
	for trail in _trail_nodes:
		trail.visible = false
	if anim and anim.sprite_frames.has_animation("death"):
		anim.visible = true
		anim.play("death")
		await anim.animation_finished
	if _dying or not is_inside_tree():
		return
	anim.visible = false
	_current_frame = 0
	_gone = 1   # already gone; comes back at its start (the shape stays off till then)
	_crushed = false

## Ren's recorded animation while it's where he was; once the level has put
## it somewhere else, the one its own movement calls for (as Ren's would).
func _animate(f: Dictionary, in_sync: bool) -> void:
	if not anim:
		return
	if in_sync and f.has("anim"):
		anim.flip_h = f["flip_h"]
		anim.play(f["anim"])
		return
	var axis: float = f.get("move", 0.0)
	if axis != 0.0:
		anim.flip_h = axis < 0
	if _body.is_on_floor():
		anim.play("push_forward" if _pushing else ("run" if axis != 0.0 else "idle"))
	elif _wall_sliding:
		anim.play("wall_slide")
	elif f.get("anim", "") == "double_jump":
		anim.play("double_jump")
	else:
		anim.play("jump_up" if _body.velocity.y < 0.0 else "jump_down")

func _update_trail() -> void:
	if _phantom:
		return
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
	if _phantom:
		return
	if anim:
		anim.visible = false
	modulate = Color(_slot_color.r, _slot_color.g, _slot_color.b, 0.45) if _is_active else Color(1, 1, 1, 0)
	for trail in _trail_nodes:
		trail.visible = _is_active


func _setup_trail() -> void:
	if _phantom:
		return
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
		trail_sprite.material = GLOW   # an echo is light: it shows in the dark
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

func die() -> void:
	# Stop physics and interactions immediately
	_dying = true
	set_physics_process(false)
	_is_active = false
	_body_shape.set_deferred("disabled", true)
	# Hide trail
	for trail in _trail_nodes:
		trail.visible = false
	# Play death animation then free
	if anim and anim.sprite_frames.has_animation("death"):
		anim.visible = true
		anim.play("death")
		await anim.animation_finished
	queue_free()
