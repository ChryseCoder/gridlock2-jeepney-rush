extends Node3D
class_name IntersectionController


# =========================================================
# TRAFFIC LIGHT STATES
# =========================================================


enum Phase {
	NORTH_SOUTH_GREEN,
	NORTH_SOUTH_YELLOW,
	ALL_RED_TO_EAST_WEST,
	EAST_WEST_GREEN,
	EAST_WEST_YELLOW,
	ALL_RED_TO_NORTH_SOUTH
}


# =========================================================
# TIMINGS
# =========================================================

@export_group("Traffic Light Timing")

@export var green_time: float = 8.0
@export var yellow_time: float = 2.0
@export var all_red_time: float = 1.0


# =========================================================
# TRAFFIC LIGHTS
# =========================================================

@export_group("Traffic Lights")

@export var north_light: Node
@export var south_light: Node
@export var east_light: Node
@export var west_light: Node


# =========================================================
# STOP ZONES
# =========================================================

@export_group("Stop Zones")

@export var north_stop_zone: Area3D
@export var south_stop_zone: Area3D
@export var east_stop_zone: Area3D
@export var west_stop_zone: Area3D


# =========================================================
# CURRENT STATE
# =========================================================

var current_phase: Phase = Phase.NORTH_SOUTH_GREEN

var north_south_state: TrafficManager.LightState = TrafficManager.LightState.RED
var east_west_state: TrafficManager.LightState = TrafficManager.LightState.RED


# Vehicles currently inside each pair of stop zones.
var north_south_vehicles: Array[Node] = []
var east_west_vehicles: Array[Node] = []


var phase_timer: Timer


# =========================================================
# READY
# =========================================================

func _ready() -> void:
	add_to_group("intersection_controllers")

	TrafficManager.register_intersection(self)

	_create_phase_timer()
	_connect_stop_zones()

	# Start traffic cycle.
	_set_phase(Phase.NORTH_SOUTH_GREEN)


func _exit_tree() -> void:
	TrafficManager.unregister_intersection(self)


# =========================================================
# TIMER SETUP
# =========================================================

func _create_phase_timer() -> void:
	phase_timer = Timer.new()

	phase_timer.one_shot = true

	add_child(phase_timer)

	phase_timer.timeout.connect(_on_phase_timer_timeout)


# =========================================================
# STOP ZONE SIGNALS
# =========================================================

func _connect_stop_zones() -> void:
	_connect_zone(
		north_stop_zone,
		&"north_south"
	)

	_connect_zone(
		south_stop_zone,
		&"north_south"
	)

	_connect_zone(
		east_stop_zone,
		&"east_west"
	)

	_connect_zone(
		west_stop_zone,
		&"east_west"
	)


func _connect_zone(
	zone: Area3D,
	axis: StringName
) -> void:

	if zone == null:
		return

	zone.body_entered.connect(
		_on_vehicle_entered_zone.bind(axis)
	)

	zone.body_exited.connect(
		_on_vehicle_exited_zone.bind(axis)
	)


# =========================================================
# VEHICLE ENTERED STOP ZONE
# =========================================================

func _on_vehicle_entered_zone(
	body: Node,
	axis: StringName
) -> void:

	if not body.is_in_group("npc_vehicles"):
		return


	if axis == &"north_south":

		if body not in north_south_vehicles:
			north_south_vehicles.append(body)

		_update_vehicle_for_axis(
			body,
			north_south_state
		)


	elif axis == &"east_west":

		if body not in east_west_vehicles:
			east_west_vehicles.append(body)

		_update_vehicle_for_axis(
			body,
			east_west_state
		)


# =========================================================
# VEHICLE EXITED STOP ZONE
# =========================================================

func _on_vehicle_exited_zone(
	body: Node,
	axis: StringName
) -> void:

	if axis == &"north_south":
		north_south_vehicles.erase(body)

	elif axis == &"east_west":
		east_west_vehicles.erase(body)


# =========================================================
# TRAFFIC PHASES
# =========================================================

