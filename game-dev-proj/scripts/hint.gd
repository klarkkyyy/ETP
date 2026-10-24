#hint.gd
# A tutorial prompt that keeps out of the way: hidden unless Ren seems stuck.
# It fades in once he has spent `delay` seconds in `zone` (in control, alive)
# and fades out when he leaves it, so a player who works it out never sees
# it, and one who needs the controls gets them. Put it on the prompt's node.
extends Node2D

## Where Ren has to be (world coordinates) for the stuck time to count.
@export var zone: Rect2
@export var delay: float = 4.0
## Only once this echo slot is unlocked (0 = always).
@export var requires_echo: int = 0
## Only once Ren has recorded an echo (a slot is spent).
@export var requires_recorded: bool = false

const FADE_TIME = 0.8

var _stuck := 0.0

func _ready() -> void:
	modulate.a = 0.0
	# readable in the dark outside (darkness.gd)
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unshaded
	for c in find_children("*", "CanvasItem", true, false):
		if c.material == null:
			c.use_parent_material = true

func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as CharacterBody2D
	var inside := p != null and zone.has_point(p.global_position) and _counts(p)
	if inside:
		_stuck += delta
	var want := 1.0 if inside and _stuck >= delay else 0.0
	modulate.a = move_toward(modulate.a, want, delta / FADE_TIME)

func _counts(p: CharacterBody2D) -> bool:
	if p.get("is_dead") or p.get("controls_locked") or not p.is_physics_processing():
		return false   # a cutscene or the title has him
	if requires_echo > 0 and not GameManager.is_echo_unlocked(requires_echo):
		return false
	if requires_recorded and not (Echoes.is_spent(0) or Echoes.is_spent(1) or Echoes.is_spent(2)):
		return false
	return true
