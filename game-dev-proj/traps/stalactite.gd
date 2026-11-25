# stalactite.gd — loose rock hanging from a cave ceiling (Level 11, The Tally).
# Anything that walks under it, Ren or an echo, shakes it loose: it trembles
# for `delay` seconds, then drops. It kills Ren if it comes down on him;
# echoes shrug it off, which makes them good decoys. When it hits the floor
# it stands there, tip buried, as a pillar you can stand on for `linger`
# seconds (`landing`), then crumbles and slowly grows back on the ceiling.
# When Ren respawns every stalactite is back on the ceiling, armed. With
# `shakes` set, its crash shakes that other rock loose too.
# Place the node with its origin at the ceiling, centred on the rock. The
# floor below is found with a ray at ready, unless `fall_distance` is set.
extends Node2D

const SFX_LOOSE = "res://audio/sfx/woosh_r.mp3"
const SFX_LAND = "res://audio/sfx/stone_door_close.mp3"
const ROCK = Color(0.42, 0.24, 0.26)
const ROCK_LIGHT = Color(0.66, 0.38, 0.36)
const ROCK_DARK = Color(0.24, 0.12, 0.15)
const GRAVITY = 1100.0

## Width of the rock in px (its flat top is what you stand on once it lands).
@export var width: float = 24.0
## Length from the ceiling to the tip, px.
@export var length: float = 30.0
## How far below the tip it notices things (0 = all the way to the floor).
@export var reach: float = 0.0
## Seconds it trembles before it drops.
@export var delay: float = 0.3
## Seconds it stands as a pillar after landing (0 = it shatters at once).
@export var linger: float = 3.0
## Seconds it takes to grow back once it's gone.
@export var regrow: float = 2.5
## Ceiling to floor in px; 0 = measure it with a ray.
@export var fall_distance: float = 0.0
## Another stalactite the crash of this one shakes loose (a chain of rocks
## where the next is out of reach once you stand on this one).
@export var shakes: NodePath

enum State { ARMED, SHAKING, FALLING, LANDED, GONE, GROWING }
var state := State.ARMED
var _t := 0.0
var _drop := 0.0          # how far the rock has fallen, px
var _vel := 0.0
var _rock: Polygon2D
var _body: StaticBody2D
var _shape: CollisionShape2D
var _dust: CPUParticles2D
var _player: Node2D
var _player_was_dead := false


func _ready() -> void:
	add_to_group("stalactite")
	z_index = -5
	_rock = Polygon2D.new()
	_rock.polygon = _outline()
	_rock.color = ROCK
	add_child(_rock)
	var rim := Line2D.new()  # a lit edge down one side so it reads against the dark rock
	rim.points = PackedVector2Array([Vector2(-width * 0.5 + 2, 1), Vector2(-width * 0.16, length * 0.62), Vector2(0, length - 2)])
	rim.width = 2.0
	rim.default_color = ROCK_LIGHT
	_rock.add_child(rim)
	var shade := Line2D.new()
	shade.points = PackedVector2Array([Vector2(width * 0.5 - 2, 1), Vector2(width * 0.2, length * 0.55)])
	shade.width = 2.0
	shade.default_color = ROCK_DARK
	_rock.add_child(shade)
	_body = StaticBody2D.new()
	_body.collision_layer = 1
	_body.collision_mask = 0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width - 4.0, length - 6.0)  # the wide part; the buried tip doesn't count
	_shape.shape = rect
	_shape.disabled = true
	_body.add_child(_shape)
	add_child(_body)
	_dust = CPUParticles2D.new()
	_dust.emitting = false
	_dust.one_shot = true
	_dust.amount = 14
	_dust.lifetime = 0.7
	_dust.explosiveness = 0.9
	_dust.direction = Vector2(0, -1)
	_dust.spread = 70.0
	_dust.gravity = Vector2(0, 260)
	_dust.initial_velocity_min = 30.0
	_dust.initial_velocity_max = 80.0
	_dust.scale_amount_min = 1.5
	_dust.scale_amount_max = 3.0
	_dust.color = Color(0.6, 0.42, 0.4, 0.8)
	add_child(_dust)
	_place()


func _outline() -> PackedVector2Array:
	var w := width * 0.5
	return PackedVector2Array([
		Vector2(-w, 0), Vector2(w, 0), Vector2(w * 0.8, length * 0.25), Vector2(w * 0.45, length * 0.55),
		Vector2(w * 0.15, length * 0.85), Vector2(0, length), Vector2(-w * 0.2, length * 0.8),
		Vector2(-w * 0.55, length * 0.5), Vector2(-w * 0.85, length * 0.22),
	])


