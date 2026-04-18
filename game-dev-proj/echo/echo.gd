extends Area2D

## Looping ghost replay of a recorded movement path.
## Trigger-only — no collision layer, interacts via Area2D overlap.

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D   # ← match your echo scene node name

var _frames: Array = []          # Array of {pos, flip_h}
var _current_frame: int = 0
var _is_active: bool = true      # controlled by distance check in echo_zone
var _loop_timer: float = 0.0


func setup(recorded_frames: Array, use_distance_check: bool) -> void:
	_frames = recorded_frames
	_current_frame = 0
	_is_active = not use_distance_check   # if no range check, always active
	if _frames.size() > 0:
		global_position = _frames[0]["pos"]
	_update_visuals()


func set_active(active: bool) -> void:
	if _is_active == active:
		return
	_is_active = active
	_update_visuals()


func _physics_process(_delta: float) -> void:
	if not _is_active or _frames.size() == 0:
		return

	var frame_data = _frames[_current_frame]
	global_position = frame_data["pos"]

	if anim:
		anim.flip_h = frame_data["flip_h"]
		# Mirror the run/idle animation based on movement delta
		_update_echo_animation(frame_data)

	_current_frame = (_current_frame + 1) % _frames.size()


func _update_echo_animation(frame_data: Dictionary) -> void:
	if not anim:
		return
	# Simple heuristic: compare position to previous frame to pick animation
	var prev_idx = (_current_frame - 1 + _frames.size()) % _frames.size()
	var prev_pos: Vector2 = _frames[prev_idx]["pos"]
	var delta_x = abs(frame_data["pos"].x - prev_pos.x)
	var delta_y = frame_data["pos"].y - prev_pos.y

	if delta_y < -1.5:
		anim.play("jump_up")
	elif delta_y > 1.5:
		anim.play("jump_down")
	elif delta_x > 0.5:
		anim.play("run")
	else:
		anim.play("idle")


func _update_visuals() -> void:
	if anim:
		anim.visible = _is_active
	modulate = Color(1, 1, 1, 0.55) if _is_active else Color(1, 1, 1, 0)


signal echo_entered_pad(echo: Area2D)
signal echo_exited_pad(echo: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("pressure_pad") or area.is_in_group("switch"):
		area.on_echo_enter(self)   # call a method on the pad — see pressure_pad.gd example below
	emit_signal("echo_entered_pad", self)


func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("pressure_pad") or area.is_in_group("switch"):
		area.on_echo_exit(self)
	emit_signal("echo_exited_pad", self)
