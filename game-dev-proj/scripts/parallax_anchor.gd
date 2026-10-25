extends Parallax2D
## A parallax layer laid out in its parent's coordinates (put it under a plain
## Node2D at the level's origin). Children sit where they should appear while
## the camera is centred on `design_camera`; the layer drifts from there by its
## scroll_scale. Works wherever the level sits in game.tscn and at any window size.

@export var design_camera := Vector2.ZERO

func _ready() -> void:
	top_level = true
	var origin := (get_parent() as Node2D).global_position
	# Parallax2D places itself at (camera centre - half viewport) * (1 - scroll_scale) + scroll_offset.
	var screen := origin + design_camera - get_viewport_rect().size * 0.5
	scroll_offset = origin - screen * (Vector2.ONE - scroll_scale)
