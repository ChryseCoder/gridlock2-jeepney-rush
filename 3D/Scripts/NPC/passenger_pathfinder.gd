extends RefCounted

const CELL_SIZE: float = 0.35
const CLEARANCE: float = 0.04


static func has_line_of_sight(
	body: CharacterBody3D,
	target: Vector3
) -> bool:
	target.y = body.global_position.y

	var ray := PhysicsRayQueryParameters3D.create(
		body.global_position,
		target,
		body.collision_mask,
		[body.get_rid()]
	)

	return body.get_world_3d().direct_space_state.intersect_ray(
		ray
	).is_empty()


static func find_path(
	body: CharacterBody3D,
	target: Vector3,
	arrival_distance: float,
	padding: float
) -> PackedVector3Array:
	var collision := body.get_node(
		"CollisionShape3D"
	) as CollisionShape3D

	var space := body.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()

	query.shape = collision.shape
	query.collision_mask = body.collision_mask
	query.exclude = [body.get_rid()]
	query.margin = CLEARANCE

	var shape_transform := collision.global_transform
	var start := body.global_position
	target.y = start.y

	# The marker itself may be too close to the vehicle's collision body.
	var approach := (
		target
		+ (start - target).normalized() * arrival_distance * 0.8
	)

	if _segment_clear(
		space, query, shape_transform, start, start, approach
	):
		return PackedVector3Array([approach])

	var start_2d := Vector2(start.x, start.z)
	var target_2d := Vector2(target.x, target.z)

	var minimum := (
		start_2d.min(target_2d) - Vector2.ONE * padding
	).snappedf(CELL_SIZE)

	var maximum := (
		start_2d.max(target_2d) + Vector2.ONE * padding
	)

	var dimensions := Vector2i(
		ceil((maximum.x - minimum.x) / CELL_SIZE) + 1,
		ceil((maximum.y - minimum.y) / CELL_SIZE) + 1
	)

	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, dimensions)
	grid.cell_size = Vector2.ONE * CELL_SIZE
	grid.offset = minimum
	grid.diagonal_mode = (
		AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	)
	grid.update()

	var goals: Array[Vector2i] = []

	for x in range(dimensions.x):
		for z in range(dimensions.y):
			var cell := Vector2i(x, z)
			var point := grid.get_point_position(cell)
			var point_3d := Vector3(point.x, start.y, point.y)

			query.transform = shape_transform
			query.transform.origin += point_3d - start
			query.motion = Vector3.ZERO

			var blocked := not space.intersect_shape(
				query, 1
			).is_empty()

			grid.set_point_solid(cell, blocked)

			if (
				not blocked
				and point.distance_to(target_2d)
				<= arrival_distance * 0.9
			):
				var ray := PhysicsRayQueryParameters3D.create(
					point_3d,
					target,
					body.collision_mask,
					[body.get_rid()]
				)

				if space.intersect_ray(ray).is_empty():
					goals.append(cell)

	var start_cell := Vector2i(
		((start_2d - minimum) / CELL_SIZE).round()
	)
	grid.set_point_solid(start_cell, false)

	# Check whole segments too, so thin obstacles between samples are detected.
	for attempt in range(8):
		var best := PackedVector2Array()
		var best_length := INF

		for goal in goals:
			if grid.is_point_solid(goal):
				continue

			var candidate := grid.get_point_path(start_cell, goal)

			if candidate.is_empty():
				continue

			var length := 0.0
			var previous := start_2d

			for point in candidate:
				length += previous.distance_to(point)
				previous = point

			if length < best_length:
				best = candidate
				best_length = length

		if best.is_empty():
			return PackedVector3Array()

		var result := PackedVector3Array()
		var previous := start
		var blocked_segment := false

		# Use the actual passenger position instead of the start cell's center.
		var first_index := 0 if best.size() == 1 else 1

		for index in range(first_index, best.size()):
			var point := Vector3(
				best[index].x,
				start.y,
				best[index].y
			)

			if not _segment_clear(
				space, query, shape_transform, start, previous, point
			):
				var cell := Vector2i(
					((best[index] - minimum) / CELL_SIZE).round()
				)
				grid.set_point_solid(cell, true)
				blocked_segment = true
				break

			result.append(point)
			previous = point

		if not blocked_segment:
			return result

	return PackedVector3Array()


static func _segment_clear(
	space: PhysicsDirectSpaceState3D,
	query: PhysicsShapeQueryParameters3D,
	shape_transform: Transform3D,
	body_start: Vector3,
	from: Vector3,
	to: Vector3
) -> bool:
	query.transform = shape_transform
	query.transform.origin += to - body_start
	query.motion = Vector3.ZERO

	if not space.intersect_shape(query, 1).is_empty():
		return false

	query.transform = shape_transform
	query.transform.origin += from - body_start
	query.motion = to - from

	var fractions := space.cast_motion(query)
	return fractions[0] >= 0.999
