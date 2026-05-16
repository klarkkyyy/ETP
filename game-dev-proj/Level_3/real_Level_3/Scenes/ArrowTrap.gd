extends Area2D

const ArrowScene = preload("res://scenes/arrow.tscn")

@onready var sprite = $AnimatedSprite2D
@export var damage_amount: float = 20.0
@export var damage_cooldown: float = 0.6
@export var max_uses: int = 2 # Trap only works twice
@export var recharge_time: float = 5.0 # 5 seconds between uses

var is_active: bool = false
var damage_timer: float = 0.0
var uses_left: int = 2
var recharge_timer: float = 0.0
var is_broken: bool = false

@export var arrow_direction: Vector2 = Vector2.RIGHT  # set per trap in inspector
@onready var spawn_point: Marker2D = $Marker2D

func _ready():
	uses_left = max_uses
	

func activate_trap():
	if is_broken:
		print("Trap is broken!")
		return
	if recharge_timer > 0:
		print("Trap is still recharging: ", snapped(recharge_timer, 0.1), "s remaining")
		return
		
	is_active = true
	sprite.stop()
	sprite.frame = 0
	sprite.play("default")

	print("Arrow spawn node: ", spawn_point)
	print("Arrow direction set to: ", arrow_direction.normalized())

	if spawn_point and ArrowScene:
		var arrow = ArrowScene.instantiate()
		arrow.direction = arrow_direction.normalized()
		get_parent().add_child(arrow)
		arrow.global_position = spawn_point.global_position
		print("Arrow spawned at: ", arrow.global_position)
	else:
		print("FAILED — spawn_point: ", spawn_point, " | ArrowScene: ", ArrowScene)

func deactivate_trap():
	is_active = false
	sprite.stop()     
	sprite.frame = 0
	damage_timer = 0.0
	
	# Start the 5-second recharge cooldown
	if not is_broken and uses_left > 0:
		recharge_timer = recharge_time
		print("Trap deactivated. 5 second recharge started...")

func _physics_process(delta: float):
	# Handle the 5-second recharge timer
	if recharge_timer > 0:
		recharge_timer -= delta
		# Visual feedback: make the trap slightly transparent while recharging
		sprite.modulate.a = 0.5 
	else:
		if not is_broken:
			sprite.modulate.a = 1.0 # Fully visible when ready

	if not is_active or is_broken:
		return
		
	# Handle internal damage ticking (if boss stands on it)
	if damage_timer > 0:
		damage_timer -= delta
		return

	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.name == "Boss" or body.is_in_group("boss"):
			if body.has_method("take_damage"):
				body.take_damage(damage_amount)
				damage_timer = damage_cooldown 
				
				# Count this as one use
				uses_left -= 1
				
				if uses_left <= 0:
					_break_trap()

func _break_trap():
	is_broken = true
	is_active = false
	sprite.stop()
	sprite.frame = 0
	sprite.modulate = Color(0.3, 0.3, 0.3) # Darken to show it's dead
	print("Trap is now PERMANENTLY disabled.")

func on_echo_enter(echo: Area2D) -> void:
	activate_trap()

func on_echo_exit(echo: Area2D) -> void:
	pass


func _on_arrow_button_pad_activated() -> void:
	activate_trap()


func _on_arrow_button_2_pad_activated() -> void:
	activate_trap()


func _on_arrow_button_3_pad_activated() -> void:
	activate_trap()
