#timed_trap.gd
# Base for traps that loop through a sprite-sheet cycle on the shared clock.
# Every timed trap reads the same clock, so a row of them set with increasing
# `phase` makes a wave that's identical every time the player respawns.
#   cycle_frames  frames in one cycle; each lasts period / cycle_frames
#   deadly_frames frames on which anything overlapping $Hitbox dies
# Subclasses set the frame data and react to frame changes in _on_frame().
extends Node2D

@export var period: float = 2.0     # seconds per cycle
@export var phase: float = 0.0      # 0..1 offset into the cycle

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox

var cycle_frames: int = 1
var deadly_frames: PackedInt32Array = []
var frame := -1

func _ready() -> void:
	sprite.stop()
	_tick()

func _physics_process(_delta: float) -> void:
	_tick()
	if frame in deadly_frames:
		for body in hitbox.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("die") and not body.is_dead:
				body.die()

func _tick() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var f := int(fposmod(t / period + phase, 1.0) * cycle_frames) % cycle_frames
	if f == frame:
		return
	frame = f
	sprite.frame = f
	_on_frame(f)

func _on_frame(_f: int) -> void:
	pass
