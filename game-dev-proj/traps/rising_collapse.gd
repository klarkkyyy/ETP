# rising_collapse.gd — the shaft caving in under you (Level 11's last climb).
# Works exactly like rising_flood.gd (start(), rises at rise_speed, kills Ren
# below its edge, backs off reset_gap under his respawn and waits `grace`),
# but it's rubble, not water: a jagged edge of broken rock with grit
# spilling off it, and a rumble.
extends "res://traps/rising_flood.gd"

const RUBBLE = Color(0.3, 0.16, 0.17)
const RUBBLE_EDGE = Color(0.5, 0.29, 0.28)

var _edge: Polygon2D
var _rim: Line2D
var _grit: CPUParticles2D


func _ready() -> void:
	super._ready()
	z_index = -11   # over the wall scratches and decor (same z, later in the tree), still behind the walls (-10)
	_body.color = RUBBLE
	_surf.visible = false
	_edge = Polygon2D.new()
	_edge.color = RUBBLE
	add_child(_edge)
	_rim = Line2D.new()
	_rim.width = 2.0
	_rim.default_color = RUBBLE_EDGE
	add_child(_rim)
	var pts := PackedVector2Array()
	var rim := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var x := 0.0
	while x <= width:
		var p := Vector2(x, rng.randf_range(-10.0, 2.0))
		pts.append(p)
		rim.append(p)
		x += rng.randf_range(6.0, 14.0)
	pts.append(Vector2(width, 12))
	pts.append(Vector2(0, 12))
	_edge.polygon = pts
	_rim.points = rim
	_grit = CPUParticles2D.new()
	_grit.amount = 24
	_grit.lifetime = 0.9
	_grit.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_grit.emission_rect_extents = Vector2(width * 0.5, 2)
	_grit.position = Vector2(width * 0.5, 0)
	_grit.direction = Vector2(0, -1)
	_grit.spread = 35.0
	_grit.gravity = Vector2(0, 300)
	_grit.initial_velocity_min = 40.0
	_grit.initial_velocity_max = 110.0
	_grit.scale_amount_min = 1.0
	_grit.scale_amount_max = 2.5
	_grit.color = Color(0.55, 0.36, 0.33, 0.9)
	add_child(_grit)
	_place()


func _process(_delta: float) -> void:
	pass  # (the water's drifting surface texture isn't used)


func _place() -> void:
	super._place()
	if _edge:
		_edge.position = Vector2(0, surface)
		_rim.position = Vector2(0, surface)
		_grit.position.y = surface - 4
		_grit.emitting = rising
