extends Area2D

## Looping ghost replay of a recorded movement path.
## Trigger-only — no collision layer, interacts via Area2D overlap.


@onready var anim: AnimatedSprite2D = $animations   # ← match your echo scene node name

const TRAIL_LENGTH = 8        # how many trail copies
const TRAIL_INTERVAL = 3      # frames between each trail copy
const SLOT_COLORS = [
	Color(0.4, 0.8, 1.0),   # slot 0 — blue
	Color(0.7, 0.3, 1.0),   # slot 1 — purple
	Color(0.2, 0.2, 0.2),   # slot 2 — dark/black
]

var _frames: Array = []          # Array of {pos, flip_h}
var _current_frame: int = 0
var _is_active: bool = true      # controlled by distance check in echo_zone
var _loop_timer: float = 0.0
var _trail_nodes: Array = []
var _trail_counter: int = 0
var _slot_color: Color = SLOT_COLORS[0]

func setup(recorded_frames: Array, use_distance_check: bool, slot: int = 0) -> void:
	_frames = recorded_frames
	_current_frame = 0
	_is_active = not use_distance_check
	_slot_color = SLOT_COLORS[clamp(slot, 0, SLOT_COLORS.size() - 1)]
	# ← remove the global_position line from here
	_setup_trail()
	_update_visuals()

func set_active(active: bool) -> void:
	if _is_active == active:
		return
	_is_active = active
	_update_visuals()

func _physics_process(_delta: float) -> void:
	if not _is_active or _frames.size() == 0:
		return
	
	_trail_counter += 1
	if _trail_counter >= TRAIL_INTERVAL:
		_trail_counter = 0
		_update_trail()
	
	var frame_data = _frames[_current_frame]
	global_position = frame_data["pos"]
	if anim:
		anim.flip_h = frame_data["flip_h"]
		_update_echo_animation(frame_data)
	_current_frame = (_current_frame + 1) % _frames.size()

func _update_echo_animation(frame_data: Dictionary) -> void:
	if frame_data.has("anim"):
		anim.play(frame_data["anim"])  # exact replay
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

func _update_trail() -> void:
	for i in range(TRAIL_LENGTH - 1, 0, -1):
		_trail_nodes[i].position = _trail_nodes[i - 1].position
		_trail_nodes[i].flip_h = _trail_nodes[i - 1].flip_h
		_trail_nodes[i].visible = _trail_nodes[i - 1].visible
		_trail_nodes[i].play(_trail_nodes[i - 1].animation)  # ← actually play it
	_trail_nodes[0].position = Vector2.ZERO
	_trail_nodes[0].flip_h = anim.flip_h
	_trail_nodes[0].visible = _is_active
	_trail_nodes[0].play(anim.animation)  # ← and this one too


func _update_visuals() -> void:
	if anim:
		anim.visible = false
	modulate = Color(_slot_color.r, _slot_color.g, _slot_color.b, 0.45) if _is_active else Color(1, 1, 1, 0)
	for trail in _trail_nodes:
		trail.visible = _is_active
signal echo_entered_pad(echo: Area2D)
signal echo_exited_pad(echo: Area2D)

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _setup_trail() -> void:
	# Clear existing trail nodes first in case setup is called again
	for t in _trail_nodes:
		t.queue_free()
	_trail_nodes.clear()

	for i in range(TRAIL_LENGTH):
		var trail_sprite = AnimatedSprite2D.new()
		trail_sprite.sprite_frames = anim.sprite_frames
		trail_sprite.play("idle")
		var alpha = (1.0 - float(i) / TRAIL_LENGTH) * 0.18
		trail_sprite.modulate = Color(_slot_color.r, _slot_color.g, _slot_color.b, alpha)
		trail_sprite.z_index = -1
		add_child(trail_sprite)
		trail_sprite.visible = false
		_trail_nodes.append(trail_sprite)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("pressure_pad") or area.is_in_group("switch"):
		area.on_echo_enter(self)   # call a method on the pad — see pressure_pad.gd example below
	emit_signal("echo_entered_pad", self)

func _on_area_exited(area: Area2D) -> void:
	if area.is_in_group("pressure_pad") or area.is_in_group("switch"):
		area.on_echo_exit(self)
	emit_signal("echo_exited_pad", self)
