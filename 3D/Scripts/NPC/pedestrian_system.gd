extends Node3D
## A fixed population is created once; culling never frees/recreates visible NPCs.
const PEDESTRIAN := preload("res://3D/Scenes/NPC/Pedestrian.tscn")
const ROUTE_SCRIPT := preload("res://3D/Scripts/NPC/pedestrian_route.gd")
@export var camera: Camera3D
@export_range(0, 200, 1) var maximum_population: int = 24
@export_group("Culling")
@export_range(0.05, 1.0, 0.05) var culling_interval: float = 0.15
@export_range(5.0, 250.0, 1.0) var activation_distance: float = 65.0
## Conservative sphere keeps sprites active slightly beyond the visible edge.
@export_range(0.5, 5.0, 0.1) var frustum_margin: float = 1.5
var pedestrians: Array[CharacterBody3D] = []
var _culling_left := 0.0
var _populated := false

func _ready() -> void:
	call_deferred("populate")

func populate() -> void:
	if _populated:
		return
	_populated = true
	for route in get_children():
		if not route is Path3D or route.get_script() != ROUTE_SCRIPT:
			continue
		if route.curve == null or route.curve.get_baked_length() <= 0.1:
			continue
		var points: PackedVector3Array = route.curve.get_baked_points()
		for index in range(points.size()):
			points[index] = route.to_global(points[index])
		for slot in range(route.pedestrian_count):
			if pedestrians.size() >= maximum_population:
				break
			var walker = PEDESTRIAN.instantiate()
			walker.walk_speed = randf_range(route.minimum_speed, maxf(route.minimum_speed, route.maximum_speed))
			walker.endpoint_pause = route.endpoint_pause
			add_child(walker)
			var index := mini(points.size() - 2, int(float(slot + 0.5) / route.pedestrian_count * (points.size() - 1)))
			walker.configure(points, index, 1 if slot % 2 == 0 else -1)
			# Badly placed route samples must not spawn walkers inside geometry.
			var collision: CollisionShape3D = walker.get_node("CollisionShape3D")
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = collision.shape
			query.transform = collision.global_transform
			query.collision_mask = walker.collision_mask
			query.exclude = [walker.get_rid()]
			if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				walker.queue_free()
				continue
			pedestrians.append(walker)
	update_culling()

func _physics_process(delta: float) -> void:
	_culling_left -= delta
	if _culling_left <= 0.0:
		_culling_left = culling_interval
		update_culling()

func update_culling() -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		camera = get_viewport().get_camera_3d()
	var planes: Array[Plane] = []
	if is_instance_valid(camera):
		planes = camera.get_frustum()
	for walker in pedestrians:
		if not is_instance_valid(walker):
			continue
		var active := not planes.is_empty()
		if active:
			active = camera.global_position.distance_squared_to(walker.global_position) <= activation_distance * activation_distance
		if active:
			for plane in planes:
				if plane.distance_to(walker.global_position) > frustum_margin:
					active = false
					break
		if active != walker.simulation_active:
			walker.set_simulation_active(active)
