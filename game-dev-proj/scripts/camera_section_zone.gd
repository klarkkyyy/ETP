#camera_section_zone.gd
# Hybrid room camera for the long levels. While the player is inside, the
# camera is held to `bounds` (or to this zone's own rectangle when empty).
# A section that fits on one screen works like the level 1/2 rooms: the
# camera glides to its center and stays put. A bigger one follows the
# player but never shows past the section's walls.
# Zones may overlap (a level-wide zone fills the gaps between sections): the
# smallest zone the player is in wins. Leaving every zone puts the camera's
# old limits back.
extends Area2D

## Camera limits for this section, relative to this zone. Empty = use this zone's shape.
@export var bounds: Rect2
## The whole level, relative to this zone. A section smaller than the screen is
## widened to fill it; this keeps that extra view inside the level.
@export var keep_inside: Rect2

static var _inside: Array = []  # zones the player is in right now
static var _defaults: Array = []  # camera limits from before the first zone

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if bounds.size == Vector2.ZERO:
		var cs: CollisionShape2D = $CollisionShape2D
		bounds = cs.transform * cs.shape.get_rect()

func _exit_tree() -> void:
	_inside.erase(self)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or self in _inside:
		return
	var cam = get_tree().get_first_node_in_group("camera")
	if not cam:
		return
	if _inside.is_empty():
		_defaults = [cam.limit_top, cam.limit_bottom, cam.limit_left, cam.limit_right]
	_inside.append(self)
	_apply(cam)

func _on_body_exited(body: Node) -> void:
	if not body.is_in_group("player") or self not in _inside:
		return
	_inside.erase(self)
	var cam = get_tree().get_first_node_in_group("camera")
	if not cam:
		return
	if _inside.is_empty():
		cam.set_follow_mode()
		cam.set_limits(_defaults[0], _defaults[1], _defaults[2], _defaults[3])
	else:
		_apply(cam)

static func _apply(cam: Camera2D) -> void:
	var best: Node = null
	for z in _inside:
		if is_instance_valid(z) and (best == null or z._area() < best._area()):
			best = z
	if best:
		best._hold(cam)

func _area() -> float:
	return bounds.get_area()

func _hold(cam: Camera2D) -> void:
	var r: Rect2 = global_transform * bounds
	# a section narrower or shorter than the screen is centered in it
	var view: Vector2 = cam.get_viewport_rect().size / cam.zoom
	var grow := (view - r.size).max(Vector2.ZERO) * 0.5
	r = r.grow_individual(grow.x, grow.y, grow.x, grow.y)
	if keep_inside.size != Vector2.ZERO:
		var outer: Rect2 = global_transform * keep_inside
		r.position = r.position.clamp(outer.position, (outer.end - r.size).max(outer.position))
	cam.set_limits(int(r.position.y), int(r.end.y), int(r.position.x), int(r.end.x))
	if r.size.x <= view.x + 1.0 and r.size.y <= view.y + 1.0:
		cam.set_room_mode(r.get_center())
	else:
		cam.set_follow_mode()
