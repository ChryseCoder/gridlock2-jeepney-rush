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
const REFUEL_STOP_EPSILON: float = 0.01

@export_group("Turning Dynamics")
@export var turn_accel: float = 10.0
@export var turn_friction: float = 10.0

@export_group("Gearbox")
@export var gear_top_speeds_kmh: Array[float] = [20, 40, 60, 80, 220]  # actual km/h cap per gear
@export var gear_accel_mult: Array[float] = [1, 0.5, 0.4, 0.3, 0.2]

@export_group("Passenger")
@onready var boarding_point: Marker3D = $BoardingPoint
@export var passenger_scene: PackedScene
@export var arrow_scene: PackedScene
@export var arrow_container: Control

@export_group("Collision Dialogue")
@export_range(0.0, 10.0, 0.5) var collision_dialogue_cooldown: float = 4.0

const COLLISION_REACTION_LINES: Array[String] = [
	"Dahan-dahan naman, manong!",
	"Ano ba 'yan, manong?",
	"Ingat naman po!",
	"Manong, may pasahero kayo!"
]

var _collision_dialogue_time_left: float = 0.0
var _was_touching_obstacle: bool = false

var passengers: Array[Dictionary] = []
var destination_arrows: Dictionary = {}
var passenger_count: int = 0

var current_gear: int = 1

var gear_speed_caps: Array[float] = []   # m/s, computed from gear_top_speeds_kmh
var max_speed: float = 0.0               # derived: top speed of highest gear

var speed: float = 0.0
var fuel: float = max_fuel
var turn_velocity: float = 0.0
var locked_y: float

func _ready() -> void:
	add_to_group("player")
	for kmh in gear_top_speeds_kmh:
		gear_speed_caps.append(kmh / 3.6)
	max_speed = gear_speed_caps[gear_speed_caps.size() - 1]
	locked_y = global_position.y
	
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
	
	_try_refuel(delta)
	
	# --- Fuel drain ---
	if fuel > 0:
		fuel -= fuel_drain_rate * input_forward * delta
		fuel = max(fuel, 0.0)

	# --- Out of fuel: force a dead stop ---
	if fuel <= 0:
		input_forward = 0.0
		speed = 0.0
		
		var mission_manager = get_tree().get_first_node_in_group("MissionManager")
		
		if mission_manager:
			mission_manager.fail_mission()
	
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
		speed = move_toward(speed, 0.0, friction * 0.2 * delta)

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

	# --- Movement & Collision ---
	var forward = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))

	velocity = velocity.lerp(forward * speed, drift_factor)
	velocity.y = 0.0

	# Save velocity before collision response modifies it.
	var velocity_before_move = velocity

	move_and_slide()

	# Calculate how strongly the Jeepney hit an obstacle.
	var strongest_impact: float = 0.0
	var touching_obstacle: bool = false

	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()

		# Ignore vertical collision components.
		normal.y = 0.0

		if normal.length_squared() > 0.001:
			touching_obstacle = true
			normal = normal.normalized()

			var impact = -velocity_before_move.dot(normal)
			strongest_impact = maxf(strongest_impact, impact)

	# Reduce the Jeepney's actual driving speed after impact.
	if strongest_impact > 0.1:
		var remaining_speed = maxf(
			abs(speed) - strongest_impact,
			0.0
		)
		speed = signf(speed) * remaining_speed

	# Apply one penalty when a new obstacle contact begins.
	if strongest_impact > 0.1 and touching_obstacle and not _was_touching_obstacle:
		var mission_timer = get_tree().get_first_node_in_group(
			"MissionTimer"
		)

		if mission_timer:
			mission_timer.apply_penalty(&"collision")

	_update_collision_dialogue(strongest_impact, touching_obstacle, delta)

	# Keep the Jeepney at its original height.
	global_position.y = locked_y


