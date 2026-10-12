#spear_launcher.gd
# A launcher set into a wall that fires a spear on a cycle. The spear flies until
# it hits a wall and kills the player on contact; echoes are unharmed. Like the
# other timed traps it runs off the shared clock: set `phase` to stagger a bank
# of launchers. Mount it on the wall face with `facing` pointing into the room.
extends "res://traps/timed_trap.gd"

const SPEAR_SCENE = "res://traps/spear.tscn"
const SFX_FIRE = "res://audio/sfx/woosh.mp3"
const FIRE_FRAME := 5

@export var facing: int = 1            # 1 fires right, -1 fires left
@export var spear_speed: float = 150.0

func _ready() -> void:
	# the sheet's 7 frames are the shot; idle on frame 0 for the rest of the cycle
	cycle_frames = 28
	sprite.flip_h = facing < 0
	super._ready()

func _tick() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var f := int(fposmod(t / period + phase, 1.0) * cycle_frames) % cycle_frames
	if f == frame:
		return
	frame = f
	sprite.frame = f if f < 7 else 0
	if f == FIRE_FRAME and is_node_ready():
		_fire()

func _fire() -> void:
	var s: Node2D = load(SPEAR_SCENE).instantiate()
	s.direction = facing
	s.speed = spear_speed
	s.position = position + Vector2(8 * facing, 0)   # same parent, same space
	# deferred: the level may still be adding its children when a shot is due
	get_parent().add_child.call_deferred(s)
	if $Notifier.is_on_screen():
		SoundManager.play(SFX_FIRE, -16, 1.6)
