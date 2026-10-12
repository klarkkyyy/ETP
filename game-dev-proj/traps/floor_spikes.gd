#floor_spikes.gd
# One tile of spikes that rise out of the floor and sink back on a cycle.
# Frames 6-7 poke up as a warning, 8-11 are deadly, then they sink.
# Place it with its origin on the floor surface, centred on the tile.
extends "res://traps/timed_trap.gd"

func _ready() -> void:
	cycle_frames = 15
	deadly_frames = PackedInt32Array([8, 9, 10, 11])
	super._ready()
