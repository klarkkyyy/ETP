# music_manager.gd
extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

var _current_track: String = ""
var _fade_speed: float = 0.2  # how fast volume fades in/out

func _ready() -> void:
	add_child(player)
	player.volume_db = 0.0

func play(track_path: String, fade: bool = true) -> void:
	# Don't restart if same track is already playing
	if _current_track == track_path and player.playing:
		return
	_current_track = track_path
	if fade:
		await _fade_out()
	player.stream = load(track_path)
	player.play()
	if fade:
		_fade_in()

func stop(fade: bool = true) -> void:
	if fade:
		await _fade_out()
	player.stop()
	_current_track = ""

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, _fade_speed)
	await tween.finished

func _fade_in() -> void:
	player.volume_db = -80.0
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -6.0, _fade_speed)