func _update_collision_dialogue(
	impact: float,
	touching_obstacle: bool,
	delta: float
) -> void:
	_collision_dialogue_time_left = maxf(
		_collision_dialogue_time_left - delta,
		0.0
	)

	# One reaction per contact, not every physics frame against a wall.
	var new_collision := touching_obstacle and not _was_touching_obstacle
	_was_touching_obstacle = touching_obstacle

	if not new_collision or impact <= 0.1:
		return

	if passengers.is_empty() or _collision_dialogue_time_left > 0.0:
		return

	_collision_dialogue_time_left = collision_dialogue_cooldown

	# Equal probability for either line, regardless of passenger count.
	var lines: Array[String] = [
		COLLISION_REACTION_LINES.pick_random()
	]

	var screen_size := get_viewport().get_visible_rect().size
	var dialog_position := Vector2(
		screen_size.x / 2.0,
		screen_size.y - 120.0
	)

	DialogueManager.start_dialog(dialog_position, lines)


func add_passenger(destination_id: StringName, appearance: Dictionary, is_mission_passenger: bool):
	var arrow = null

	if destination_arrows.has(destination_id):
		arrow = destination_arrows[destination_id]
	else:
		if arrow_scene != null and arrow_container != null:
			arrow = arrow_scene.instantiate()
			arrow_container.add_child(arrow)
			arrow.set_destination(destination_id, self)

			destination_arrows[destination_id] = arrow

	passengers.append({
		"destination_id": destination_id,
		"appearance": appearance,
		"is_mission_passenger": is_mission_passenger
	})

	passenger_count = passengers.size()
	update_destination_activation()

	print("Passenger boarded for: ", destination_id)
	print("Total passengers: ", passenger_count)

var is_releasing_passengers: bool = false

func release_passengers(destination: Node3D):
	if is_releasing_passengers:
		return

	is_releasing_passengers = true

	var index := 0

	while index < passengers.size():
		var passenger_data = passengers[index]

		if passenger_data["destination_id"] == destination.destination_id:
			var passenger = passenger_scene.instantiate()
			passenger.is_mission_passenger = passenger_data["is_mission_passenger"]
			get_tree().current_scene.add_child(passenger)

			passenger.global_position = $PassengerExitPoint.global_position

			passenger.get_node("PassengerVisual").set_appearance(
				passenger_data["appearance"]
			)

			passenger.walk_to_destination(
				destination.entry_point.global_position
			)
			
			passengers.remove_at(index)
			passenger_count = passengers.size()

			print("Passenger released! Remaining passengers: ", passenger_count)

			await get_tree().create_timer(0.6).timeout

		else:
			index += 1
	
	var still_has_destination := false

	for passenger_data in passengers:
		if passenger_data["destination_id"] == destination.destination_id:
			still_has_destination = true
			break

	if not still_has_destination:
		if destination_arrows.has(destination.destination_id):
			var arrow = destination_arrows[destination.destination_id]

			if is_instance_valid(arrow):
				arrow.queue_free()

			destination_arrows.erase(destination.destination_id)
	
	update_destination_activation()
	is_releasing_passengers = false

func update_destination_activation():
	for destination in get_tree().get_nodes_in_group("PassengerDestination"):
		var has_passenger := false

		for passenger_data in passengers:
			if passenger_data["destination_id"] == destination.destination_id:
				has_passenger = true
				break

		destination.set_destination_active(has_passenger)


# Refuel Block ------------------------------------------------------
func is_stopped_for_refueling() -> bool:
	var horizontal_velocity := Vector2(velocity.x, velocity.z)

	return (
		absf(speed) <= REFUEL_STOP_EPSILON
		and horizontal_velocity.length_squared() <= REFUEL_STOP_EPSILON ** 2
		and not Input.is_action_pressed("accelerate")
		and not Input.is_action_pressed("brake")
	)


func refuel(amount: float) -> float:
	if amount <= 0.0 or not is_stopped_for_refueling():
		return 0.0

	var previous_fuel := fuel
	fuel = clampf(fuel + amount, 0.0, max_fuel)

	return fuel - previous_fuel


func _try_refuel(delta: float) -> void:
	if not is_stopped_for_refueling():
		return

	for area in get_tree().get_nodes_in_group("RefuelingAreas"):
		# Overlapping areas must not multiply the refueling rate.
		if area.try_refuel(self, delta):
			break
#-----------------------------------------------------------------
