extends "res://3D/Scripts/NPC/pedestrian_system.gd"
## Streams a fixed crowd pool onto the sidewalk strips of the current road meshes.
## The city_builder straight-road mesh uses outer local-X strips [0.93, 1.0].
@export_group("Road Sidewalks")
@export var road_grids: Array[GridMap] = []
@export_range(0.94, 0.98, 0.005) var sidewalk_center: float = 0.965
@export_range(0.2, 0.9, 0.05) var patrol_half_length: float = 0.8
@export_range(0.1, 5.0, 0.1) var minimum_speed: float = 1.0
@export_range(0.1, 5.0, 0.1) var maximum_speed: float = 1.8

const BUCKET_SIZE := 24.0
const ROAD_TOP := 0.1
const SPRITE_CLEARANCE := 0.135
var sidewalk_segments: Array[Dictionary] = []
var _segment_buckets: Dictionary = {}
var _roads: Array[Dictionary] = []
var _road_buckets: Dictionary = {}
var _assigned: Dictionary = {}
var _stream_center := Vector3(INF, INF, INF)
var _stream_camera: Camera3D

func populate() -> void:
	if _populated:
		return
	_populated = true
	_build_sidewalks()
	update_culling()

func _bucket(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x / BUCKET_SIZE), floori(point.z / BUCKET_SIZE))

func _build_sidewalks() -> void:
	# Index the real mesh transforms once, including per-cell rotation and scale.
	for grid in road_grids:
		if not is_instance_valid(grid) or grid.mesh_library == null:
			continue
		for cell in grid.get_used_cells():
			var item := grid.get_cell_item(cell)
			var item_name := grid.mesh_library.get_item_name(item)
			if not item_name.begins_with("road_"):
				continue
			var transform := grid.global_transform * Transform3D(grid.get_cell_item_basis(cell), grid.map_to_local(cell)) * grid.mesh_library.get_item_mesh_transform(item)
			var index := _roads.size()
			_roads.append({"transform": transform, "inverse": transform.affine_inverse(), "straight": item_name == "road_straight"})
			var key := _bucket(transform.origin)
			if not _road_buckets.has(key):
				_road_buckets[key] = []
			_road_buckets[key].append(index)
	for index in range(_roads.size()):
		var road: Dictionary = _roads[index]
		if not road.straight:
			continue
		var transform: Transform3D = road.transform
		for side in [-1.0, 1.0]:
			var first: Vector3 = transform * Vector3(side * sidewalk_center, ROAD_TOP, -patrol_half_length) + Vector3.UP * SPRITE_CLEARANCE
			var last: Vector3 = transform * Vector3(side * sidewalk_center, ROAD_TOP, patrol_half_length) + Vector3.UP * SPRITE_CLEARANCE
			var safe := true
			# Avoid overlapping crossroads/other roadway tiles, including road-grid seams.
			for step in range(5):
				if _inside_other_road(first.lerp(last, step / 4.0), index):
					safe = false
					break
			if not safe:
				continue
			var segment := {"points": PackedVector3Array([first, last]), "center": (first + last) * 0.5, "road": index, "side": side}
			var segment_index := sidewalk_segments.size()
			sidewalk_segments.append(segment)
			var key := _bucket(segment.center)
			if not _segment_buckets.has(key):
				_segment_buckets[key] = []
			_segment_buckets[key].append(segment_index)

func _inside_other_road(point: Vector3, own_road: int) -> bool:
	var bucket := _bucket(point)
	for x in range(-1, 2):
		for z in range(-1, 2):
			for index in _road_buckets.get(bucket + Vector2i(x, z), []):
				if index == own_road:
					continue
				var local: Vector3 = _roads[index].inverse * point
				if absf(local.x) < 0.9 and absf(local.z) < 1.0:
					return true
	return false

