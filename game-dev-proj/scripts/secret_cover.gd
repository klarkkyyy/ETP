#secret_cover.gd
# Rock drawn over a hidden room: the level's own wall tiles laid over where the
# room (or a fake floor or wall) is, in front of Ren, so from outside it looks
# like solid ground. It has no collision (a TileMapLayer's tiles do collide by
# default, so the node sets collision_enabled off too). While Ren is inside `reveal` it fades
# away, so he can see the room he found, and it comes back when he leaves.
extends TileMapLayer

## Where Ren has to be for the rock to fade (local px). Empty: never fades.
@export var reveal: Rect2

const FADE_TIME = 0.35

var _player: Node2D
var _shown := 1.0

func _ready() -> void:
	collision_enabled = false
	z_index = 6   # in front of Ren and the room's contents

func _physics_process(delta: float) -> void:
	if reveal.size == Vector2.ZERO:
		return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
		if _player == null:
			return
	var inside := reveal.has_point(to_local(_player.global_position))
	_shown = move_toward(_shown, 0.0 if inside else 1.0, delta / FADE_TIME)
	modulate.a = _shown
