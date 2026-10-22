#box.gd
# A crate Ren can push, stand on and stack. Echoes push it too: when a
# recording ends, crates go back to where they were when it started
# (echoes.gd), so the echo re-enacts the push on every loop. A crate is
# solid on the world layer, so it stops spears; it weighs down pressure pads
# and floats on a rising flood. It returns to its start when Ren respawns or
# clears his echoes, so one lost in a pit can't lock a room.
extends CharacterBody2D

@export var push_speed: float = 80.0
@export var friction: float = 800.0
@export var reset_on_respawn: bool = true
@export var reset_on_clear: bool = true

var home: Vector2
var _player: Node2D = null
var _player_was_dead := false
var _water_y := INF   # set each frame by a flood this crate is in

func _ready() -> void:
	add_to_group("box")
	add_to_group("moveable")
	home = global_position
	Echoes.echoes_cleared.connect(_on_echoes_cleared)

func _physics_process(delta: float) -> void:
	_watch_respawn()
	if _water_y < INF and global_position.y + 8.0 > _water_y - 2.0:
		# buoyant: ride up to sit on the surface
		velocity.y = clamp((_water_y - 6.0 - global_position.y) / delta, -150.0, 60.0)
	elif not is_on_floor():
		velocity += get_gravity() * delta
	_water_y = INF

	# Friction — only apply when on floor
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# Stop horizontal movement if hitting a wall
	if is_on_wall():
		velocity.x = 0.0

	move_and_slide()

func receive_push(direction: float) -> void:
	# Don't push it further into a wall it's already against
	if is_on_wall() and direction * get_wall_normal().x < 0.0:
		return
	velocity.x = direction * push_speed

## Called every physics frame by a rising_flood this crate is inside.
func float_on(surface_y: float) -> void:
	_water_y = surface_y

func reset() -> void:
	global_position = home
	velocity = Vector2.ZERO

func _watch_respawn() -> void:
	if not reset_on_respawn:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var dead: bool = _player.get("is_dead")
	if _player_was_dead and not dead:
		reset()
	_player_was_dead = dead

func _on_echoes_cleared() -> void:
	if reset_on_clear:
		reset()
