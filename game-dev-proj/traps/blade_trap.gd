#blade_trap.gd
# A spinning blade on a chain - the "rotating spike".
#   ORBIT     the blade circles the pivot (blades > 1 spreads several evenly)
#   PENDULUM  the blade swings back and forth under the pivot
#   LINE      the blade slides back and forth from the pivot to pivot + travel
# Touching a blade kills the player. Echoes and enemies pass through unharmed.
# Every blade runs off the same clock, so a row of them keeps its rhythm and a
# player who learns a pattern can rely on it after a respawn.
extends Node2D

enum Mode { ORBIT, PENDULUM, LINE }

@export var mode: Mode = Mode.ORBIT
@export var radius: float = 48.0            # chain length (ORBIT, PENDULUM)
@export var speed_deg: float = 90.0         # ORBIT: degrees per second, negative = anticlockwise
@export var blades: int = 1                 # ORBIT: blades spread evenly round the pivot
@export var swing_deg: float = 60.0         # PENDULUM: swing either side of straight down
@export var period: float = 2.0             # PENDULUM, LINE: seconds for a full back-and-forth
@export var travel: Vector2 = Vector2(96, 0)  # LINE: far end, relative to the pivot
@export var phase: float = 0.0              # 0..1, offset into the cycle
@export var rod_up: float = 0.0             # draws a rod from the pivot up to its mount (px)

@onready var blade_template: Area2D = $Blade
@onready var chain_template: Line2D = $Chain

var _blades: Array[Area2D] = []
var _chains: Array[Line2D] = []

func _ready() -> void:
	if rod_up > 0.0:
		$Rod.points = PackedVector2Array([Vector2.ZERO, Vector2(0, -rod_up)])
	else:
		$Rod.visible = false
	_blades.append(blade_template)
	_chains.append(chain_template)
	var count := blades if mode == Mode.ORBIT else 1
	for i in range(1, count):
		var b := blade_template.duplicate() as Area2D
		add_child(b)
		_blades.append(b)
		var c := chain_template.duplicate() as Line2D
		add_child(c)
		move_child(c, 0)
		_chains.append(c)
	for b in _blades:
		b.body_entered.connect(_on_body_entered)
		(b.get_node("Sprite") as AnimatedSprite2D).play("spin")
	if mode == Mode.LINE:
		for c in _chains:
			c.visible = false
	_update()

func _physics_process(_delta: float) -> void:
	_update()
	for b in _blades:
		for body in b.get_overlapping_bodies():
			_on_body_entered(body)

func _update() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in _blades.size():
		var p := _blade_pos(t, i)
		_blades[i].position = p
		_chains[i].points = PackedVector2Array([Vector2.ZERO, p])

func _blade_pos(t: float, i: int) -> Vector2:
	match mode:
		Mode.ORBIT:
			var a := deg_to_rad(speed_deg * t + phase * 360.0 + 360.0 * i / maxi(blades, 1))
			return Vector2(0, radius).rotated(a)
		Mode.PENDULUM:
			var a := deg_to_rad(swing_deg) * sin(TAU * (t / period + phase))
			return Vector2(0, radius).rotated(a)
		_:
			var k := 0.5 - 0.5 * cos(TAU * (t / period + phase))   # eases at each end
			return travel * k

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("die") and not body.is_dead:
		body.die()
