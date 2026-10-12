#trap_door.gd
# A 2-tile hinged floor panel that swings open on a cycle and drops whatever
# stands on it, usually into spikes. It creaks open on frames 6-11; the panel is
# solid on every other frame. Place its origin on the floor surface, centred.
extends "res://traps/timed_trap.gd"

const OPEN := [6, 7, 8, 9, 10, 11]

func _ready() -> void:
	cycle_frames = 14
	super._ready()

func _on_frame(f: int) -> void:
	$Panel/Shape.set_deferred("disabled", f in OPEN)
