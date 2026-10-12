#crusher.gd
# A 3-tile-wide stone slab set in the ceiling that slams down 4 tiles and winches
# back up on a cycle. It flashes for a few frames before it drops. Hang it with
# its origin on the ceiling underside, centred on its 3 tiles, over a corridor
# exactly 4 tiles tall so the slab meets the floor.
extends "res://traps/timed_trap.gd"

const SFX_SLAM = "res://audio/sfx/stone_door_close.mp3"
# how far the slab reaches below the ceiling on each frame of the sheet
const REACH := [8, 8, 8, 8, 8, 8, 8, 8, 8, 16, 56, 64, 64, 64, 64, 64, 64, 48, 32, 16]

func _ready() -> void:
	cycle_frames = 20
	deadly_frames = PackedInt32Array([10, 11, 12, 13, 14, 15, 16, 17])
	super._ready()

func _on_frame(f: int) -> void:
	var shape := ($Hitbox/Shape as CollisionShape2D).shape as RectangleShape2D
	var reach: float = REACH[f]
	shape.size = Vector2(44, reach - 2)
	$Hitbox/Shape.position = Vector2(0, reach * 0.5)
	if f == 11 and _on_screen():
		SoundManager.play(SFX_SLAM, -14, 1.4)

func _on_screen() -> bool:
	return $Notifier.is_on_screen()
