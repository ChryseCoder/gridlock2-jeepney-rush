extends CharacterBody2D

# --- Physical Properties (Same as Player) ---
@export var acceleration: float = 40.0
@export var max_speed: float = 120.0 # Slightly slower than the player
@export var friction: float = 50.0
@export var brake_force: float = 150.0
@export var turn_speed: float = 3.0
@export var drift_factor: float = 0.9

var speed: float = 0.0
var turn_velocity: float = 0.0

# --- AI Properties ---
@export var target_position: Vector2
@onready var front_sensor: RayCast2D = $RayCast2D # Points forward from the car

# 1. Export an array specifically for 2D textures
@export var car_skins: Array[Texture2D] = []

# Get a reference to the child Sprite2D node
@onready var sprite_node: Sprite2D = $Sprite2D

# --- NEW: Navigation Properties ---
@export var path_node: Path2D # Drag your Path2D from the map into this slot in the Inspector
var path_points: Array[Vector2] = []
var current_point_index: int = 0

func _physics_process(delta: float) -> void:
	
	# --- NEW: Checkpoint Logic ---
	if path_points.size() > 0:
		# How far are we from our current target?
		var distance_to_target = global_position.distance_to(target_position)
		
		# If we get within 100 pixels, consider it "reached"
		if distance_to_target < 100.0:
			current_point_index += 1
			
			# Loop back to the start if we reached the end of the path
			if current_point_index >= path_points.size():
				current_point_index = 0
				
			# Lock onto the next point
			target_position = path_points[current_point_index]

	# 1. VISION: Determine Gas or Brake
	var virtual_gas := 1.0
	var virtual_brake := 0.0

	if front_sensor.is_colliding():
		# Something is in front of us!
		virtual_gas = 0.0
		virtual_brake = 1.0


	# 2. NAVIGATION: Determine Steering
	var target_rotation = (target_position - global_position).angle() + PI / 2.0
	target_rotation = wrapf(target_rotation, -PI, PI)


	# 3. PHYSICS

	# 🚀 Acceleration
	if virtual_gas > 0:
		speed += acceleration * virtual_gas * delta

	# 🛑 Braking
	elif virtual_brake > 0:
		if speed > 0:
			speed -= brake_force * virtual_brake * delta

	# 🧊 Natural friction
	else:
		if speed > 0:
			speed -= friction * delta

	speed = clamp(speed, 0, max_speed)

	# 🛞 SNAPPY TURNING
	if speed > 10:
		target_rotation = (target_position - global_position).angle() + PI / 2.0

		rotation = lerp_angle(
			rotation,
			target_rotation,
			10.0 * delta
		)


	# 🚗 Movement
	var forward = Vector2.UP.rotated(rotation)
	velocity = velocity.lerp(forward * speed, drift_factor)

	move_and_slide()
	
	# 💥 Collision Impact (same as player)
	if get_slide_collision_count() > 0:
		speed = velocity.dot(forward)

func _ready() -> void:
	if path_node and path_node.curve:
		var curve = path_node.curve

		var path_length = curve.get_baked_length()
		var sample_distance = 50.0

		for distance in range(0, int(path_length), int(sample_distance)):
			var local_point = curve.sample_baked(distance)
			var global_point = path_node.to_global(local_point)

			path_points.append(global_point)

		if path_points.size() > 0:
			target_position = path_points[0]


	# Check if you actually put any sprites in the Inspector list
	if car_skins.size() > 0:
		# Option A: Pick a completely random skin from the array
		sprite_node.texture = car_skins.pick_random()
		
		# Option B: If you want to specify a choice per instance instead, 
		# you could export an integer index variable instead.
