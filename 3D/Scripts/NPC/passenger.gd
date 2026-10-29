extends CharacterBody3D

const Pathfinder = preload("res://3D/Scripts/NPC/passenger_pathfinder.gd")

@export_group("Pathfinding")
@export_range(0.1, 2.0, 0.1) var path_refresh_interval: float = 0.5
@export_range(1.0, 6.0, 0.5) var path_search_padding: float = 3.0

var _path := PackedVector3Array()
var _path_index: int = 0
var _path_time_left: float = 0.0
var _boarding_origin: Vector3
var _last_target: Vector3

@export var walk_speed: float = 2.0
@export var boarding_distance: float = 0.5
@export var max_boarding_distance: float = 3.0
@export var destination_id: StringName
@export_group("Stop Rules")
@export var legal_pickup: bool = true
@export var is_mission_passenger: bool = true

@export_group("Appearance")
## Disable to use the selected SpriteFrames. Empty slots use the default character layers.
@export var randomize_appearance: bool = true
## SpriteFrames resources containing all eight idle/walk direction animations.
@export var body_sprite_frames: SpriteFrames
@export var outfit_sprite_frames: SpriteFrames
@export var hair_sprite_frames: SpriteFrames
@export var outfit_tint: Color = Color.WHITE

@onready var visual = $PassengerVisual
@onready var marker_visual = $MarkerVisual

var jeepney: CharacterBody3D
var walking: bool = false

var destination_target: Vector3
var walking_to_destination: bool = false
var can_board: bool = true
var nearby_jeepney: CharacterBody3D = null

var waiting_position: Vector3
var returning_to_wait: bool = false
var _exit_vehicle: CharacterBody3D = null


func _ready():
	visual.configure_appearance(
		randomize_appearance, body_sprite_frames, outfit_sprite_frames,
		hair_sprite_frames, outfit_tint
	)
	add_to_group("MinimapPassengers")
	if can_board and is_mission_passenger:
		add_to_group("MissionPassengers")
	waiting_position = global_position
	visual.play_animation("idle_down")

func _reset_path() -> void:
	_path.clear()
	_path_index = 0
	_path_time_left = 0.0

func walk_to_jeepney(target_jeepney: CharacterBody3D):
	jeepney = target_jeepney
	if not legal_pickup:
		GameSession.report_illegal_stop(jeepney, self)
	_boarding_origin = jeepney.global_position

	returning_to_wait = false
	_reset_path()

	walking = true
	walking_to_destination = false
	marker_visual.hide()

func walk_to_destination(target_position: Vector3):
	destination_target = target_position

	returning_to_wait = false
	_reset_path()

	walking = true
	walking_to_destination = true
	can_board = false
	marker_visual.hide()

func _physics_process(delta):
	_update_disembark_collision()
	# A walking detour must not count as the jeepney driving away.
	if walking and not walking_to_destination and not returning_to_wait:
		if not is_instance_valid(jeepney):
			cancel_boarding()
			return

		if (
			jeepney.global_position.distance_to(_boarding_origin)
			> max_boarding_distance
		):
			cancel_boarding()
			return

	# Start boarding once the nearby jeepney stops.
	if not walking and is_instance_valid(nearby_jeepney):
		if nearby_jeepney.velocity.length() <= 0.1:
			walk_to_jeepney(nearby_jeepney)

	if not walking:
		velocity = Vector3.ZERO
		return

	var target_position: Vector3

	if returning_to_wait:
		target_position = waiting_position
	elif walking_to_destination:
		target_position = destination_target
	else:
		if jeepney == null:
			return

		target_position = jeepney.boarding_point.global_position

	var direction = target_position - global_position
	direction.y = 0.0

	# Being close is insufficient if an obstacle separates us from the target.
	if (
		direction.length() <= boarding_distance
		and Pathfinder.has_line_of_sight(self, target_position)
	):
		if returning_to_wait:
			returning_to_wait = false
			walking = false
			velocity = Vector3.ZERO
			visual.play_animation("idle_down")
			marker_visual.show()

		elif walking_to_destination:
			reach_destination()

		else:
			board_jeepney()

		return

	_path_time_left -= delta

	if (
		_path_time_left <= 0.0
		or target_position.distance_to(_last_target) > 0.25
	):
		_path = Pathfinder.find_path(
			self,
			target_position,
			boarding_distance,
			path_search_padding
		)
		_path_index = 0
		_path_time_left = path_refresh_interval
		_last_target = target_position

	while _path_index < _path.size():
		var step := _path[_path_index] - global_position
		step.y = 0.0

		var tolerance := 0.08

		if _path_index == _path.size() - 1:
			tolerance = minf(0.02, boarding_distance * 0.05)

		if step.length() > tolerance:
			break

		_path_index += 1

	if _path_index >= _path.size():
		# Wait and retry instead of pushing against the obstruction.
		velocity = Vector3.ZERO
		visual.play_animation("idle_down")
		return

	var next_step := _path[_path_index] - global_position
	next_step.y = 0.0

	var step_speed := minf(
		walk_speed,
		next_step.length() / maxf(delta, 0.001)
	)

	velocity = next_step.normalized() * step_speed
	update_walk_animation(next_step)
	move_and_slide()


