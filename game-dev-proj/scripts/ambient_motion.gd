extends Node2D
## Endless decorative motion for background pieces (no collision, no gameplay):
## SPIN turns at `speed` rad/s, SWING rocks around this node like a pendulum
## (`amount` rad either way), BOB rises and falls `amount` px. One cycle of a
## swing or bob takes `period` seconds; `phase` (0-1) staggers neighbours.

enum Mode { SPIN, SWING, BOB }

@export var mode := Mode.SPIN
@export var speed := 0.1
@export var amount := 0.3
@export var period := 6.0
@export_range(0.0, 1.0) var phase := 0.0

var _rest: Vector2
var _t := 0.0

func _ready() -> void:
	_rest = position
	_t = phase * period

func _process(delta: float) -> void:
	_t += delta
	match mode:
		Mode.SPIN:
			rotation = wrapf(rotation + speed * delta, -PI, PI)
		Mode.SWING:
			rotation = amount * sin(TAU * _t / period)
		Mode.BOB:
			position.y = _rest.y + amount * sin(TAU * _t / period)
