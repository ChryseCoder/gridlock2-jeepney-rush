extends CharacterBody2D

@export var acceleration: float = 40.0
@export var max_speed: float = 150.0
@export var friction: float = 50.0
@export var brake_force: float = 150.0
@export var turn_speed: float = 3.0
@export var drift_factor: float = 0.9
@export var turn_accel: float = 2.0
@export var turn_friction: float = 2.5

var speed: float = 0.0
var turn_velocity: float = 0.0
signal jeepney_stopped(jeepney_node)
var was_moving := false

func _physics_process(delta):
	var input_forward = Input.get_action_strength("accelerate")
	var input_brake = Input.get_action_strength("brake")
	var input_turn = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")

	# 🚀 Acceleration
	if input_forward > 0:
		speed += acceleration * input_forward * delta

	# 🛑 BRAKING
	elif input_brake > 0:
		if speed > 0:
			# braking forward motion
			speed -= brake_force * input_brake * delta
		else:
			# reverse movement (slower)
			speed -= acceleration * 0.4 * input_brake * delta

	# 🧊 Natural friction
	else:
		if speed > 0:
			speed -= friction * delta
		elif speed < 0:
			speed += friction * delta

	# Clamp speed
	speed = clamp(speed, -max_speed * 0.4, max_speed)

	# 🛞 TURNING (with ease)
	if input_turn != 0:
		turn_velocity = lerp(turn_velocity, input_turn * turn_speed, turn_accel * delta)
	else:
		turn_velocity = lerp(turn_velocity, 0.0, turn_friction * delta)

	if abs(speed) > 10:
		rotation += turn_velocity * delta * (speed / max_speed)

	# 🚗 Movement
	var forward = Vector2.UP.rotated(rotation)
	velocity = velocity.lerp(forward * speed, drift_factor)

	move_and_slide()
	
	# 💥 NEW: Collision Impact Logic
	# Check if move_and_slide() registered a hit this frame
	if get_slide_collision_count() > 0:
		# We use the dot product to sync our internal 'speed' with the true physical velocity.
		# If you hit a wall head-on, velocity becomes 0, so speed drops to 0 instantly.
		# If you scrape a wall at an angle, velocity slides along the wall, 
		# and speed perfectly adjusts to match that scraping momentum!
		speed = velocity.dot(forward)
	
	# 🛑 Signal Logic
	if velocity.length() < 10.0:
		if was_moving:
			jeepney_stopped.emit(self) 
			was_moving = false
	else:
		was_moving = true

	# 🎯 Target RPM based on speed
	var speed_ratio = abs(speed) / max_speed
	speed_ratio = clamp(speed_ratio, 0.0, 1.0)
