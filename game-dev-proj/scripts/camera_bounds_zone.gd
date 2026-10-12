#camera_bounds_zone.gd
# Like camera_follow_zone.gd, but while the player is inside this zone the
# camera is also clamped to the zone's rectangle (its CollisionShape2D), so it
# never shows past the level's edges. The previous limits come back on exit.
extends Area2D

var _saved: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	var cam = get_tree().get_first_node_in_group("camera")
	if not cam:
		return
	cam.set_follow_mode()
	if _saved.is_empty():
		_saved = [cam.limit_top, cam.limit_bottom, cam.limit_left, cam.limit_right]
	var cs: CollisionShape2D = $CollisionShape2D
	var r: Rect2 = cs.global_transform * cs.shape.get_rect()
	cam.set_limits(int(r.position.y), int(r.end.y), int(r.position.x), int(r.end.x))

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player") or _saved.is_empty():
		return
	var cam = get_tree().get_first_node_in_group("camera")
	if cam:
		cam.set_limits(_saved[0], _saved[1], _saved[2], _saved[3])
	_saved = []
