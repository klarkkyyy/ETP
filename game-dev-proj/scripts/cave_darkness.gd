# cave_darkness.gd — the dark stretch of Level 11 (The Dark Seam).
# darkness.gd with three changes:
#   - the zone is given relative to the level (`local_zone`, px), since the
#     level sits somewhere in game.tscn;
#   - every playing echo carries a lantern-sized light while it's dark, so an
#     echo sent ahead lights the way (Ren's own light is deliberately small);
#   - hazards listed in `glows` get a faint red glow so they stay readable.
# The echo lights live in a holder of their own and follow the echoes: as
# children of an echo they'd pick up its faded, tinted modulate and barely
# show. Put this node as a child of a Node2D in the level.
extends "res://scripts/darkness.gd"

@export var local_zone: Rect2
@export var echo_light_color: Color = Color(0.75, 0.88, 1.0)
@export var echo_light_size: float = 1.6
@export var echo_light_energy: float = 1.3

const STRANGER = preload("res://story/stranger.gd")

var _holder: Node2D
var _lights := {}   # echo -> PointLight2D


func _ready() -> void:
	var root := get_parent() as Node2D
	zone = Rect2(root.global_position + local_zone.position, local_zone.size)
	_holder = Node2D.new()
	_holder.top_level = true
	root.add_child.call_deferred(_holder)
	super._ready()


func _process(delta: float) -> void:
	super._process(delta)
	if not _holder.is_inside_tree():
		return
	var t := smoothstep(0.0, 1.0, _dark)
	for e in get_tree().get_nodes_in_group("echo"):
		if not _lights.has(e):
			var light := STRANGER.glow_light(echo_light_color, echo_light_size, echo_light_energy)
			_holder.add_child(light)
			_lights[e] = light
	for e in _lights.keys():
		var light: PointLight2D = _lights[e]
		if not is_instance_valid(e) or e.get("_dying"):
			light.queue_free()
			_lights.erase(e)
			continue
		light.global_position = (e as Node2D).global_position + Vector2(0, -4)
		light.energy = echo_light_energy * t * (1.0 if e.get("_is_active") else 0.0)
		light.visible = light.energy > 0.001
