#trophy_icon.gd
# A small pixel-art trophy cup, drawn in code so it stays crisp at any size and
# takes any colour (rarity colours, grey while locked). Used by the main menu's
# achievements button, the achievements list and the unlock pop-up.
class_name TrophyIcon
extends Control

## The cup's colour. The shine and shade are worked out from it.
@export var color := Color(1.0, 0.82, 0.35):
	set(c):
		color = c
		queue_redraw()

func _init(size_px := 32.0, tint := Color(1.0, 0.82, 0.35)) -> void:
	custom_minimum_size = Vector2.ONE * size_px
	color = tint
	mouse_filter = Control.MOUSE_FILTER_IGNORE

## Drawn on a 16x16 grid, scaled to fit, centred.
func _draw() -> void:
	var px := floorf(minf(size.x, size.y) / 16.0 * 2.0) / 2.0
	var o := (size - Vector2.ONE * px * 16.0) * 0.5
	var shade := color.darkened(0.35)
	var shine := color.lightened(0.45)
	var outline := Color(0.03, 0.03, 0.06, 0.9)
	var cells := [
		# outline first, one cell bigger all round
		[Rect2(2, 1, 12, 7), outline], [Rect2(0, 2, 3, 6), outline], [Rect2(13, 2, 3, 6), outline],
		[Rect2(4, 7, 8, 3), outline], [Rect2(6, 9, 4, 3), outline], [Rect2(3, 11, 10, 4), outline],
		# handles
		[Rect2(1, 3, 2, 1), shade], [Rect2(1, 3, 1, 3), shade], [Rect2(1, 6, 3, 1), shade],
		[Rect2(13, 3, 2, 1), shade], [Rect2(14, 3, 1, 3), shade], [Rect2(12, 6, 3, 1), shade],
		# cup
		[Rect2(3, 2, 10, 1), shine], [Rect2(4, 3, 8, 4), color], [Rect2(5, 7, 6, 1), color],
		[Rect2(6, 8, 4, 1), shade], [Rect2(10, 3, 2, 4), shade],
		[Rect2(5, 3, 1, 3), shine],
		# stem and base
		[Rect2(7, 9, 2, 2), shade], [Rect2(5, 11, 6, 1), color], [Rect2(4, 12, 8, 2), shade],
		[Rect2(5, 12, 3, 1), color],
	]
	for c in cells:
		var r: Rect2 = c[0]
		draw_rect(Rect2(o + r.position * px, r.size * px), c[1])
