extends Area2D

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

func _ready():
	uses_left = max_uses

func activate_trap():
	# 1. If it's broken, stop immediately
	if is_broken:
		print("Trap is broken!")
		return
	
	# 2. If it's still recharging, stop immediately
	if recharge_timer > 0:
		print("Trap is recharging: ", snapped(recharge_timer, 0.1), "s remaining")
		return
		
	# 3. Play animation
	is_active = true
	sprite.stop() 
	sprite.frame = 0 
	sprite.play("default")
	print("Trap Spiking! Uses remaining: ", uses_left)

func deactivate_trap():
	# If it's already broken, don't start a recharge timer
	if is_broken:
		is_active = false
		return

	is_active = false
	sprite.stop()
	sprite.frame = 0
	damage_timer = 0.0
	
	# ONLY start recharge if we have uses left and aren't already recharging
	if uses_left > 0 and recharge_timer <= 0:
		recharge_timer = recharge_time
		print("5 second recharge started...")
		
		
		
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
