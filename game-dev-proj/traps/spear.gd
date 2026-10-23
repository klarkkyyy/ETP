#spear.gd
# Fired by spear_launcher.gd. Flies straight until it hits a wall (or has gone
# max_distance), killing the player on contact. Solid echoes (Echoes.solid)
# stop it; in boss fights (Echoes.mortal) the echo dies of it.
extends Area2D

var direction: int = 1
var speed: float = 150.0
var max_distance: float = 900.0
var _travelled := 0.0

func _ready() -> void:
	$Sprite.flip_h = direction < 0
	$Sprite.play("fly")
	body_entered.connect(_on_body_entered)
	if Echoes.solid != Echoes.Solid.OFF:
		collision_mask |= 4   # the echo layer
		area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	var step := speed * delta
	# Areas don't report tilemap walls reliably, so look ahead for one instead
	var from := global_position
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(direction * (step + 4.0), 0), 1)
	if get_world_2d().direct_space_state.intersect_ray(query):
		queue_free()
		return
	position.x += direction * step
	_travelled += step
	if _travelled > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("die") and not body.is_dead:
			body.die()
		queue_free()
	elif not body.is_in_group("echo") and not body.get_parent().is_in_group("echo"):
		queue_free()   # walls, floors, doors (an echo's body is handled below)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("echo") and area.get("_is_active"):
		if Echoes.mortal:
			area.die()
		queue_free()
