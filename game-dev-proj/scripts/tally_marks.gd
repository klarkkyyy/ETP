# tally_marks.gd — scratched tallies on a cave wall (Level 11, The Tally).
# Fills `size` with rows of four strokes and a slash, slightly uneven, as if
# scratched by hand over a very long time: older ones fainter. Purely
# decoration; draws behind the level's walls.
@tool
extends Node2D

@export var size := Vector2(176, 96):
	set(v):
		size = v
		queue_redraw()
@export var seed_value: int = 11
@export var color := Color(0.86, 0.74, 0.7)


func _ready() -> void:
	z_index = -11


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var y := 4.0
	while y + 14.0 <= size.y:
		var x := 4.0 + rng.randf_range(0.0, 6.0)
		while x + 14.0 <= size.x:
			if rng.randf() < 0.86:   # a few gaps, where the rock flaked off
				_group(Vector2(x, y), rng)
			x += 18.0 + rng.randf_range(-2.0, 3.0)
		y += 18.0 + rng.randf_range(-1.0, 2.0)


## Four strokes and a slash through them.
func _group(at: Vector2, rng: RandomNumberGenerator) -> void:
	var c := color
	c.a = rng.randf_range(0.18, 0.55)
	var strokes := 4 if rng.randf() < 0.95 else rng.randi_range(1, 3)
	for i in strokes:
		var x := at.x + i * 3.0 + rng.randf_range(-0.6, 0.6)
		draw_line(Vector2(x + rng.randf_range(-1, 1), at.y), Vector2(x, at.y + 12.0 + rng.randf_range(-1, 1)), c, 1.0)
	if strokes == 4:
		draw_line(at + Vector2(-2, 10 + rng.randf_range(-1, 1)), at + Vector2(12, 2 + rng.randf_range(-1, 1)), c, 1.0)
