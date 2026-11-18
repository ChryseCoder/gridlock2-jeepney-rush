extends SceneTree
var checks := 0
var failures := 0
var fixture: Node3D
func _initialize() -> void:
	call_deferred("run")
func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
func frames(count: int) -> void:
	for index in range(count):
		await physics_frame
func run() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	current_scene = fixture
	var camera := Camera3D.new()
	camera.position = Vector3(0, 15, 0)
	camera.rotation_degrees.x = -90
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	fixture.add_child(camera)
	camera.make_current()
	var system = load("res://3D/Scenes/NPC/PedestrianSystem.tscn").instantiate()
	system.camera = camera
	system.maximum_population = 3
	fixture.add_child(system)
	await frames(4)
	check(system.pedestrians.size() == 3, "population is capped even when the route requests more")
	var walker = system.pedestrians[1]
	var identity: int = walker.get_instance_id()
	check(walker.simulation_active and walker.visible, "walkers inside the real camera frustum are active")
	var original: Vector3 = walker.global_position
	await frames(12)
	check(walker.global_position.distance_to(original) > 0.01, "visible pedestrians walk along the authored route")
	check(not walker.has_method("board_jeepney") and not walker.is_in_group("MissionPassengers") and not walker.is_in_group("MinimapPassengers"), "ambient pedestrians cannot board or affect mission passenger counts")
	check(walker.collision_layer == 0, "ambient walkers do not block the player, traffic, or enforcers")
	camera.position.x = 40
	system.activation_distance = 200
	system.update_culling()
	check(not walker.simulation_active and not walker.visible and walker.process_mode == Node.PROCESS_MODE_DISABLED, "frustum culling suspends the entire movement and animation subtree")
	var hidden_position: Vector3 = walker.global_position
	var hidden_frame: int = walker.visual.body.frame
	await frames(12)
	check(walker.global_position == hidden_position and walker.visual.body.frame == hidden_frame, "offscreen pedestrians do not simulate or animate")
	camera.position.x = 0
	system.update_culling()
	check(walker.simulation_active and walker.get_instance_id() == identity and walker.global_position == hidden_position, "returning camera resumes the same pedestrian without respawning or teleporting")
	system.activation_distance = 5
	system.update_culling()
	check(not walker.simulation_active, "distance limit culls even in-frustum pedestrians")
	system.activation_distance = 65
	camera.rotation_degrees.x = 90
	system.update_culling()
	check(not walker.simulation_active, "pedestrians behind the camera are culled")
	camera.rotation_degrees.x = -90
	system.update_culling()
	system.populate()
	check(system.pedestrians.size() == 3, "repeated population calls do not duplicate NPCs")
	walker.global_position = walker._points[walker._points.size() - 1]
	walker._target_index = walker._points.size() - 1
	walker._direction = 1
	walker._pause_left = 0
	walker._physics_process(0.1)
	check(walker._direction == -1 and walker._pause_left > 0, "walkers pause and reverse at the sidewalk endpoint")
	paused = true
	var paused_position: Vector3 = walker.global_position
	await process_frame
	await process_frame
	check(walker.global_position == paused_position, "game pause also pauses pedestrians")
	paused = false
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(6, 3, 40)
	shape.shape = box
	wall.add_child(shape)
	fixture.add_child(wall)
	await frames(2)
	var blocked = load("res://3D/Scenes/NPC/PedestrianSystem.tscn").instantiate()
	fixture.add_child(blocked)
	await frames(3)
	check(blocked.pedestrians.is_empty(), "blocked route samples do not spawn pedestrians inside geometry")
	blocked.free()
	wall.free()
	camera.free()
	system.update_culling()
	check(not walker.simulation_active, "missing camera safely suspends pedestrians")
	fixture.free()
	current_scene = null
	await frames(2)
	change_scene_to_file("res://3D/Scenes/World/GameMap.tscn")
	await scene_changed
	await frames(5)
	var level = current_scene
	var total := 0
	for name in ["PickupPedestrians", "SchoolPedestrians", "WestPedestrians"]:
		var population: int = level.get_node(name).pedestrians.size()
		print("MAP POPULATION ", name, ": ", population)
		total += population
	check(total > 0 and total <= 12, "GameMap contains a bounded ambient population")
	check(level.get_node("MissionManager").remaining_mission_passengers == 2, "ambient population leaves mission objectives unchanged")
	check(root.get_node("GameSession").earnings == 0 and root.get_node("GameSession").violation_points == 0, "ambient population does not award money or violations")
	level.free()
	current_scene = null
	await frames(2)
	check(get_nodes_in_group("AmbientPedestrians").is_empty(), "scene cleanup removes the entire ambient population")
	print("CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
