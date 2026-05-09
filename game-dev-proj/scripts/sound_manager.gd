# sound_manager.gd
extends Node

# ── Sound players ────────────────────────────────────────────────────────────
var _players: Dictionary = {}

func _ready() -> void:
	pass

func play(sound_path: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not ResourceLoader.exists(sound_path):
		print("SoundManager: file not found — ", sound_path)
		return
	var player = AudioStreamPlayer.new()
	add_child(player)
	player.stream = load(sound_path)
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()
	player.finished.connect(player.queue_free)
