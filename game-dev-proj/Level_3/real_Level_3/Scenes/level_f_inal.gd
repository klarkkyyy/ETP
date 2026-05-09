extends Area2D

@onready var sprite = $AnimatedSprite2D

# Track if the lever is currently pointing right
var is_pointing_right: bool = false

func _on_body_entered(body: Node2D) -> void:
	# Check if the thing hitting the lever is the player
	if body.name == "player" or body.is_in_group("player"):
		toggle_lever()

func toggle_lever():
	if not is_pointing_right:
		sprite.play("GoingRight")
		is_pointing_right = true
		print("Lever flipped Right")
	else:
		sprite.play("GoingLeft")
		is_pointing_right = false
		print("Lever flipped Left")
