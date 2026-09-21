extends CharacterBody2D

# --- Vehicle Properties ---
@export var engine_power: float = 300.0
@export var max_speed: float = 1000.0
@export var braking_power: float = 1200.0
@export var friction: float = 1.0

# --- Steering & Handling Properties ---
@export var steering_speed: float = 2.5
@export var wheel_turn_speed: float = 4.0 
# Increased traction for that planted AWD feel
@export var traction: float = 8.0 

var current_speed: float = 0.0
var current_steering_input: float = 0.0 

func _physics_process(delta: float) -> void:
	# 1. Get Player Input
	var target_turn_input = Input.get_axis("ui_left", "ui_right")
	var drive_input = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up") 

	# 2. Smooth the Steering 
	current_steering_input = move_toward(current_steering_input, target_turn_input, wheel_turn_speed * delta)

	# 3. Acceleration & Braking
	if drive_input < 0:
		current_speed += engine_power * delta
	elif drive_input > 0:
		current_speed -= braking_power * delta
	else: 
		current_speed = move_toward(current_speed, 0, friction * engine_power * delta)

	current_speed = clamp(current_speed, -max_speed / 2.0, max_speed)

	# 4. Speed-Dependent Steering (Fixes the low-speed spinning)
	if abs(current_speed) > 10.0:
		# We scale the rotation by how fast the Jeepney is moving.
		var speed_factor = abs(current_speed) / (max_speed * 0.5)
		# Clamp prevents the car from losing all steering at low speeds, 
		# while keeping the turn radius realistic.
		speed_factor = clamp(speed_factor, 0.2, 1.0) 
		
		rotation += current_steering_input * steering_speed * speed_factor * delta * sign(current_speed)

	# 5. AWD Traction Model (The Dot Product Method)
	var forward = transform.x # The direction the hood is pointing
	var lateral = transform.y # The side of the Jeepney (orthogonal)
	
	# We measure how much of the current physical velocity is sliding sideways
	var lateral_velocity = lateral * velocity.dot(lateral)
	
	# AWD vehicles have massive grip, so we aggressively reduce the sideways slide to zero
	lateral_velocity = lateral_velocity.lerp(Vector2.ZERO, traction * delta)
	
	# The final velocity is our engine pushing forward, plus whatever minor slide is left
	velocity = (forward * current_speed) + lateral_velocity
	
	move_and_slide()
	resolve_collisions()

func resolve_collisions() -> void:
	if get_slide_collision_count() > 0:
		current_speed *= 0.2
