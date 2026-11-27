extends Node3D

@export var npc_car_scene: PackedScene
@export var traffic_path: Path3D
@export var spawn_interval: float = 4.0 # Spawns a new car every 4 seconds
@export var camera: Camera3D
@export_range(0.5, 10.0, 0.1) var minimum_spawn_distance: float = 2.0

var spawn_timer: Timer

func _ready():
	# Create and configure the timer entirely in code
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_timer_timeout)
	
	add_child(spawn_timer)

func _on_timer_timeout():
	if not npc_car_scene or not traffic_path or not camera:
		return

	var spawn_position = traffic_path.curve.sample_baked(0.0)
	spawn_position = traffic_path.to_global(spawn_position)

	# Don't spawn if the player can currently see the spawn point.
	if camera.is_position_in_frustum(spawn_position):
		return

	# Routes can share a lane entrance and trigger in the same frame.
	if _spawn_is_occupied(spawn_position):
		return

	var new_car = npc_car_scene.instantiate()

	new_car.path_node = traffic_path

	add_child(new_car)
	
	var start_pos = traffic_path.curve.sample_baked(0.0)
	var next_pos = traffic_path.curve.sample_baked(1.0)

	start_pos = traffic_path.to_global(start_pos)
	next_pos = traffic_path.to_global(next_pos)

	new_car.global_position = start_pos
	new_car.look_at(next_pos, Vector3.UP)


func _spawn_is_occupied(spawn_position: Vector3) -> bool:
	for group in [&"npc_vehicles", &"Player", &"player"]:
		for vehicle in get_tree().get_nodes_in_group(group):
			if not vehicle is Node3D:
				continue
			var offset: Vector3 = vehicle.global_position - spawn_position
			if absf(offset.y) > 1.0:
				continue
			offset.y = 0.0
			if offset.length_squared() < minimum_spawn_distance * minimum_spawn_distance:
				return true
	return false
