extends CharacterBody3D

@export var path_node: Path3D
@onready var shape_cast = $ShapeCast3D

@export_group("Vehicle Stats")
@export var max_speed: float = 5.0
@export var acceleration: float = 5.0
@export var braking_force: float = 10.0
@export var steering_speed: float = 2.0

@export_group("Overtaking Logic")
@export var overtake_time: float = 1.0

var path_points: PackedVector3Array
var current_point_index: int = 0
var current_speed: float = 0.0

var is_overtaking: bool = false
var overtake_timer: float = 0.0
var traffic_light_stop: bool = false
var traffic_queue_stop: bool = false

enum ObstacleType {
	NONE,
	NORMAL,
	TRAFFIC_QUEUE
}

func _ready():
	if path_node and path_node.curve:
		path_points = path_node.curve.get_baked_points()
		for i in range(path_points.size()):
			path_points[i] = path_node.to_global(path_points[i])
		
		# Snap to the start of the line
		current_point_index = 0
		global_position = path_points[0]
	else:
		print("No path assigned!")
		set_physics_process(false)


func _physics_process(delta):
	if path_points.is_empty():
		return
		
# ---------------------------------------------------------
# 1. Obstacle Detection
# ---------------------------------------------------------

	var obstacle_type = check_for_obstacles()


	match obstacle_type:

		ObstacleType.TRAFFIC_QUEUE:

			traffic_queue_stop = true
			is_overtaking = false


		ObstacleType.NORMAL:

			traffic_queue_stop = false

			# Only overtake when we are not stopped
			# directly by a traffic light.
			if not traffic_light_stop:
				is_overtaking = true
				overtake_timer = overtake_time


		ObstacleType.NONE:

			traffic_queue_stop = false
		
	# 2. Overtake Timer
	if is_overtaking:
		overtake_timer -= delta
		if overtake_timer <= 0:
			is_overtaking = false
			
# ---------------------------------------------------------
# 3. Dynamic Speed
# ---------------------------------------------------------

	if traffic_light_stop or traffic_queue_stop:

		# Come to a full stop.
		current_speed = move_toward(
			current_speed,
			0.0,
			braking_force * delta
		)


	elif is_overtaking:

		current_speed = move_toward(
			current_speed,
			max_speed * 0.7,
			braking_force * delta
		)


	else:

		current_speed = move_toward(
			current_speed,
			max_speed,
			acceleration * delta
		)

	# 4. Target Tracking
	var target = path_points[current_point_index]
	target.y = global_position.y 
	
	if global_position.distance_to(target) < 2.0:
		current_point_index += 1
		
		if current_point_index >= path_points.size():
			queue_free() # Safely despawns at the end of the road
			return
			
		target = path_points[current_point_index]
		target.y = global_position.y

	# 5. Steering & Swerving
	var direction = (target - global_position).normalized()
	
	# If overtaking, rotate the target direction 45 degrees left
	if is_overtaking:
		direction = direction.rotated(Vector3.UP, deg_to_rad(45))
		
	var forward = -global_transform.basis.z
	var angle_to_target = forward.signed_angle_to(direction, Vector3.UP)
	
	rotation.y += sign(angle_to_target) * min(abs(angle_to_target), steering_speed * delta)
	
	# 6. Apply Movement
	velocity = -global_transform.basis.z * current_speed
	velocity.y = 0.0 
	
	move_and_slide()

func check_for_obstacles() -> ObstacleType:
	if not shape_cast:
		return ObstacleType.NONE

	if not shape_cast.is_colliding():
		return ObstacleType.NONE


	for i in range(shape_cast.get_collision_count()):
		var collider = shape_cast.get_collider(i)

		if collider == null:
			continue

		if collider.is_in_group("npc_vehicles"):

			if collider.has_method("is_waiting_for_traffic"):

				if collider.is_waiting_for_traffic():
					return ObstacleType.TRAFFIC_QUEUE


	# Something exists ahead, but it isn't a traffic queue.
	return ObstacleType.NORMAL
	
func set_traffic_light_stop(should_stop: bool) -> void:
	traffic_light_stop = should_stop

	# Do not try to overtake while intentionally
	# stopped at a traffic light.
	if traffic_light_stop:
		is_overtaking = false

func is_waiting_for_traffic() -> bool:
	return traffic_light_stop or traffic_queue_stop
