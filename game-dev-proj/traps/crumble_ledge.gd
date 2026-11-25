# crumble_ledge.gd — a rock shelf that gives way (Level 11, The Tally).
# When Ren or a playing echo stands on it, it cracks for `delay` seconds and
# then falls away; `respawn` seconds later it's back (once nothing is in its
# way). Echoes break it too, so the order you send things across matters.
# Ren respawning puts every ledge back at once.
# Place the node at the centre of the shelf's top edge; it is `tiles` wide
# and one tile thick, drawn from the cave tileset's one-tile run.
extends StaticBody2D

const CAVES = "res://assets/FREE UPDATE V1/FREE UPDATE V1/TILESETS/caves_tileset.png"
const SFX_CRACK = "res://audio/sfx/step_rock.wav"
const SFX_FALL = "res://audio/sfx/stone_door_close.mp3"
const T = 16.0

@export var tiles: int = 3
@export var delay: float = 0.45
@export var respawn: float = 3.0

enum State { SOLID, CRACKING, GONE }
var state := State.SOLID
var _t := 0.0
var _art: Node2D
var _shape: CollisionShape2D
var _player: Node2D
var _player_was_dead := false


func _ready() -> void:
	add_to_group("crumble_ledge")
	collision_layer = 1
	collision_mask = 0
	var w := tiles * T
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(w, T)
	_shape.shape = rect
	_shape.position = Vector2(0, T * 0.5)
	add_child(_shape)
	_art = Node2D.new()
	_art.z_index = -9
	add_child(_art)
	var tex: Texture2D = load(CAVES)
	for i in tiles:
		# the tileset's one-tile run: left cap (9, 1), middle (10, 1), right cap (12, 1)
		var col := 10 if (i > 0 and i < tiles - 1) else (9 if i == 0 else 12)
		if tiles == 1:
			col = 10
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.region_enabled = true
		s.region_rect = Rect2(col * T, T, T, T)
		s.centered = false
		s.position = Vector2(-w * 0.5 + i * T, 0)
		_art.add_child(s)
	# hairline cracks so it reads as fragile even before it's touched
	var crack := Line2D.new()
	var pts := PackedVector2Array()
	for i in tiles * 2 + 1:
		pts.append(Vector2(-w * 0.5 + 2 + i * (w - 4) / (tiles * 2), 7 + (3 if i % 2 else -2)))
	crack.points = pts
	crack.width = 1.0
	crack.default_color = Color(0.16, 0.07, 0.09, 0.9)
	_art.add_child(crack)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	if _player:
		var dead: bool = _player.get("is_dead")
		if _player_was_dead and not dead:
			_restore()
		_player_was_dead = dead
	match state:
		State.SOLID:
			if _stood_on():
				state = State.CRACKING
				_t = delay
				SoundManager.play(SFX_CRACK, -6, 0.6)
		State.CRACKING:
			_t -= delta
			_art.position = Vector2(randf_range(-1, 1), randf_range(0, 1)) * (1.0 - _t / delay) * 2.0
			if _t <= 0.0:
				_break()
		State.GONE:
			_t -= delta
			if _t <= 0.0 and not _blocked():
				_restore()


func _break() -> void:
	state = State.GONE
	_t = respawn
	_shape.set_deferred("disabled", true)
	SoundManager.play(SFX_FALL, -14, 1.5)
	var tw := create_tween()
	_art.position = Vector2.ZERO
	tw.tween_property(_art, "position", Vector2(0, 40), 0.35).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_art, "modulate:a", 0.0, 0.35)


func _restore() -> void:
	state = State.SOLID
	_shape.set_deferred("disabled", false)
	_art.position = Vector2.ZERO
	var tw := create_tween()
	tw.tween_property(_art, "modulate:a", 1.0, 0.25)


## Ren or a playing echo standing on it (feet on its top edge, on the floor:
## jumping up past its edge doesn't count).
func _stood_on() -> bool:
	if _player and not _player.get("is_dead") and _grounded(_player) and _on_top(_player.global_position):
		return true
	for e in get_tree().get_nodes_in_group("echo"):
		if e.get("_is_active") and not e.get("_dying") and _grounded(e.get("_body")) and _on_top((e as Node2D).global_position):
			return true
	return false


func _grounded(b) -> bool:
	return b is CharacterBody2D and (b as CharacterBody2D).is_on_floor()


func _on_top(p: Vector2) -> bool:
	var d := p - global_position
	return absf(d.x) <= tiles * T * 0.5 + 3.0 and d.y > -12.0 and d.y < -4.0


## Something where the shelf would come back (it waits rather than shove it).
func _blocked() -> bool:
	var pts: Array = []
	if _player and not _player.get("is_dead"):
		pts.append(_player.global_position)
	for e in get_tree().get_nodes_in_group("echo"):
		pts.append((e as Node2D).global_position)
	for p in pts:
		var d: Vector2 = p - global_position
		if absf(d.x) <= tiles * T * 0.5 + 5.0 and d.y > -8.0 and d.y < T + 8.0:
			return true
	return false
