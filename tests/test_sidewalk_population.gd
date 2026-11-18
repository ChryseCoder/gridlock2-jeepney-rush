extends SceneTree
var checks := 0
var failures := 0
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
func on_sidewalk(population: Node, walker: Node3D) -> bool:
	var index: int = walker.get_meta("sidewalk_segment", -1)
	if index < 0:
		return true
	var segment: Dictionary = population.sidewalk_segments[index]
	var road: Dictionary = population._roads[segment.road]
	var local: Vector3 = road.inverse * walker.global_position
	return absf(absf(local.x) - population.sidewalk_center) < 0.007 and absf(local.z) <= population.patrol_half_length + 0.001 and not population._inside_other_road(walker.global_position, segment.road)
func run() -> void:
	change_scene_to_file("res://3D/Scenes/World/GameMap.tscn")
	await scene_changed
	await frames(4)
	var level = current_scene
	var population = level.get_node("SidewalkPopulation")
	var camera = level.get_node("Camera3D")
	camera.set_physics_process(false)
	level.get_node("Player").set_physics_process(false)
	population.set_physics_process(false)
	check(population.sidewalk_segments.size() > 1000, "sidewalk routes cover the road network instead of three passenger stops")
	var near_start := false
	var far_east := false
	var far_west := false
	var rotated := false
	for segment in population.sidewalk_segments:
		if segment.center.distance_to(Vector3(258.175, 2.235, -429)) < 1.0:
			near_start = true
		if segment.center.x > 200 and segment.center.z > -100:
			far_east = true
		if segment.center.x < -200:
			far_west = true
		var delta: Vector3 = segment.points[1] - segment.points[0]
		if absf(delta.x) > absf(delta.z):
			rotated = true
	check(near_start, "starting street uses the mesh sidewalk center X=258.175")
	check(far_east and far_west, "sidewalk candidates extend well beyond pickups and drop-offs")
	check(rotated, "cell orientation supports both horizontal and vertical streets")
	var all_geometry := true
	for segment in population.sidewalk_segments:
		var inverse: Transform3D = population._roads[segment.road].inverse
		for point in segment.points:
			var local: Vector3 = inverse * point
			if absf(local.x) < 0.93 or absf(local.x) > 1.0 or absf(local.z) > 0.9:
				all_geometry = false
	check(all_geometry, "every generated patrol endpoint lies on the actual mesh sidewalk strip")
	var pool_ids: Array[int] = []
	for region in [Vector3(263, 12, -418), Vector3(263, 12, -100), Vector3(-330, 12, -370), Vector3(0, 12, 0)]:
		camera.global_position = region
		population.update_culling()
		check(population._assigned.size() > 0 and population.pedestrians.size() <= 40, "camera region has local pedestrians within the fixed global pool: " + str(region))
		var placed_correctly := true
		var nearby := 0
		for walker in population.pedestrians:
			if walker.get_meta("sidewalk_segment", -1) >= 0:
				placed_correctly = placed_correctly and on_sidewalk(population, walker)
				if walker.global_position.distance_to(region) <= population.activation_distance + 10:
					nearby += 1
		check(placed_correctly and nearby > 0, "streamed pedestrians stand on sidewalks in this region")
		if region == Vector3(263, 12, -100):
			for walker in population.pedestrians:
				pool_ids.append(walker.get_instance_id())
	var same_pool := true
	for walker in population.pedestrians:
		if walker.get_instance_id() not in pool_ids:
			same_pool = false
	check(same_pool, "travelling across the map reuses the same pedestrian pool")
	var walker: CharacterBody3D = population._assigned.values()[0]
	camera.global_position = walker.global_position + Vector3(0, 12, 0)
	population.update_culling()
	var identity := walker.get_instance_id()
	var segment_index: int = walker.get_meta("sidewalk_segment")
	var before: Vector3 = walker.global_position
	population._stream_near_camera()
	check(walker.get_instance_id() == identity and walker.get_meta("sidewalk_segment") == segment_index and walker.global_position == before, "visible pedestrians are never recycled or teleported during streaming")
	walker.set_simulation_active(true)
	await frames(50)
	check(on_sidewalk(population, walker), "walking remains constrained to its sidewalk patrol")
	var free_walker = population.PEDESTRIAN.instantiate()
	population.add_child(free_walker)
	population.pedestrians.append(free_walker)
	free_walker.global_position = camera.global_position - Vector3(0, 12, 0)
	population.update_culling()
	check(not free_walker.simulation_active, "unused pooled walkers stay hidden even when their old position is visible")
	population.pedestrians.erase(free_walker)
	free_walker.free()
	check(level.get_node("MissionManager").remaining_mission_passengers == 2, "network-wide pedestrians do not alter missions")
	level.free()
	current_scene = null
	await frames(2)
	check(get_nodes_in_group("AmbientPedestrians").is_empty(), "streamed population is fully cleaned up on scene exit")
	print("CHECKS: %d; FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
