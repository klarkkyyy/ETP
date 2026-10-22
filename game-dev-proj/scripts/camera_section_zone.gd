#camera_section_zone.gd
# Hybrid room camera for the long levels. While the player is inside, the
# camera is held to `bounds` (or to this zone's own rectangle when empty).
# A section that fits on one screen works like the level 1/2 rooms: the
# camera glides to its center and stays put. A bigger one follows the
# player but never shows past the section's walls.
# Zones may overlap (a level-wide zone sits under all of a level's sections).
# camera.gd calls update_all() every physics tick, going by the player's
# centre. A section takes over when the centre enters its collision shape
# (its trigger) and has left the current section's trigger (plus STICKY px,
# so a jump on the seam doesn't flip the camera back and forth). Triggers can
# be inset from the camera bounds, leaving a doorway between two of them; in
# there the current section holds while the centre is inside its bounds,
# instead of the level-wide zone cutting in. Leaving every zone puts the
# camera's old limits back.
class_name CameraSectionZone
extends Area2D

## Camera limits for this section, relative to this zone. Empty = use this zone's shape.
@export var bounds: Rect2
## The whole level, relative to this zone. A section smaller than the screen is
## widened to fill it; this keeps that extra view inside the level.
@export var keep_inside: Rect2

const STICKY = 4.0

static var _all: Array = []
static var _current: CameraSectionZone = null
static var _defaults: Array = []  # camera limits from before the first zone

var _trigger: Rect2  # this zone's shape, relative to the zone

func _ready() -> void:
	var cs: CollisionShape2D = $CollisionShape2D
	_trigger = cs.transform * cs.shape.get_rect()
	if bounds.size == Vector2.ZERO:
		bounds = _trigger
	_all.append(self)

func _exit_tree() -> void:
	_all.erase(self)
	if _current == self:
		_current = null

func _trigger_rect() -> Rect2:
	return global_transform * _trigger

func _rect() -> Rect2:
	return global_transform * bounds

func _area() -> float:
	return bounds.get_area()

static func update_all(cam: Camera2D, player: Node2D) -> void:
	var c := player.global_position
	var cur: CameraSectionZone = _current if is_instance_valid(_current) else null
	var pick: CameraSectionZone = cur
	if cur and cur._trigger_rect().grow(STICKY).has_point(c):
		# in the level-wide zone and now inside one of its sections (bounds, not
		# trigger: a checkpoint can sit in the doorway between two triggers)
		for z in _all:
			var inner: bool = z != cur and cur._rect().encloses(z._rect())
			if inner and z._rect().has_point(c) and z._area() < pick._area():
				pick = z
	else:
		var next: CameraSectionZone = null
		for z in _all:
			if z == cur or not z._trigger_rect().has_point(c):
				continue
			if cur and z._rect().encloses(cur._rect()):
				continue  # the level-wide zone under this section: not in a doorway
			if next == null or z._area() < next._area():
				next = z
		if next:
			pick = next
		elif not (cur and cur._rect().has_point(c)):
			pick = null
			for z in _all:
				if z._rect().has_point(c) and (pick == null or z._area() < pick._area()):
					pick = z
	if pick == _current:
		return
	if _current == null:
		_defaults = [cam.limit_top, cam.limit_bottom, cam.limit_left, cam.limit_right]
	_current = pick
	if pick:
		pick._hold(cam)
	else:
		cam.set_follow_mode()
		cam.set_limits(_defaults[0], _defaults[1], _defaults[2], _defaults[3])

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