## Finds the floor under the rock.
func _measure() -> void:
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, length + 1), global_position + Vector2(0, 2000))
	q.collision_mask = 1
	var hit := get_world_2d().direct_space_state.intersect_ray(q)
	fall_distance = (hit.position.y - global_position.y) if hit else 400.0


## How far the rock drops before its tip meets the floor.
func _max_drop() -> float:
	return maxf(0.0, fall_distance - length)


func _physics_process(delta: float) -> void:
	if fall_distance <= 0.0:
		_measure()   # on the first physics frame: the level's collision isn't in place at _ready
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		var dead: bool = _player.get("is_dead")
		if _player_was_dead and not dead:
			reset()
		_player_was_dead = dead
	match state:
		State.ARMED:
			if _something_below():
				shake()
		State.SHAKING:
			_t -= delta
			_rock.position.x = sin(Time.get_ticks_msec() * 0.09) * 1.5
			if _t <= 0.0:
				_rock.position.x = 0.0
				state = State.FALLING
				_vel = 0.0
		State.FALLING:
			_vel += GRAVITY * delta
			_drop = minf(_drop + _vel * delta, _max_drop())
			_place()
			_hit_ren()
			if _drop >= _max_drop():
				_land()
		State.LANDED:
			_t -= delta
			if _t < 0.6:
				_rock.modulate.a = 0.4 + 0.6 * absf(sin(_t * 18.0))  # about to crumble
			if _t <= 0.0:
				_crumble()
		State.GONE:
			_t -= delta
			if _t <= 0.0:
				state = State.GROWING
				_t = 0.8
				_drop = 0.0
				_place()
				_rock.visible = true
		State.GROWING:
			_t -= delta
			_rock.modulate.a = 1.0 - _t / 0.8
			_rock.scale = Vector2(1.0, lerpf(0.2, 1.0, 1.0 - _t / 0.8))
			if _t <= 0.0:
				_rock.modulate.a = 1.0
				_rock.scale = Vector2.ONE
				state = State.ARMED


## Starts it trembling, as if something walked under it.
func shake() -> void:
	if state != State.ARMED:
		return
	state = State.SHAKING
	_t = delay
	SoundManager.play(SFX_LOOSE, -14, 0.7)


func _land() -> void:
	SoundManager.play(SFX_LAND, -10, 1.3)
	_dust.position = Vector2(0, fall_distance)
	_dust.restart()
	var next := get_node_or_null(shakes) if not shakes.is_empty() else null
	if next and next.has_method("shake"):
		next.shake()
	if linger <= 0.0:
		_crumble()
		return
	state = State.LANDED
	_t = linger
	_shape.set_deferred("disabled", false)


func _crumble() -> void:
	state = State.GONE
	_t = regrow
	_rock.visible = false
	_rock.modulate.a = 1.0
	_shape.set_deferred("disabled", true)
	_dust.position = Vector2(0, _drop + length * 0.5)
	_dust.restart()


## Back on the ceiling, armed (Ren respawned).
func reset() -> void:
	state = State.ARMED
	_drop = 0.0
	_vel = 0.0
	_rock.visible = true
	_rock.modulate.a = 1.0
	_rock.scale = Vector2.ONE
	_rock.position = Vector2.ZERO
	_shape.set_deferred("disabled", true)
	_place()


func _place() -> void:
	_rock.position.y = _drop
	_shape.position = Vector2(0, _drop + (length - 6.0) * 0.5)


## Ren or a playing echo in the column under the rock.
func _something_below() -> bool:
	var bottom := (length + reach) if reach > 0.0 else fall_distance
	var half := width * 0.5 + 3.0
	if _player and not _player.get("is_dead") and _in_column(_player.global_position, half, bottom):
		return true
	for e in get_tree().get_nodes_in_group("echo"):
		if e.get("_is_active") and not e.get("_dying") and _in_column((e as Node2D).global_position, half, bottom):
			return true
	return false


func _in_column(p: Vector2, half: float, bottom: float) -> bool:
	var d := p - global_position
	return absf(d.x) <= half and d.y > 0.0 and d.y - 8.0 <= bottom


## The falling rock kills Ren if it overlaps him (his capsule is 9 x 15).
func _hit_ren() -> void:
	if _player == null or _player.get("is_dead"):
		return
	var d := _player.global_position - global_position
	var top := _drop
	var tip := _drop + length
	var half := width * 0.5 - 2.0
	if absf(d.x) <= half + 4.0 and d.y + 7.0 >= top and d.y - 7.0 <= tip - 4.0:
		_player.die()