func _set_phase(new_phase: Phase) -> void:

	current_phase = new_phase


	match current_phase:

		# -------------------------------------------------
		# NORTH / SOUTH GREEN
		# -------------------------------------------------

		Phase.NORTH_SOUTH_GREEN:

			north_south_state = TrafficManager.LightState.GREEN
			east_west_state = TrafficManager.LightState.RED

			_update_all_lights()
			_update_waiting_vehicles()

			phase_timer.start(green_time)


		# -------------------------------------------------
		# NORTH / SOUTH YELLOW
		# -------------------------------------------------

		Phase.NORTH_SOUTH_YELLOW:

			north_south_state = TrafficManager.LightState.YELLOW
			east_west_state = TrafficManager.LightState.RED

			_update_all_lights()
			_update_waiting_vehicles()

			phase_timer.start(yellow_time)


		# -------------------------------------------------
		# ALL RED
		# -------------------------------------------------

		Phase.ALL_RED_TO_EAST_WEST:

			north_south_state = TrafficManager.LightState.RED
			east_west_state = TrafficManager.LightState.RED

			_update_all_lights()
			_update_waiting_vehicles()

			phase_timer.start(all_red_time)


		# -------------------------------------------------
		# EAST / WEST GREEN
		# -------------------------------------------------

		Phase.EAST_WEST_GREEN:

			north_south_state = TrafficManager.LightState.RED
			east_west_state = TrafficManager.LightState.GREEN

			_update_all_lights()
			_update_waiting_vehicles()

			phase_timer.start(green_time)


		# -------------------------------------------------
		# EAST / WEST YELLOW
		# -------------------------------------------------

		Phase.EAST_WEST_YELLOW:

			north_south_state = TrafficManager.LightState.RED
			east_west_state = TrafficManager.LightState.YELLOW

			_update_all_lights()
			_update_waiting_vehicles()

			phase_timer.start(yellow_time)


		# -------------------------------------------------
		# ALL RED
		# -------------------------------------------------

		Phase.ALL_RED_TO_NORTH_SOUTH:

			north_south_state = TrafficManager.LightState.RED
			east_west_state = TrafficManager.LightState.RED

			_update_all_lights()
			_update_waiting_vehicles()

			phase_timer.start(all_red_time)


# =========================================================
# NEXT PHASE
# =========================================================

func _on_phase_timer_timeout() -> void:

	match current_phase:

		Phase.NORTH_SOUTH_GREEN:
			_set_phase(
				Phase.NORTH_SOUTH_YELLOW
			)

		Phase.NORTH_SOUTH_YELLOW:
			_set_phase(
				Phase.ALL_RED_TO_EAST_WEST
			)

		Phase.ALL_RED_TO_EAST_WEST:
			_set_phase(
				Phase.EAST_WEST_GREEN
			)

		Phase.EAST_WEST_GREEN:
			_set_phase(
				Phase.EAST_WEST_YELLOW
			)

		Phase.EAST_WEST_YELLOW:
			_set_phase(
				Phase.ALL_RED_TO_NORTH_SOUTH
			)

		Phase.ALL_RED_TO_NORTH_SOUTH:
			_set_phase(
				Phase.NORTH_SOUTH_GREEN
			)


# =========================================================
# TRAFFIC LIGHT VISUALS
# =========================================================

func _update_all_lights() -> void:

	_set_light_state(
		north_light,
		north_south_state
	)

	_set_light_state(
		south_light,
		north_south_state
	)

	_set_light_state(
		east_light,
		east_west_state
	)

	_set_light_state(
		west_light,
		east_west_state
	)


func _set_light_state(
	light: Node,
	state: TrafficManager.LightState
) -> void:

	if light == null:
		return

	if light.has_method("set_state"):
		light.set_state(state)


# =========================================================
# NPC CONTROL
# =========================================================

func _update_waiting_vehicles() -> void:

	for vehicle in north_south_vehicles:

		if is_instance_valid(vehicle):
			_update_vehicle_for_axis(
				vehicle,
				north_south_state
			)


	for vehicle in east_west_vehicles:

		if is_instance_valid(vehicle):
			_update_vehicle_for_axis(
				vehicle,
				east_west_state
			)


func _update_vehicle_for_axis(
	vehicle: Node,
	state: TrafficManager.LightState
) -> void:

	if not is_instance_valid(vehicle):
		return

	if not vehicle.has_method(
		"set_traffic_light_stop"
	):
		return


	# NPCs currently stop only for RED.
	var should_stop: bool = (
		state == TrafficManager.LightState.RED
	)

	vehicle.set_traffic_light_stop(
		should_stop
	)


# =========================================================
# OPTIONAL PUBLIC FUNCTIONS
# =========================================================

func get_north_south_state() -> TrafficManager.LightState:
	return north_south_state


func get_east_west_state() -> TrafficManager.LightState:
	return east_west_state
