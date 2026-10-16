extends Control

@export var player: Node3D
@export var map_top_left: Marker3D
@export var map_bottom_right: Marker3D

@export var map_clip: Control
@export var map_content: Control
@export var map_texture: TextureRect
@export var player_marker: Control

@export_range(1.0, 5.0, 0.1) var zoom_level: float = 2.0
@export var map_screen_offset: Vector2 = Vector2(-12, -4)

func _ready():
	map_content.pivot_offset = Vector2.ZERO
	map_content.size = map_texture.size
	map_content.scale = Vector2.ONE * zoom_level


func _process(_delta):
	if player == null or map_top_left == null or map_bottom_right == null:
		return

	var world_width = map_bottom_right.global_position.x - map_top_left.global_position.x
	var world_depth = map_bottom_right.global_position.z - map_top_left.global_position.z

	if abs(world_width) < 0.001 or abs(world_depth) < 0.001:
		return

	# Convert the Jeepney's world position into map-image coordinates.
	var map_x = (player.global_position.x - map_top_left.global_position.x) / world_width
	var map_y = (player.global_position.z - map_top_left.global_position.z) / world_depth

	var map_position = Vector2(
		map_x * map_texture.size.x,
		map_y * map_texture.size.y
	)

	# Keep the player marker at the center of the minimap.
	var center = map_clip.size / 2.0

	map_content.position = center - map_position * zoom_level + map_screen_offset

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

	player_marker.position = map_clip.position + center - player_marker.size / 2.0

	# Rotate the marker to match the Jeepney's heading.
	player_marker.rotation = -player.rotation.y
