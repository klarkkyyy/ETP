#camera.gd
# The game camera. FOLLOW tracks Ren; ROOM glides to a fixed point (a room's
# centre). It runs on the physics tick, like Ren, so it never judders against
# him, and Godot's position smoothing is the only easing. The target is kept
# inside the limits, so the camera never drifts out past a wall and then
# lurches when the limits change.
# Height follows the platformer rule: the camera holds the height Ren last
# stood at, so a jump or double jump doesn't bob the screen; it follows him
# once he climbs well above that or drops below it.
# When the view changes (a new section, room or limits) the camera pans there
# with an ease-in-out instead of the smoothing's fast start, with the limits
# off until it arrives, so they can't clamp it into a jump.
# The camera zones (camera_section_zone / camera_room_zone / camera_follow_zone)
# are updated from here each tick, before the camera moves.
extends Camera2D

@export var follow_speed: float = 8.0  # smoothing while following
@export var snap_speed: float = 5.0  # smoothing while gliding to a room
@export var follow_offset: Vector2 = Vector2(0, -45)
## How far Ren can rise above where he last stood before the camera follows him
## up. A double jump is ~78 px, so jumping never moves it; wall-climbing does.
@export var rise_window: float = 90.0
## How far Ren can fall below where he last stood before the camera follows him down.
@export var fall_window: float = 8.0
## Pan speed when the view changes; the pan takes 0.2-0.6 s whatever the distance.
@export var pan_speed: float = 1000.0

## Ren moved further than this in one tick (respawn, teleport): cut, don't pan.
const CUT_DISTANCE = 160.0
const PAN_MIN = 0.2
const PAN_MAX = 0.6
const MAX_LAG = 60.0  # px the view may trail a falling Ren
const PAN_MARGIN = 16.0  # px Ren stays inside the view edge during a pan

enum CameraMode { FOLLOW, ROOM }

var mode: CameraMode = CameraMode.FOLLOW
var player: Node2D = null
## While true the camera stays where it is (cutscenes).
var hold: bool = false
var _target_pos: Vector2
var _last_player_pos: Vector2
var _view_changed := false
var _pan_from: Vector2
var _pan_time := 0.0
var _pan_length := 0.0

func _ready() -> void:
	add_to_group("camera")
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("ERROR: Camera could not find player")
		return
	_target_pos = player.global_position + follow_offset
	_last_player_pos = player.global_position

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or hold:
		return
	var p := player.global_position
	var cut := p.distance_to(_last_player_pos) > CUT_DISTANCE
	_last_player_pos = p
	# where the view is now, before new limits can pull it
	var shown := get_screen_center_position()
	# zones first: they set the mode, the room target and the limits
	CameraSectionZone.update_all(self, player)
	CameraRoomZone.update_all(self, player)

	if mode == CameraMode.FOLLOW:
		var want := p + follow_offset
		_target_pos.x = want.x
		if cut or player.is_on_floor():
			_target_pos.y = want.y
		elif want.y < _target_pos.y - rise_window:
			_target_pos.y = want.y + rise_window
		elif want.y > _target_pos.y + fall_window:
			_target_pos.y = want.y - fall_window
	var goal := _clamp_to_limits(_target_pos)

	if cut:
		_view_changed = false
		_end_pan()
		global_position = goal
		reset_smoothing()
		return
	if _view_changed:
		_view_changed = false
		_start_pan(shown, goal)
	if _pan_length > 0.0:
		_pan_time += delta
		var t := clampf(_pan_time / _pan_length, 0.0, 1.0)
		var pos := _pan_from.lerp(goal, smoothstep(0.0, 1.0, t))
		# the pan starts slow: never let it leave Ren outside the view
		var keep := get_viewport_rect().size / zoom * 0.5 - Vector2(PAN_MARGIN, PAN_MARGIN)
		global_position = pos.clamp(p - keep, p + keep)
		if t >= 1.0:
			_end_pan()
		return
	position_smoothing_speed = snap_speed
	if mode == CameraMode.FOLLOW:
		# smoothing lags speed/smoothing px behind: keep up with a long fall
		var vy: float = absf(player.velocity.y) if "velocity" in player else 0.0
		position_smoothing_speed = maxf(follow_speed, vy / MAX_LAG)
	global_position = goal

func _start_pan(from: Vector2, goal: Vector2) -> void:
	_pan_from = from
	_pan_time = 0.0
	_pan_length = clampf(_pan_from.distance_to(goal) / pan_speed, PAN_MIN, PAN_MAX)
	position_smoothing_enabled = false
	limit_enabled = false  # the goal is clamped to them already

func _end_pan() -> void:
	if _pan_length <= 0.0:
		return
	_pan_length = 0.0
	limit_enabled = true
	position_smoothing_enabled = true
	reset_smoothing()

func _clamp_to_limits(pos: Vector2) -> Vector2:
	var half := get_viewport_rect().size / zoom * 0.5
	var lo := Vector2(limit_left, limit_top) + half
	var hi := Vector2(limit_right, limit_bottom) - half
	# a limit box smaller than the screen: sit in its middle
	return Vector2(
		pos.x if lo.x <= hi.x else (lo.x + hi.x) * 0.5,
		pos.y if lo.y <= hi.y else (lo.y + hi.y) * 0.5).clamp(lo.min(hi), hi.max(lo))

func set_follow_mode() -> void:
	if mode != CameraMode.FOLLOW:
		_view_changed = true
		if is_instance_valid(player):
			_target_pos = player.global_position + follow_offset
	mode = CameraMode.FOLLOW

func set_room_mode(room_center: Vector2) -> void:
	if mode != CameraMode.ROOM or not room_center.is_equal_approx(_target_pos):
		_view_changed = true
	mode = CameraMode.ROOM
	_target_pos = room_center

func set_limits(top: int, bottom: int, left: int, right: int) -> void:
	if top != limit_top or bottom != limit_bottom or left != limit_left or right != limit_right:
		_view_changed = true
	limit_top = top
	limit_bottom = bottom
	limit_left = left
	limit_right = right
