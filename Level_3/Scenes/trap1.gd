extends Area2D

@onready var sprite = $AnimatedSprite2D

var is_active: bool = false

func _ready():
	sprite.stop()
	sprite.frame = 0 # Start on the "flat" hidden frame

func activate_trap():
	is_active = true
	sprite.play("default") 
	print("STEP 3: Trap Spiking!")

func deactivate_trap():
	is_active = false
	sprite.stop()
	sprite.frame = 0 # Returns the spikes to the hidden/flat frame
	print("STEP 3: Trap Retracting!")

func _on_body_entered(body):
	if is_active and body.name == "Boss":
		if body.has_method("die"):
			body.die()

func _on_pressure_pad_pad_activated() -> void:
	pass # Replace with function body.
