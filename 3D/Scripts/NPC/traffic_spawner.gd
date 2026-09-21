extends Node3D

@export var npc_car_scene: PackedScene
@export var traffic_path: Path3D
@export var spawn_interval: float = 4.0 # Spawns a new car every 4 seconds

var spawn_timer: Timer

func _ready():
	# Create and configure the timer entirely in code
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_timer_timeout)
	
	add_child(spawn_timer)

func _on_timer_timeout():
	if npc_car_scene and traffic_path:
		# 1. Create a brand new copy of the car
		var new_car = npc_car_scene.instantiate()
		
		# 2. Assign the path to the car BEFORE it enters the scene tree.
		# This ensures its _ready() function can find the path immediately!
		new_car.path_node = traffic_path
		
		# 3. Add the car to the world
		add_child(new_car)
