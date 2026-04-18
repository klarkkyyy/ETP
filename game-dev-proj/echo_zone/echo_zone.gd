extends Area2D

## ── Configurable in Inspector ──────────────────────────────────────────────
@export var max_echoes: int = 3
@export var activation_range: float = 600.0
@export var sample_every_frames: int = 1

## ── Scene reference ────────────────────────────────────────────────────────
const EchoScene = preload("res://echo/echo.tscn")   # ← adjust to your path

## ── Internal state ─────────────────────────────────────────────────────────
var player: CharacterBody2D = null
var is_recording: bool = false
var active_slot: int = -1               # which slot (0-indexed) is recording
var current_recording: Array = []
var active_echo_nodes: Array = []       # live Echo nodes, indexed by slot
var _frame_counter: int = 0

signal echo_saved(slot: int)
signal echoes_cleared()


func _ready() -> void:
	add_to_group("echo_zone")
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	# Record frames only while actively recording
	if is_recording and player:
		_frame_counter += 1
		if _frame_counter >= sample_every_frames:
			_frame_counter = 0
			current_recording.append({
				"pos":    player.global_position,
				"flip_h": player.get_node("animations").flip_h
			})

	# Distance culling for active echoes
	if player and activation_range > 0.0:
		for echo_node in active_echo_nodes:
			if is_instance_valid(echo_node):
				var dist = player.global_position.distance_to(echo_node.global_position)
				echo_node.set_active(dist <= activation_range)


func _unhandled_input(event: InputEvent) -> void:
	# Ignore input when player is not inside the zone
	if not player:
		return

	if event.is_action_pressed("clear_echoes"):   # R
		_clear_all_echoes()
		return

	for slot in range(1, max_echoes + 1):
		if event.is_action_pressed("echo_slot_%d" % slot):
			_handle_slot_press(slot - 1)   # convert to 0-indexed
			return


# ── Slot press logic ───────────────────────────────────────────────────────

func _handle_slot_press(slot: int) -> void:
	if not is_recording:
		# Nothing recording yet — start recording for this slot
		_start_recording(slot)
	elif active_slot == slot:
		# Same button pressed again — finish and save
		_finish_recording()
	else:
		# Different slot pressed while already recording —
		# save the current one first, then start the new slot
		_finish_recording()
		_start_recording(slot)


func _start_recording(slot: int) -> void:
	current_recording = []
	_frame_counter = 0
	active_slot = slot
	is_recording = true
	# Optional: play a "recording started" animation on the zone sprite here


func _finish_recording() -> void:
	if not is_recording:
		return
	is_recording = false

	if current_recording.size() < 2:
		# Too short to be useful — discard silently
		active_slot = -1
		current_recording = []
		return

	_spawn_echo(active_slot, current_recording.duplicate(true))
	emit_signal("echo_saved", active_slot + 1)

	active_slot = -1
	current_recording = []


func _spawn_echo(slot: int, frames: Array) -> void:
	# Remove old echo in this slot if one exists
	while active_echo_nodes.size() <= slot:
		active_echo_nodes.append(null)

	if is_instance_valid(active_echo_nodes[slot]):
		active_echo_nodes[slot].queue_free()

	var echo_node = EchoScene.instantiate()
	get_parent().add_child(echo_node)
	echo_node.setup(frames, activation_range > 0.0)
	active_echo_nodes[slot] = echo_node


func _clear_all_echoes() -> void:
	is_recording = false
	active_slot = -1
	current_recording = []

	for echo_node in active_echo_nodes:
		if is_instance_valid(echo_node):
			echo_node.queue_free()
	active_echo_nodes.clear()
	emit_signal("echoes_cleared")


# ── Zone overlap ───────────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body


func _on_body_exited(body: Node) -> void:
	if body == player:
		# Leaving the zone finishes any active recording
		if is_recording:
			_finish_recording()
		player = null


# ── Called by player.gd on death ──────────────────────────────────────────

func cancel_recording() -> void:
	# Discard in-progress recording without saving — echoes already saved survive
	is_recording = false
	active_slot = -1
	current_recording = []
