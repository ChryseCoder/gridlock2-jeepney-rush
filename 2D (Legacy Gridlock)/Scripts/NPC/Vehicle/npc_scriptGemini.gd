extends CharacterBody2D

# --- Node References ---
@export var path_node: Path2D

# Replace the raycast variable with this
@onready var shape_cast = $ShapeCast2D

# --- Vehicle Settings ---
@export var max_speed: float = 250.0
@export var acceleration: float = 300.0
@export var braking_force: float = 600.0
@export var steering_speed: float = 3.0

# --- Pathfinding Variables ---
@export var path_tolerance: float = 30.0 # How close to a point before targeting the next one
var path_points: PackedVector2Array
var current_point_index: int = 0
var current_speed: float = 0.0

# --- Overtaking Variables ---
var is_overtaking: bool = false
var overtake_timer: float = 0.0
@export var overtake_time: float = 1.0 # How long the car commits to the left-swerve

func _ready():
	if path_node and path_node.curve:
		var curve = path_node.curve
		path_points = curve.get_baked_points()
		
		var closest_distance = INF
		var closest_index = 0
		
		for i in range(path_points.size()):
			# Convert to global coordinates
			path_points[i] = path_node.to_global(path_points[i])
			
			# Check how far this point is from the vehicle's starting position
			var dist = global_position.distance_to(path_points[i])
			if dist < closest_distance:
				closest_distance = dist
				closest_index = i
				
		# Assign the closest point as the vehicle's first target
		current_point_index = closest_index
	else:
		print("Warning: No Path2D assigned to the NPC vehicle!")
		set_physics_process(false)

func _physics_process(delta):
	if path_points.is_empty():
		return

	# 1. Check for obstacles and trigger the overtake state
	if check_for_obstacles():
		is_overtaking = true
		overtake_timer = overtake_time # Resets timer as long as obstacle is in sight

	# 2. Handle the overtake timer
	if is_overtaking:
		overtake_timer -= delta
		if overtake_timer <= 0:
			is_overtaking = false

	# 3. Determine speed (slow down a bit while overtaking)
	if is_overtaking:
		current_speed = move_toward(current_speed, max_speed * 0.7, braking_force * delta)
	else:
		current_speed = move_toward(current_speed, max_speed, acceleration * delta)
		
	# 4. Steer (we now pass the overtaking state to the function)
	steer_towards_path(delta, is_overtaking)

	# Apply Movement
	velocity = -transform.y * current_speed
	move_and_slide()

# CHANGED: Added 'overtaking' parameter with a default value of false
func steer_towards_path(delta, overtaking: bool = false):
	var target_point = path_points[current_point_index]

	if global_position.distance_to(target_point) < path_tolerance:
		current_point_index += 1
		if current_point_index >= path_points.size():
			current_point_index = 0
		target_point = path_points[current_point_index]

	# Calculate base direction to target
	var direction = (target_point - global_position).normalized()
	
	# CHANGED: If overtaking, shift the target direction to the left
	if overtaking:
		# Rotate the target direction counter-clockwise by 45 degrees
		# In Godot 2D, negative angles rotate left
		direction = direction.rotated(deg_to_rad(-45))

	var forward_vector = -transform.y 
	var angle_to_target = forward_vector.angle_to(direction)

	rotation += sign(angle_to_target) * min(abs(angle_to_target), steering_speed * delta)

func check_for_obstacles() -> bool:
	# ShapeCast2D uses the exact same is_colliding() method
	if shape_cast.is_colliding():
		return true
	return false
