# music_manager.gd
extends Node

@onready var player: AudioStreamPlayer = AudioStreamPlayer.new()

var _current_track: String = ""
var _fade_speed: float = 0.2  # how fast volume fades in/out

func _ready() -> void:
	add_child(player)
	player.volume_db = -80

func play(track_path: String, fade: bool = true, target_db: float = -6.0) -> void:
	print("MusicManager.play called | track: ", track_path, " | current: ", _current_track, " | playing: ", player.playing)
	if _current_track == track_path and player.playing:
		print("Skipping — same track already playing")
		return
	_current_track = track_path
	if fade:
		await _fade_out()
	player.stream = load(track_path)
	player.play()
	if fade:
		_fade_in(target_db)

func stop(fade: bool = true) -> void:
	if fade:
		await _fade_out()
	player.stop()
	_current_track = ""

func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_property(player, "volume_db", -80.0, _fade_speed)
	await tween.finished

func _fade_in(target_db: float = -25.0) -> void:
	player.volume_db = -80.0
	var tween = create_tween()
	tween.tween_property(player, "volume_db", target_db, _fade_speed)

func reset() -> void:
	_current_track = ""
	player.stop()
