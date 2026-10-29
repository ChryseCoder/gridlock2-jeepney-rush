extends CharacterBody3D
## Place instances anywhere; their initial world position is their idle post.
signal state_changed(state: int)

const Pathfinder = preload("res://3D/Scripts/NPC/passenger_pathfinder.gd")
enum State { IDLE, ALERT, PURSUING, TICKETING, RETURNING }

@export_group("Detection")
@export_range(1.0, 60.0, 1.0) var detection_radius: float = 14.0
@export_range(2.0, 100.0, 1.0) var pursuit_radius: float = 28.0
@export_range(1.0, 60.0, 1.0) var pursuit_timeout: float = 20.0
@export_group("Movement")
@export_range(0.5, 10.0, 0.5) var walk_speed: float = 3.5
@export_range(0.1, 3.0, 0.1) var path_refresh_interval: float = 0.7
@export_range(0.5, 4.0, 0.1) var ticket_distance: float = 1.5
@export_group("Ticket")
@export_range(0.1, 3.0, 0.1) var alert_duration: float = 0.6
@export_range(0.2, 5.0, 0.1) var ticket_duration: float = 1.5
@export_multiline var ticket_dialogue: String = "Akala mo lusot ka, boss? ₱300 'yan!"
@export var whistle_sound: AudioStream = preload("res://3D/Assets/Audio/enforcer_whistle.wav")

@onready var visual = $PassengerVisual
@onready var whistle: AudioStreamPlayer3D = $Whistle
@onready var status: Label3D = $Status
var state: State = State.IDLE
var home_position: Vector3
var target_vehicle: CharacterBody3D
var _vehicle_id: int = 0
var _incident_position: Vector3
var _elapsed: float = 0.0
var _ticket_elapsed: float = 0.0
var _path := PackedVector3Array()
var _path_index: int = 0
var _refresh: float = 0.0

func _ready() -> void:
	add_to_group("TrafficEnforcers")
	home_position = global_position
	pursuit_radius = maxf(pursuit_radius, detection_radius)
	# A consistent blue uniform distinguishes enforcers from passengers.
	visual.outfit.modulate = Color(0.2, 0.45, 1.0)
	whistle.stream = whistle_sound
	_set_state(State.IDLE)

func can_witness(vehicle: CharacterBody3D, spot: Node3D) -> bool:
	return (
		state == State.IDLE
		and global_position.distance_to(vehicle.global_position) <= detection_radius
		and _can_see(vehicle, spot)
	)

func _can_see(vehicle: CharacterBody3D, spot: Node3D = null) -> bool:
	var excluded: Array[RID] = [get_rid(), vehicle.get_rid()]
	if spot is CollisionObject3D:
		excluded.append(spot.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(
		global_position, vehicle.global_position, collision_mask, excluded
	)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func begin_encounter(vehicle: CharacterBody3D) -> void:
	target_vehicle = vehicle
	_vehicle_id = vehicle.get_instance_id()
	_incident_position = vehicle.global_position
	_elapsed = 0.0
	_ticket_elapsed = 0.0
	_set_state(State.ALERT)
	whistle.play()
	GameSession.enforcement_notice.emit("Enforcer spotted an illegal stop! Stop to accept the ticket.")

func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			velocity = Vector3.ZERO
		State.ALERT, State.PURSUING, State.TICKETING:
			if not is_instance_valid(target_vehicle):
				GameSession.abandon_encounter(_vehicle_id, self)
				_return_home()
				return
			_elapsed += delta
			if _elapsed >= pursuit_timeout and target_vehicle.global_position.distance_to(_incident_position) < 2.0:
				# A blocked approach is not an evasion by a stationary driver.
				GameSession.abandon_encounter(_vehicle_id, self)
				GameSession.enforcement_notice.emit("Enforcer could not reach the jeepney. No ticket issued.")
				_return_home()
				return
			if (
				target_vehicle.global_position.distance_to(home_position) > pursuit_radius
				or _elapsed >= pursuit_timeout
			):
				GameSession.resolve_encounter(_vehicle_id, self, true)
				_return_home()
				return
			if state == State.ALERT and _elapsed < alert_duration:
				return
			var distance := global_position.distance_to(target_vehicle.boarding_point.global_position)
			var stopped := absf(target_vehicle.speed) <= 0.1 and target_vehicle.velocity.length() <= 0.1
			if distance <= ticket_distance and stopped and _can_see(target_vehicle):
				if state != State.TICKETING:
					_set_state(State.TICKETING)
					DialogueManager.cancel_dialogue()
					var lines: Array[String] = [ticket_dialogue]
					DialogueManager.start_dialog(Vector2(24, 24), lines)
				velocity = Vector3.ZERO
				visual.play_animation("idle_down")
				_ticket_elapsed += delta
				if _ticket_elapsed >= ticket_duration and not DialogueManager.is_dialog_active:
					GameSession.resolve_encounter(_vehicle_id, self, false)
					_return_home()
			else:
				_ticket_elapsed = 0.0
				if state != State.PURSUING:
					_set_state(State.PURSUING)
				_move_to(target_vehicle.boarding_point.global_position, ticket_distance * 0.8, delta)
		State.RETURNING:
			var distance := global_position.distance_to(home_position)
			if distance < 0.15:
				global_position = home_position
				_set_state(State.IDLE)
			else:
				_move_to(home_position, 0.1, delta)

func _move_to(goal: Vector3, arrival: float, delta: float) -> void:
	_refresh -= delta
	if _refresh <= 0.0:
		_path = Pathfinder.find_path(self, goal, arrival, 2.0)
		_path_index = 0
		_refresh = path_refresh_interval
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) < 0.08:
		_path_index += 1
	if _path_index >= _path.size():
		velocity = Vector3.ZERO
		visual.play_animation("idle_down")
		return
	var direction := _path[_path_index] - global_position
	direction.y = 0.0
	velocity = direction.normalized() * minf(walk_speed, direction.length() / maxf(delta, 0.001))
	var animation := "walk_down"
	if absf(direction.x) > absf(direction.z):
		animation = "walk_right" if direction.x > 0 else "walk_left"
	elif direction.z < 0:
		animation = "walk_up"
	visual.play_animation(animation)
	move_and_slide()
	global_position.y = home_position.y

func _return_home() -> void:
	target_vehicle = null
	_set_state(State.RETURNING)

func _set_state(value: State) -> void:
	state = value
	_refresh = 0.0
	_path.clear()
	velocity = Vector3.ZERO
	status.text = ["ENFORCER", "! ILLEGAL STOP", "STOP!", "ISSUING TICKET", "RETURNING"][state]
	if state == State.IDLE:
		visual.play_animation("idle_down")
	state_changed.emit(state)

func _exit_tree() -> void:
	GameSession.abandon_encounter(_vehicle_id, self)
