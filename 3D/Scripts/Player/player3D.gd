extends CharacterBody3D

@export_group("Movement Stats")
@export var acceleration: float = 15.0
@export var friction: float = 10.0
@export var brake_force: float = 30.0
@export var turn_speed: float = 3.5
@export var drift_factor: float = 0.95

@export_group("Fuel")
@export var max_fuel: float = 100.0
@export var fuel_drain_rate: float = 1

@export_group("Turning Dynamics")
@export var turn_accel: float = 10.0
@export var turn_friction: float = 10.0

@export_group("Gearbox")
@export var gear_top_speeds_kmh: Array[float] = [20, 40, 60, 80, 220]  # actual km/h cap per gear
@export var gear_accel_mult: Array[float] = [1, 0.5, 0.4, 0.3, 0.2]

@export_group("Passenger")
@onready var boarding_point: Marker3D = $BoardingPoint
@export var passenger_scene: PackedScene
var passenger_count: int = 0

var current_gear: int = 1

var gear_speed_caps: Array[float] = []   # m/s, computed from gear_top_speeds_kmh
var max_speed: float = 0.0               # derived: top speed of highest gear

var speed: float = 0.0
var fuel: float = max_fuel
var turn_velocity: float = 0.0


func _ready() -> void:
	add_to_group("player")
	for kmh in gear_top_speeds_kmh:
		gear_speed_caps.append(kmh / 3.6)
	max_speed = gear_speed_caps[gear_speed_caps.size() - 1]
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("gear_up"):
		current_gear = min(current_gear + 1, gear_speed_caps.size())
	elif event.is_action_pressed("gear_down"):
		current_gear = max(current_gear - 1, 1)

func _physics_process(delta: float) -> void:
	var input_forward = Input.get_action_strength("accelerate")
	var input_brake = Input.get_action_strength("brake")
	var input_turn = Input.get_action_strength("steer_right") - Input.get_action_strength("steer_left")
		
	if speed < 0: current_gear = 1
	
	# --- Fuel drain ---
	if fuel > 0:
		fuel -= fuel_drain_rate * input_forward * delta
		fuel = max(fuel, 0.0)

	# --- Out of fuel: force a dead stop ---
	if fuel <= 0:
		input_forward = 0.0
		speed = 0.0
	
	# --- Acceleration ---
	if input_forward > 0:
		var gear_cap: float = gear_speed_caps[current_gear - 1]
		var gear_accel: float = acceleration * gear_accel_mult[current_gear - 1]
		
		if speed < gear_cap:
			# Normal acceleration up toward this gear's cap
			speed += gear_accel * input_forward * delta
			speed = min(speed, gear_cap)
			
		elif speed > gear_cap:
			# Over the cap (just downshifted) - engine braking pulls speed down
			speed-= brake_force * 0.3 * delta # tweak this multiplier for how fast the slow down when downshifting
			speed = max(speed, gear_cap)

	# --- Braking & Reverse ---
	elif input_brake > 0:
		if speed > 0:
			# Braking forward motion
			speed -= brake_force * input_brake * delta 
		else:
			# Reverse movement (slower)
			speed -= acceleration * 0.4 * input_brake * delta 

	# --- Natural Friction ---
	else:
		if speed > 0:
			speed -= friction * 0.2 * delta
		elif speed < 0:
			speed += friction * 0.2 * delta

	# Clamp max and reverse speeds
	speed = clamp(speed, -max_speed * 0.4, max_speed)

	# --- Turning (Responsive) ---
	if input_turn != 0:
		turn_velocity = lerp(turn_velocity, input_turn * turn_speed, turn_accel * delta)
	else:
		turn_velocity = lerp(turn_velocity, 0.0, turn_friction * delta)

	#only turns when accelerating
	if abs(speed) > 0.5:
	# We create a turn_ratio so turning feels responsive at medium speeds,
	# but doesn't get wildly sensitive at maximum speed.
		var turn_ref_speed = 5.5 
		var turn_ratio = clamp(abs(speed) / turn_ref_speed, 0.5, 1.0)
		turn_ratio = sqrt(turn_ratio)
	# Adding sign(speed) ensures the vehicle steers correctly when driving in reverse!
		rotation.y -= turn_velocity * delta * turn_ratio * sign(speed)

	# --- Movement & Drift ---
	# Calculate forward direction along the ground in 3D space
	var forward = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	
	# Lerp the velocity towards the target forward speed for drifting
	velocity = velocity.lerp(forward * speed, drift_factor)
	
	# Ensure the Y-axis remains 0 so the player stays flat on the ground
	velocity.y = 0.0 

	move_and_slide()

func add_passenger():
	passenger_count += 1
	print("Passenger boarded! Total passengers: ", passenger_count)

func release_passenger(destination: Node3D):
	if passenger_count <= 0:
		return

	var passenger = passenger_scene.instantiate()

	get_tree().current_scene.add_child(passenger)

	passenger.global_position = $PassengerExitPoint.global_position
	passenger.walk_to_destination(destination.entry_point.global_position)

	passenger_count -= 1

	print("Passenger released! Remaining passengers: ", passenger_count)
