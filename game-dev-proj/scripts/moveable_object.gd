# moveable_object.gd
extends RigidBody2D

@export var push_force: float = 80.0        # Force applied per frame while player pushes
@export var max_push_velocity: float = 40.0  # Max speed while being pushed
@export var ground_linear_damp: float = 8.0  # High damp = heavy/sluggish feel
@export var mass_feel: float = 10.0          # Set this in Inspector too on the RigidBody2D

var is_being_pushed: bool = false
var push_direction: float = 0.0

func _ready() -> void:
	add_to_group("moveable")
	lock_rotation = true
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	mass = mass_feel
	linear_damp = ground_linear_damp

func receive_push(direction: float) -> void:
	is_being_pushed = true
	push_direction = direction

func _physics_process(_delta: float) -> void:
	if is_being_pushed:
		# Only push if under speed cap
		if abs(linear_velocity.x) < max_push_velocity:
			apply_central_force(Vector2(push_direction * push_force, 0))
		# Clamp so it never exceeds cap even from residual force
		linear_velocity.x = clamp(linear_velocity.x, -max_push_velocity, max_push_velocity)

	is_being_pushed = false  # Reset each frame; player must re-signal it

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Strong damping when not being pushed, lighter when pushed (so force has effect)
	if is_being_pushed:
		state.linear_velocity.x *= 0.90   # Some drag even while pushing
	else:
		state.linear_velocity.x *= 0.75   # Heavier drag when released — stops sluggishly
	state.linear_velocity.y = state.linear_velocity.y  # Don't touch vertical (gravity handles it)