func update_culling() -> void:
	if not is_instance_valid(camera) or not camera.is_inside_tree():
		camera = get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		if camera != _stream_camera or camera.global_position.distance_squared_to(_stream_center) >= 16.0:
			_stream_camera = camera
			_stream_center = camera.global_position
			_stream_near_camera()
	super.update_culling()
	for walker in pedestrians:
		if walker.get_meta("sidewalk_segment", -1) < 0:
			walker.set_simulation_active(false)

func _nearby_segments() -> Array[int]:
	var result: Array[int] = []
	var bucket := _bucket(camera.global_position)
	var radius := ceili(activation_distance / BUCKET_SIZE)
	for x in range(-radius, radius + 1):
		for z in range(-radius, radius + 1):
			for index in _segment_buckets.get(bucket + Vector2i(x, z), []):
				if camera.global_position.distance_squared_to(sidewalk_segments[index].center) <= activation_distance * activation_distance:
					result.append(index)
	result.sort_custom(func(a: int, b: int) -> bool:
		return camera.global_position.distance_squared_to(sidewalk_segments[a].center) < camera.global_position.distance_squared_to(sidewalk_segments[b].center))
	return result

func _stream_near_camera() -> void:
	var candidates := _nearby_segments()
	var wanted: Dictionary = {}
	for index in candidates:
		if wanted.size() >= maximum_population:
			break
		wanted[index] = true
	# Recycling is allowed only while outside the padded frustum (or beyond range).
	# Existing visible walkers keep their route even when the camera shifts.
	var free_walkers: Array[CharacterBody3D] = []
	for walker in pedestrians:
		if walker.get_meta("sidewalk_segment", -1) < 0:
			free_walkers.append(walker)
	for index in _assigned.keys():
		var walker: CharacterBody3D = _assigned[index]
		if not wanted.has(index) and not _visible_now(walker.global_position):
			walker.set_simulation_active(false)
			free_walkers.append(walker)
			walker.set_meta("sidewalk_segment", -1)
			_assigned.erase(index)
	var initial := pedestrians.is_empty()
	for index in candidates:
		if _assigned.has(index):
			continue
		if _assigned.size() >= maximum_population:
			break
		var segment: Dictionary = sidewalk_segments[index]
		# Populate visible routes on first load only. Later additions happen offscreen.
		if not initial and (_visible_now(segment.center) or _visible_now(segment.points[0]) or _visible_now(segment.points[1])):
			continue
		var walker: CharacterBody3D
		if free_walkers.is_empty():
			if pedestrians.size() >= maximum_population:
				break
			walker = PEDESTRIAN.instantiate()
			add_child(walker)
			pedestrians.append(walker)
			walker.set_meta("sidewalk_segment", -1)
		else:
			walker = free_walkers.pop_back()
		if not _segment_clear(walker, segment.points):
			free_walkers.append(walker)
			continue
		walker.walk_speed = randf_range(minimum_speed, maxf(minimum_speed, maximum_speed))
		walker.configure(segment.points, 0 if index % 2 == 0 else 1, 1 if index % 2 == 0 else -1, true)
		walker.set_meta("sidewalk_segment", index)
		_assigned[index] = walker
	# Retain inactive free pool entries for the next area; never leave them visible.
	for walker in free_walkers:
		walker.set_simulation_active(false)
		walker.set_meta("sidewalk_segment", -1)

func _visible_now(point: Vector3) -> bool:
	if camera.global_position.distance_squared_to(point) > activation_distance * activation_distance:
		return false
	for plane in camera.get_frustum():
		if plane.distance_to(point) > frustum_margin:
			return false
	return true

func _segment_clear(walker: CharacterBody3D, points: PackedVector3Array) -> bool:
	var collision: CollisionShape3D = walker.get_node("CollisionShape3D")
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision.shape
	query.transform = Transform3D(walker.global_basis, points[0]) * collision.transform
	query.collision_mask = walker.collision_mask
	query.exclude = [walker.get_rid()]
	var space := get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.motion = points[1] - points[0]
	return space.cast_motion(query)[0] >= 0.999
