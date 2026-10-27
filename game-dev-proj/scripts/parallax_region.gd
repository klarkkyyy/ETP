extends Node2D
## Groups a level's parallax layers (scripts/parallax_anchor.gd) and shows them
## only while the camera is over the level. Distant layers move almost with the
## screen, so without this they would show through gaps in neighbouring levels.

## Where the layers belong, in this node's coordinates (put it at the level's origin).
@export var area: Rect2
## When above zero, the layers fade out over this many px as the camera leaves
## `area`, instead of vanishing at its edge.
@export var fade := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keep up while paused too

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	var at := to_local(cam.get_screen_center_position())
	if fade <= 0.0:
		visible = area.has_point(at)
		return
	var out := maxf(maxf(area.position.x - at.x, at.x - area.end.x), maxf(area.position.y - at.y, at.y - area.end.y))
	var a := clampf(1.0 - out / fade, 0.0, 1.0)
	visible = a > 0.0
	for c in get_children():   # the layers are top_level, so they don't take this node's modulate
		if c is CanvasItem:
			(c as CanvasItem).modulate.a = a
