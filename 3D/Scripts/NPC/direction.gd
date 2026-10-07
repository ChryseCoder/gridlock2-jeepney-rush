extends Control
class_name DestinationArrow

# 0 if your arrow image points UP, 90 if it points RIGHT, 180 if DOWN, -90 if LEFT
@export var rotation_offset_degrees: float = 0.0

var destination_id: StringName = &""
var target: Node3D = null
var origin: Node3D = null  # the jeepney

func _ready() -> void:
	resized.connect(_update_pivot)
	_update_pivot()

func _update_pivot() -> void:
	pivot_offset = size / 2.0

func set_destination(id: StringName, from: Node3D) -> void:
	destination_id = id
	origin = from
	target = _find_destination(id)
	visible = target != null
	if target == null:
		push_warning("No PassengerDestination found with id: %s" % id)

func _find_destination(id: StringName) -> Node3D:
	for dest in get_tree().get_nodes_in_group("PassengerDestination"):
		if dest.destination_id == id:
			return dest
	return null

func _process(_delta: float) -> void:
	if target == null or origin == null:
		return
	if not is_instance_valid(target) or not is_instance_valid(origin):
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var from_screen := camera.unproject_position(origin.global_position)
	var to_screen := camera.unproject_position(target.global_position)
	var dir := to_screen - from_screen

	if dir.length() < 1.0:
		return

	rotation = dir.angle() + PI / 2.0 + deg_to_rad(rotation_offset_degrees)