func update_walk_animation(direction: Vector3):
	if abs(direction.x) > abs(direction.z):

		if direction.x > 0:
			visual.play_animation("walk_right")
		else:
			visual.play_animation("walk_left")

	else:
		if direction.z > 0:
			visual.play_animation("walk_down")
		else:
			visual.play_animation("walk_up")


func board_jeepney():
	if not walking:
		return

	walking = false
	velocity = Vector3.ZERO

	jeepney.add_passenger(
	destination_id,
	visual.get_appearance(),
	is_mission_passenger,
	)
	
	var lines: Array[String] = [
		"Salamat po!",
		"Sa %s lang po." % destination_id
	]

	var screen_size = get_viewport().get_visible_rect().size
	var dialog_position = Vector2(
		screen_size.x / 2.0,
		screen_size.y - 120.0
	)

	DialogueManager.start_dialog(dialog_position, lines)
	queue_free()


func reach_destination():
	walking = false
	velocity = Vector3.ZERO

	if is_mission_passenger:
		var manager = get_tree().get_first_node_in_group("MissionManager")
		if manager:
			manager.passenger_arrived()
	print("Passenger reached destination!")
	queue_free()


func _on_area_3d_body_entered(body):
	if not can_board:
		return

	if body.is_in_group("player"):
		print("Jeepney detected!")
		nearby_jeepney = body

func _on_area_3d_body_exited(body):
	if body == nearby_jeepney:
		nearby_jeepney = null


func cancel_boarding():
	_reset_path()
	velocity = Vector3.ZERO

	jeepney = null
	walking = true
	returning_to_wait = true

	marker_visual.hide()

func prepare_disembarkation(source_vehicle: CharacterBody3D) -> void:
	_exit_vehicle = source_vehicle

	add_collision_exception_with(source_vehicle)
	source_vehicle.add_collision_exception_with(self)


func _update_disembark_collision() -> void:
	if not is_instance_valid(_exit_vehicle):
		_exit_vehicle = null
		return

	# Check whether the passenger is fully clear of the source jeepney.
	var body_shape: CollisionShape3D = $CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()

	query.shape = body_shape.shape
	query.transform = body_shape.global_transform
	query.margin = 0.08
	query.collision_mask = _exit_vehicle.collision_layer
	query.exclude = [get_rid()]

	var space := get_world_3d().direct_space_state

	for hit in space.intersect_shape(query, 64):
		if hit["rid"] == _exit_vehicle.get_rid():
			return

	_clear_disembark_collision()


func _clear_disembark_collision() -> void:
	if is_instance_valid(_exit_vehicle):
		remove_collision_exception_with(_exit_vehicle)
		_exit_vehicle.remove_collision_exception_with(self)

	_exit_vehicle = null


func _exit_tree() -> void:
	_clear_disembark_collision()
