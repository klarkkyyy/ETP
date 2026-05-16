#echo_zone.gd
extends Area2D

@export var max_echoes: int = 3
@export var activation_range: float = 600.0
@export var sample_every_frames: int = 1

const EchoScene = preload("res://echo/echo.tscn")  
const SFX_CLEAR = "res://audio/sfx/clear.mp3"

var player: CharacterBody2D = null
var is_recording: bool = false
var active_slot: int = -1            
var current_recording: Array = []
var active_echo_nodes: Array = []      
var _frame_counter: int = 0

signal echo_saved(slot: int)
signal echoes_cleared()


func _ready() -> void:
	add_to_group("echo_zone")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

func _physics_process(_delta: float) -> void:
	if is_recording and player:
		_frame_counter += 1
		if _frame_counter >= sample_every_frames:
			_frame_counter = 0
			current_recording.append({
				"pos":    player.global_position,
				"flip_h": player.get_node("animations").flip_h,
				"anim":   player.get_node("animations").animation,
				"interact": Input.is_action_just_pressed("interact")
			})

	if player and activation_range > 0.0:
		for echo_node in active_echo_nodes:
			if is_instance_valid(echo_node):
				var dist = player.global_position.distance_to(echo_node.global_position)
				echo_node.set_active(dist <= activation_range)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("clear_echoes"):
		_clear_all_echoes()
		return

	for slot in range(1, max_echoes + 1):
		if event.is_action_pressed("echo_slot_%d" % slot):
			if not GameManager.is_echo_unlocked(slot):
				print("Echo slot ", slot, " is locked")
				return
			if player:
				_handle_slot_press(slot - 1)
			else:
				_remove_echo(slot - 1)
			return

func _remove_echo(slot: int) -> void:
	if slot >= active_echo_nodes.size():
		return
	if is_instance_valid(active_echo_nodes[slot]):
		active_echo_nodes[slot].die() 
		active_echo_nodes[slot] = null
func _start_recording(slot: int) -> void:
	current_recording = []
	_frame_counter = 0
	active_slot = slot
	is_recording = true
	EchoFlash.flash_start(slot + 1)

func _clear_all_echoes() -> void:
	is_recording = false
	active_slot = -1
	current_recording = []
	
	for echo_node in active_echo_nodes:
		if is_instance_valid(echo_node):
			SoundManager.play(SFX_CLEAR, -12, 0.9)
			echo_node.die() 
	active_echo_nodes.clear()
	emit_signal("echoes_cleared")

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		if player.has_method("set_echo_zone"):
			player.set_echo_zone(self)

func _handle_slot_press(slot: int) -> void:
	if not is_recording:
		_start_recording(slot)
	elif active_slot == slot:
		_finish_recording()
	else:
		_finish_recording()
		_start_recording(slot)

func _finish_recording() -> void:
	if not is_recording:
		return
	is_recording = false
	if current_recording.size() < 2:
		active_slot = -1
		current_recording = []
		return
	EchoFlash.flash_stop(active_slot + 1)
	_spawn_echo(active_slot, current_recording.duplicate(true))
	emit_signal("echo_saved", active_slot + 1)
	active_slot = -1
	current_recording = []

func _spawn_echo(slot: int, frames: Array) -> void:
	while active_echo_nodes.size() <= slot:
		active_echo_nodes.append(null)
	if is_instance_valid(active_echo_nodes[slot]):
		active_echo_nodes[slot].die()
	var echo_node = EchoScene.instantiate()
	get_parent().add_child(echo_node)
	echo_node.setup(frames, activation_range > 0.0, slot)
	echo_node.global_position = frames[0]["pos"]
	active_echo_nodes[slot] = echo_node

# REPLACE _on_body_exited with this:
func _on_body_exited(body: Node) -> void:
	if body == player:
		stop_recording()
		if player.has_method("set_echo_zone"):
			player.set_echo_zone(null)
		player = null

func stop_recording() -> void:
	if not is_recording:
		return
	_finish_recording()

func finish_recording_on_death() -> void:
	if not is_recording:
		return
	_finish_recording()
	
	
