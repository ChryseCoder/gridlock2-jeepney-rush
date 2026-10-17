extends Control

@export var player: Node3D
@export var map_top_left: Marker3D
@export var map_bottom_right: Marker3D

@export var map_clip: Control
@export var map_content: Control
@export var map_texture: TextureRect
@export var player_marker: Control

@export_range(1.0, 5.0, 0.1) var zoom_level: float = 2.0
@export var map_screen_offset: Vector2 = Vector2(0, 0)

@export_group("Map Markers")
@export_range(1.0, 200.0, 1.0) var passenger_detection_radius: float = 40.0
@export var destination_marker_color: Color = Color("fb4140ff")
@export var passenger_marker_color: Color = Color("7bf45aff")

var _marker_layer: Control
var _destination_markers: Dictionary = {}
var _passenger_markers: Dictionary = {}


# Draw in a separate, unscaled layer so markers keep their size when zooming.
class MapMarker extends Control:
	var is_destination: bool = false
	var marker_color: Color
	var edge_direction: Vector2 = Vector2.ZERO

	func _draw() -> void:
		if is_destination:
			var points := PackedVector2Array([
				Vector2(0, -7),
				Vector2(7, 0),
				Vector2(0, 7),
				Vector2(-7, 0)
			])

			if not edge_direction.is_zero_approx():
				points = PackedVector2Array([
					Vector2(0, -8),
					Vector2(6, 5),
					Vector2(-6, 5)
				])

				for index in range(points.size()):
					points[index] = points[index].rotated(
						edge_direction.angle() + PI / 2.0
					)

			draw_colored_polygon(points, marker_color)
			points.append(points[0])
			draw_polyline(points, Color.BLACK, 2.0, true)
		else:
			draw_circle(Vector2.ZERO, 5.0, Color.BLACK)
			draw_circle(Vector2.ZERO, 3.5, marker_color)


func _ready():
	map_content.pivot_offset = Vector2.ZERO
	map_content.size = map_texture.size
	map_content.scale = Vector2.ONE * zoom_level

	_marker_layer = Control.new()
	_marker_layer.name = "MapMarkers"
	_marker_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_clip.add_child(_marker_layer)

	player_marker.z_index = 2


func _process(_delta):
	if not is_instance_valid(player) or map_top_left == null or map_bottom_right == null:
		return

	var world_width = (
		map_bottom_right.global_position.x
		- map_top_left.global_position.x
	)
	var world_depth = (
		map_bottom_right.global_position.z
		- map_top_left.global_position.z
	)

	if abs(world_width) < 0.001 or abs(world_depth) < 0.001:
		return

	map_content.scale = Vector2.ONE * zoom_level
	var map_position = _world_to_map_position(player.global_position)

	# Follow the player until the map reaches an edge.
	var center = map_clip.size / 2.0

	map_content.position = (
		center
		- map_position * zoom_level
		+ map_screen_offset
	)

	# Prevent empty space from appearing beyond the map edges.
	map_content.position.x = clampf(
		map_content.position.x,
		map_clip.size.x - map_texture.size.x * zoom_level,
		0.0
	)

	map_content.position.y = clampf(
		map_content.position.y,
		map_clip.size.y - map_texture.size.y * zoom_level,
		0.0
	)

	# Map texture and marker can have different parent transforms.
	player_marker.pivot_offset = player_marker.size / 2.0
	player_marker.rotation = -player.global_rotation.y
	player_marker.position = _position_in_control(
		map_position,
		player_marker.get_parent() as CanvasItem
	) - player_marker.size / 2.0

	_update_map_markers()


func _world_to_map_position(world_position: Vector3) -> Vector2:
	var top_left := map_top_left.global_position
	var bottom_right := map_bottom_right.global_position

	return Vector2(
		(world_position.x - top_left.x) / (bottom_right.x - top_left.x),
		(world_position.z - top_left.z) / (bottom_right.z - top_left.z)
	) * map_texture.size


func _position_in_control(
	map_position: Vector2,
	parent: CanvasItem
) -> Vector2:
	var map_point := map_texture.get_global_transform() * map_position
	return parent.get_global_transform().affine_inverse() * map_point


func _update_map_markers() -> void:
	var active_destinations: Dictionary = {}

	for passenger_data in player.passengers:
		active_destinations[passenger_data["destination_id"]] = true

	var destination_positions: Dictionary = {}

	for destination in get_tree().get_nodes_in_group("PassengerDestination"):
		if active_destinations.has(destination.destination_id):
			destination_positions[destination.get_instance_id()] = (
				destination.global_position
			)

	_sync_markers(destination_positions, _destination_markers, true)

	var passenger_positions: Dictionary = {}
	var player_position := Vector2(
		player.global_position.x,
		player.global_position.z
	)

	for passenger in get_tree().get_nodes_in_group("MinimapPassengers"):
		if passenger.is_queued_for_deletion() or not passenger.can_board:
			continue

		var passenger_position := Vector2(
			passenger.global_position.x,
			passenger.global_position.z
		)

		if player_position.distance_squared_to(passenger_position) <= passenger_detection_radius ** 2:
			passenger_positions[passenger.get_instance_id()] = (
				passenger.global_position
			)

	_sync_markers(passenger_positions, _passenger_markers, false)


func _sync_markers(
	positions: Dictionary,
	markers: Dictionary,
	destinations: bool
) -> void:
	for id in markers.keys():
		if not positions.has(id):
			var old_marker: MapMarker = markers[id]
			old_marker.hide()
			old_marker.queue_free()
			markers.erase(id)

	for id in positions:
		if not markers.has(id):
			var new_marker := MapMarker.new()
			new_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
			new_marker.is_destination = destinations
			new_marker.z_index = 1 if destinations else 0
			_marker_layer.add_child(new_marker)
			markers[id] = new_marker

		var marker: MapMarker = markers[id]
		var point := _position_in_control(
			_world_to_map_position(positions[id]),
			_marker_layer
		)

		marker.marker_color = (
			destination_marker_color
			if destinations
			else passenger_marker_color
		)
		marker.edge_direction = Vector2.ZERO

		if destinations:
			# Keep faraway stops visible as arrows along the minimap edge.
			var margin := Vector2.ONE * 10.0
			var edge_point := point.clamp(
				margin,
				(map_clip.size - margin).max(margin)
			)

			marker.edge_direction = point - edge_point
			marker.position = edge_point
			marker.show()
		else:
			marker.position = point
			marker.visible = Rect2(
				Vector2.ZERO,
				map_clip.size
			).has_point(point)

		marker.queue_redraw()
